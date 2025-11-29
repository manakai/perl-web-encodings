package Web::Encoding::UnivCharDet;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::Encoding::UnivCharDet::Defs;

sub new ($) {
  my $self = bless {}, shift;
  
  $self->{filter} = {ja => 1, zh_hant => 1, zh_hans => 1, ko => 1, non_cjk => 1};
  
  return $self;
} # new

sub _detector ($) {
  return $_[0]->{detector} ||= do {
    my $filter = 0;
    $filter |= Web::Encoding::UnivCharDet::Defs::FILTER_JAPANESE () if $_[0]->{filter}->{ja};
    $filter |= Web::Encoding::UnivCharDet::Defs::FILTER_CHINESE_TRADITIONAL () if $_[0]->{filter}->{zh_hant};
    $filter |= Web::Encoding::UnivCharDet::Defs::FILTER_CHINESE_SIMPLIFIED () if $_[0]->{filter}->{zh_hans};
    $filter |= Web::Encoding::UnivCharDet::Defs::FILTER_KOREAN () if $_[0]->{filter}->{ko};
    $filter |= Web::Encoding::UnivCharDet::Defs::FILTER_NON_CJK () if $_[0]->{filter}->{non_cjk};
    my $x = Web::Encoding::UnivCharDet::UniversalDetector->new ($filter);
    $x->{utf} = 1 if $_[0]->{filter}->{utf};
    $x;
  };
} # _detector

sub filter ($) {
  return $_[0]->{filter};
} # filter

sub detect_byte_string ($$) {
  my $self = $_[0];
  my $detector = $self->_detector;
  $detector->reset;
  $detector->handle_data ($_[1]);
  $detector->data_end;
  return $detector->get_reported_charset; # or undef
} # detect_byte_string

sub _dump ($) {
  $_[0]->_detector->dump_status;
} # _dump

sub _dump_for_json ($) {
  $_[0]->_detector->dump_status_for_json;
} # _dump_for_json

package Web::Encoding::UnivCharDet::UniversalDetector;
our $VERSION = '1.0';
use Web::Encoding::UnivCharDet::CharsetProber;
use Web::Encoding::UnivCharDet::UTFCharsetProber;

sub new ($$) {
  my $self = bless {
    lang_filter => $_[1],
  }, $_[0];
  $self->reset;
  return $self;
} # new

sub reset ($) {
  my $self = $_[0];
  $self->{done} = 0;
  $self->{best_guess} = -1;
  $self->{start} = 1;
  delete $self->{detected_charset};
  delete $self->{font_charset};
  $self->{got_data} = undef;
  $self->{input_state} = 'pure ascii';
  $self->{last_char} = 0x00;
  $self->{charset_probers} = [];
  delete $self->{esc_charset_prober};
  delete $self->{utf1632_prober};
  delete $self->{reported};
  delete $self->{nbsp_found};
  delete $self->{esc_found};
  delete $self->{binary_found};
  $self->{win1250_refs} = 0;
  $self->{win1252_refs} = 0;
  $self->{unicode_refs} = 0;
  delete $self->{resolve_latin1_refs};
  delete $self->{amp};
} # reset

