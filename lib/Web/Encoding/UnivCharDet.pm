package Web::Encoding::UnivCharDet;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::Encoding::UnivCharDet::Defs;

sub new ($) {
  my $self = bless {}, $_[0];
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
    Web::Encoding::UnivCharDet::UniversalDetector->new ($filter);
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

sub new ($$) {
  my $self = bless {
    lang_filter => $_[1],
    charset_probers => [],
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
  $self->{esc_charset_prober}->reset if $self->{esc_charset_prober};
  $_->reset for grep { $_ } @{$self->{charset_probers}};
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

    if ($self->{detected_charset}) {
      $self->{done} = 1;
      return 1;
    }
  } # start

  for my $i (0..((length $_[1]) - 1)) {
    my $c = ord substr $_[1], $i, 1;
    if ($c & 0x80 and $c != 0xA0) {
      if ($self->{input_state} ne 'high byte') {
        $self->{input_state} = 'high byte';
        delete $self->{esc_charset_prober} if $self->{esc_charset_prober};

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

  if ($self->{input_state} eq 'esc ascii') {
    $self->{esc_charset_prober}
        ||= Web::Encoding::UnivCharDet::CharsetProber::ESC->new
            ($self->{lang_filter});
    my $st = $self->{esc_charset_prober}->handle_data ($_[1]);
    if ($st eq 'found it') {
      $self->{done} = 1;
      $self->{detected_charset} = $self->{esc_charset_prober}->get_charset_name;
    }
  } elsif ($self->{input_state} eq 'high byte') {
    for (grep { $_ } @{$self->{charset_probers}}) {
      my $st = $_->handle_data ($_[1]);
      if ($st eq 'found it') {
        $self->{done} = 1;
        $self->{detected_charset} = $_->get_charset_name;
        return 1;
      }
    }
  }

  return 1;
} # handle_data

sub data_end ($) {
  my $self = $_[0];
  return unless $self->{got_data};

  if ($self->{detected_charset}) {
    $self->{done} = 1;
    $self->{reported} = $self->{detected_charset};
    return;
  }

  if ($self->{input_state} eq 'high byte') {
    my $max_prober_confidence = 0.0;
    my $max_prober;
    for (grep { $_ } @{$self->{charset_probers}}) {
      my $prober_confidence = $_->get_confidence;
      if ($prober_confidence > $max_prober_confidence) {
        $max_prober_confidence = $prober_confidence;
        $max_prober = $_;
      }
    }
    if ($max_prober_confidence > Web::Encoding::UnivCharDet::Defs::MINIMUM_THRESHOLD) {
      $self->{reported} = $max_prober->get_charset_name;
    }
  }
} # data_end

sub get_reported_charset ($) {
  return $_[0]->{reported};
} # get_reported_charset

sub dump_status ($) {
  $_->dump_status for grep { $_ } @{$_[0]->{charset_probers}};
} # dump_status

1;

=head1 LICENSE

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at <http://mozilla.org/MPL/2.0/>.

=cut
