package Web::Encoding::UnivCharDet;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::Encoding::UnivCharDet::Defs;

sub new ($;%) {
  my $self = bless {}, shift;
  my %args = @_;
  
  $self->{filter} = {ja => 1, zh_hant => 1, zh_hans => 1, ko => 1, non_cjk => 1};
  $self->{filter}->{utf} = 1 if $args{utf};
  
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
  $self->{in_tag} = 0;
  $self->{start} = 1;
  $self->{detected_charset} = undef;
  $self->{got_data} = undef;
  $self->{input_state} = 'pure ascii';
  $self->{last_char} = 0x00;
  $self->{charset_probers} = [];
  delete $self->{esc_charset_prober};
  delete $self->{utf1632_prober};
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
  for my $i (0..($length - 1)) {
    my $c = ord substr $_[1], $i, 1;
    $zero++ if $c == 0x00;
    if ($c & 0x80 and $c != 0xA0) {
      if ($self->{input_state} ne 'high byte') {
        $self->{input_state} = 'high byte';
        delete $self->{esc_charset_prober};
        delete $self->{utf1632_prober};

        $self->{charset_probers}->[0]
            ||= Web::Encoding::UnivCharDet::CharsetProber::MBCSGroup->new
                    ($self->{lang_filter});
        $self->{charset_probers}->[1]
            ||= Web::Encoding::UnivCharDet::CharsetProber::SBCSGroup->new
            if $self->{lang_filter} & Web::Encoding::UnivCharDet::Defs::FILTER_NON_CJK;
        $self->{charset_probers}->[2]
            ||= Web::Encoding::UnivCharDet::CharsetProber::Latin1->new;
      }
    } else {
      if ($self->{input_state} eq 'pure ascii' and
          $c == 0x1B or
          ($c == 0x7B and $self->{last_char} == 0x7E)) { # ~{
        $self->{input_state} = 'esc ascii';
      }
      $self->{last_char} = $c;
    }
  } # $i

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
    for (grep { defined $_ } @{$self->{charset_probers}}) {
      my $st = $_->handle_data ($_[1]);
      if ($st eq 'found it') {
        $self->{done} = 1;
        $self->{detected_charset} = $_->get_charset_name; # non-undef when found
        return 1;
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
    $self->{reported} = $self->{utf1632_prober}->get_charset_name; # or undef
  }

  if ($self->{input_state} eq 'high byte') {
    my $max_prober_confidence = 0.0;
    my $max_prober;
    for (grep { defined $_ } @{$self->{charset_probers}}) {
      my $prober_confidence = $_->get_confidence;
      if ($prober_confidence > $max_prober_confidence) {
        $max_prober_confidence = $prober_confidence;
        $max_prober = $_;
      }
    }
    if ($max_prober_confidence > Web::Encoding::UnivCharDet::Defs::MINIMUM_THRESHOLD) {
      $self->{reported} = $max_prober->get_charset_name; # or undef (but unlikely?)
    }
  }
} # data_end

sub get_reported_charset ($) {
  return $_[0]->{reported};
} # get_reported_charset

sub dump_status ($) {
  my $self = $_[0];
  print "Input state: $self->{input_state}\n";
  $_->dump_status for grep { defined $_ }
      @{$self->{charset_probers}},
      $self->{esc_charset_prober},
      $self->{utf1632_prober};
  print "Reported: @{[$self->{reported} // '']}\n";
} # dump_status

1;

=head1 LICENSE

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at <http://mozilla.org/MPL/2.0/>.

=cut