sub handle_data ($$) {
  my $self = $_[0];
  return 1 if $self->{done};
  $self->{got_data} = 1 if length $_[1];

  if ($self->{start}) {
    $self->{start} = 0;

    if ($_[1] =~ /^\xEF\xBB\xBF/) {
      $self->{detected_charset} = 'utf-8';
    } elsif ($_[1] =~ /^\xFE\xFF/) {
      $self->{detected_charset} = 'utf-16be';
    } elsif ($_[1] =~ /^\xFF\xFE/) {
      $self->{detected_charset} = 'utf-16le';
    }

    if ($self->{utf}) {
      ## <https://github.com/mozilla/gecko-dev/commit/68332f717f14e8f2467ca4f2c521ed8fe6eff71d>
      if ($_[1] =~ /^\xFE\xFF\x00\x00/) {
        $self->{detected_charset} = 'x-iso-10646-ucs-4-3412';
      } elsif ($_[1] =~ /^\x00\x00\xFE\xFF/) {
        $self->{detected_charset} = 'utf-32be';
      } elsif ($_[1] =~ /^\x00\x00\xFF\xFE/) {
        $self->{detected_charset} = 'x-iso-10646-ucs-4-2143';
      } elsif ($_[1] =~ /^\xFF\xFE\x00\x00/) {
        $self->{detected_charset} = 'utf-32le';
      } 
    }

    if ($self->{detected_charset}) {
      $self->{done} = 1;
      return 1;
    }
  } # start

  my $length = length $_[1];
  my $zero = 0;
  my $high = 0;
  for my $i (0..($length - 1)) {
    my $c = ord substr $_[1], $i, 1;
    $zero++ if $c == 0x00;
    if ($c == 0xA0) {
      $self->{nbsp_found} = 1;
    } elsif ($c & 0x80) {
      if ($self->{input_state} ne 'high byte') {
        $self->{input_state} = 'high byte';
        $high = 1;
      }
      delete $self->{amp};
    } elsif ($c == 0x26) {
      $self->{amp} = '';
      $self->{last_char} = $c;
    } else {
      if ($self->{input_state} eq 'pure ascii') {
        if ($c == 0x1B or $c == 0x0E or $c == 0x0F) {
          $self->{input_state} = 'esc ascii';
          $self->{esc_found} = 1;
        } elsif ($c == 0x7B and $self->{last_char} == 0x7E) { # ~{
          $self->{input_state} = 'esc ascii';
        } elsif ((0x00 <= $c and $c <= 0x07) or
                 (0x10 <= $c and $c <= 0x19) or
                 (0x1C <= $c and $c <= 0x1F) or
                 $c == 0x7F) {
          $self->{binary_found} = 1;
        }
        $self->{last_char} = $c;
      }
      
      if (defined $self->{amp}) {
        if ($c == 0x3B) {
          if (defined $Web::Encoding::UnivCharDet::Defs::Latin1Entities->{$self->{amp}}) {
            $self->{win1252_refs}++;
            if ($self->{amp} =~ /^#([0-9]+)$/ and
                $Web::Encoding::UnivCharDet::Defs::Windows1250Refs->{$1}) {
              $self->{win1250_refs}++;
            }
          } elsif ($self->{amp} =~ /^#([0-9]+)$/) {
            my $cc = $1;
            if ($cc > 0xFF) {
              if ($Web::Encoding::UnivCharDet::Defs::Windows1250Refs->{$cc}) {
                $self->{win1250_refs}++;
              } else {
                $self->{unicode_refs}++;
              }
            } elsif (0x80 <= $cc) {
              if ($Web::Encoding::UnivCharDet::Defs::Windows1250Refs->{$cc}) {
                $self->{win1250_refs}++;
              }
              $self->{win1252_refs}++;
            }
          }
          delete $self->{amp};
        } elsif ($c == 0x23 and $self->{amp} eq '') { # &#
          $self->{amp} .= chr $c;
        } elsif (10 < length $self->{amp}) {
          delete $self->{amp};
        } elsif (0x30 <= $c and $c <= 0x39) {
          $self->{amp} .= chr $c;
        } elsif (0x41 <= $c and $c <= 0x5A) {
          $self->{amp} .= chr $c;
        } elsif (0x61 <= $c and $c <= 0x7A) {
          $self->{amp} .= chr $c;
        } else {
          delete $self->{amp};
        }
      } # amp
    }
  } # $i

  if ($self->{input_state} eq 'pure ascii' and
      $self->{unicode_refs} < 10 and
      $self->{win1250_refs} + $self->{win1252_refs} > 10) {
    $self->{input_state} = 'high byte';
    $high = 1;
  }

  if ($high) {
    delete $self->{esc_charset_prober};
    delete $self->{utf1632_prober};

    $self->{charset_probers}->[0]
        ||= Web::Encoding::UnivCharDet::CharsetProber::MBCSGroup->new
            ($self->{lang_filter});
    $self->{charset_probers}->[1]
        ||= Web::Encoding::UnivCharDet::CharsetProber::SBCSGroup->new
        if $self->{lang_filter} & Web::Encoding::UnivCharDet::Defs::FILTER_NON_CJK;
    $self->{charset_probers}->[2]
        ||= Web::Encoding::UnivCharDet::CharsetProber::Latin1->new
        unless $self->{lang_filter} & Web::Encoding::UnivCharDet::Defs::FILTER_NON_CJK;
    $self->{charset_probers}->[3]
        ||= Web::Encoding::UnivCharDet::CharsetProber::Vietnamese->new
        if $self->{lang_filter} & Web::Encoding::UnivCharDet::Defs::FILTER_NON_CJK;
  } # $high

  if ($self->{win1252_refs} > 10 and $self->{unicode_refs} < 10) {
    $self->{charset_probers}->[4]
        ||= Web::Encoding::UnivCharDet::CharsetProber::MBCSGroup->new
                ($self->{lang_filter}, resolve_latin1_refs => 1);
    if ($self->{lang_filter} & Web::Encoding::UnivCharDet::Defs::FILTER_NON_CJK) {
      $self->{charset_probers}->[5]
          ||= Web::Encoding::UnivCharDet::CharsetProber::SBCSGroup->new
                  (resolve_latin1_refs => 1);
    }
    if ($self->{lang_filter} & Web::Encoding::UnivCharDet::Defs::FILTER_NON_CJK) {
      $self->{charset_probers}->[6]
          ||= Web::Encoding::UnivCharDet::CharsetProber::Vietnamese->new
                  (resolve_latin1_refs => 1);
    }
    $self->{resolve_latin1_refs} = 1;
  } else {
    delete $self->{resolve_latin1_refs};
    delete $self->{charset_probers}->[4];
    delete $self->{charset_probers}->[5];
    delete $self->{charset_probers}->[6];
  }
  
  if ($self->{utf} and $zero) {
    if ($zero / ($length || 1) > 0.1) { # random threshold
      $self->{charset_probers} = [];
    }
    $self->{utf1632_prober} ||= Web::Encoding::UnivCharDet::UTFCharsetProber->new;
  }
  if (defined $self->{utf1632_prober}) {
    {
      my $st = $self->{utf1632_prober}->handle_data ($_[1]);
      if ($st eq 'found it') {
        $self->{done} = 1;
        $self->{detected_charset} = $self->{utf1632_prober}->get_charset_name; # non-undef when found
        return 1;
      }
    }
  }

  if ($self->{input_state} eq 'esc ascii') {
    $self->{esc_charset_prober}
        ||= Web::Encoding::UnivCharDet::CharsetProber::ESC->new
                ($self->{lang_filter});
    {
      my $st = $self->{esc_charset_prober}->handle_data ($_[1]);
      if ($st eq 'found it') {
        $self->{done} = 1;
        $self->{detected_charset} = $self->{esc_charset_prober}->get_charset_name; # non-undef when found
        return 1;
      }
    }
  } elsif ($self->{input_state} eq 'high byte') {
    if (defined $self->{resolve_latin1_refs}) {
      my $x = $_[1];
      if ($self->{resolve_latin1_refs}) {
        $x =~ s{&#(12[89]|1[3-9][0-9]|2[0-4][0-9]|25[0-5]);}{pack 'C', $1}ge;
        $x =~ s{&([A-Za-z0-9]+);}{
          if (defined $Web::Encoding::UnivCharDet::Defs::Latin1Entities->{$1}) {
            chr $Web::Encoding::UnivCharDet::Defs::Latin1Entities->{$1};
          } else {
            ('&'.$1.';');
          }
        }ge;
      }
      for (grep { defined $_ } @{$self->{charset_probers}}[0..3]) {
        my $st = $_->handle_data ($_[1]);
        if ($st eq 'found it') {
          $self->{done} = 1;
          $self->{detected_charset} = $_->get_charset_name; # non-undef when found
          return 1;
        }
      }
      for (grep { defined $_ } @{$self->{charset_probers}}[4..6]) {
        my $st = $_->handle_data ($x);
        if ($st eq 'found it') {
          $self->{done} = 1;
          $self->{detected_charset} = 'windows-1252';
          $self->{font_charset} = $_->get_charset_name; # non-undef when found
          if (defined $self->{font_charset} and
              $self->{font_charset} eq 'windows-1252') {
            delete $self->{font_charset};
          }
          return 1;
        }
      }
    } else {
      for (grep { defined $_ } @{$self->{charset_probers}}) {
        my $st = $_->handle_data ($_[1]);
        if ($st eq 'found it') {
          $self->{done} = 1;
          $self->{detected_charset} = $_->get_charset_name; # non-undef when found
          return 1;
        }
      }
    }
  }
  
  return 1;
} # handle_data

sub data_end ($) {
  my $self = $_[0];
  return unless $self->{got_data};

  if (defined $self->{detected_charset}) {
    $self->{done} = 1;
    $self->{reported} = $self->{detected_charset};
    return;
  }

  if (defined $self->{utf1632_prober}) {
    $self->{utf1632_prober}->handle_eof;
    $self->{reported} = $self->{utf1632_prober}->get_charset_name; # or undef
  }

  if ($self->{input_state} eq 'high byte') {
    my $max_prober_confidence = 0.0;
    my $max_prober;
    for (grep { defined $_ } @{$self->{charset_probers}}) {
      $_->handle_eof;
      my $prober_confidence = $_->get_confidence;
      if ($prober_confidence > $max_prober_confidence) {
        $max_prober_confidence = $prober_confidence;
        $max_prober = $_;
      }
    }
    if ($max_prober_confidence > Web::Encoding::UnivCharDet::Defs::MINIMUM_THRESHOLD) {
      if ($max_prober->{resolve_latin1_refs}) {
        $self->{reported} = 'windows-1252';
        $self->{font_charset} = $max_prober->get_charset_name; # or undef
        if (not defined $self->{font_charset} or
            $self->{font_charset} eq 'windows-1252') {
          delete $self->{font_charset};
        }
      } else {
        $self->{reported} = $max_prober->get_charset_name; # or undef
      }
    }
  } elsif ($self->{input_state} eq 'pure ascii' or
           $self->{input_state} eq 'esc ascii') {
    #$self->{esc_charset_prober}->handle_eof;
    if ($self->{esc_found}) {
      #
    } elsif ($self->{binary_found}) {
      #
    } elsif ($self->{nbsp_found}) {
      $self->{reported} = 'windows-1252';
    } else {
      $self->{reported} = 'ascii';
    }
  }
} # data_end

sub get_reported_charset ($) {
  return $_[0]->{reported};
} # get_reported_charset

sub get_reported_font_charset ($) {
  return $_[0]->{font_charset};
} # get_reported_font_charset

sub dump_status ($) {
  my $self = $_[0];
  printf "[%s] %s (%d %d %d) %s\n",
      $self->{reported} // '',
      defined $self->{font_charset} ? 'html:'.$self->{font_charset} : '',
      $self->{win1250_refs}, $self->{win1250_refs}, $self->{unicode_refs},
      $self->{input_state};
  $_->dump_status for grep { defined $_ }
      @{$self->{charset_probers}},
      $self->{esc_charset_prober},
      $self->{utf1632_prober};
  print "Reported: @{[$self->{reported} // '']} @{[defined $self->{font_charset} ? 'html:'.$self->{font_charset} : '']}\n";
} # dump_status

sub dump_status_for_json ($) {
  my $self = $_[0];
  return {type => ref $self,
          input_state => $self->{input_state},
          probers => [map { $_->dump_status_for_json }
                      grep { defined $_ }
                      @{$self->{charset_probers}},
                      $self->{esc_charset_prober},
                      $self->{utf1632_prober}],
          font_charset => $self->{font_charset},
          reported => $self->{reported}};
} # dump_status_for_json

1;

=head1 LICENSE

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at <http://mozilla.org/MPL/2.0/>.

=cut
