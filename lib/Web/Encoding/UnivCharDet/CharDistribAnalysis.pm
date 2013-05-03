package Web::Encoding::UnivCharDet::CharDistribAnalysis;
use strict;
use warnings;
our $VERSION = '1.0';

sub SURE_YES () { 0.99 }
sub SURE_NO () { 0.01 }

sub MINIMUM_DATA_THRESHOLD () { 4 }
sub ENOUGH_DATA_THRESHOLD () { 1024 }

sub new ($) {
  my $self = bless {}, $_[0];
  $self->reset (0);
  $self->_init;
  return $self;
} # new

sub reset ($$) {
  my $self = $_[0];
  $self->{done} = 0;
  $self->{total_chars} = 0;
  $self->{freq_chars} = 0;
  $self->{data_threshold} = $_[1] ? 0 : MINIMUM_DATA_THRESHOLD;
} # reset

sub handle_data ($$) { }

sub handle_one_char ($$$$) {
  my $self = $_[0];
  # $self, $str, $offset, $len

  my $order = $_[3] == 2 ? $self->get_order ($_[1], $_[2]) : -1;
  if ($order >= 0) {
    $self->{total_chars}++;
    if ($order < @{$self->{char_to_freq_order}}) {
      if (512 > $self->{char_to_freq_order}->[$order]) {
        $self->{freq_chars}++;
      }
    }
  }
} # handle_one_char

sub get_order ($$$) { -1 }

sub get_confidence ($) {
  my $self = $_[0];
  if ($self->{total_chars} <= 0 or
      $self->{freq_chars} <= $self->{data_threshold}) {
    return SURE_NO;
  } elsif ($self->{total_chars} != $self->{freq_chars}) {
    my $r = $self->{freq_chars} / (($self->{total_chars} - $self->{freq_chars}) * $self->{typical_distribution_ratio});
    if ($r < SURE_YES) {
      return $r;
    }
  }
  return SURE_YES;
} # get_confidence

sub got_enough_data ($) {
  return $_[0]->{total_chars} > ENOUGH_DATA_THRESHOLD;
} # got_enough_data

package Web::Encoding::UnivCharDet::CharDistribAnalysis::EUCTW;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharDistribAnalysis);

sub _init ($) {
  $_[0]->{char_to_freq_order} = Web::Encoding::UnivCharDet::Defs::EUCTWCharToFreqOrder;
  $_[0]->{typical_distribution_ratio} = Web::Encoding::UnivCharDet::Defs::EUCTW_TYPICAL_DISTRIBUTION_RATIO;
} # _init

sub get_order ($$$) {
  if ((ord substr $_[1], $_[2], 1) >= 0xC4) {
    return 94 * ((ord substr $_[1], $_[2], 1) - 0xC4) + (ord substr $_[1], $_[2] + 1, 1) - 0xA1;
  } else {
    return -1;
  }
} # get_order

package Web::Encoding::UnivCharDet::CharDistribAnalysis::EUCKR;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharDistribAnalysis);

sub _init ($) {
  $_[0]->{char_to_freq_order} = Web::Encoding::UnivCharDet::Defs::EUCKRCharToFreqOrder;
  $_[0]->{typical_distribution_ratio} = Web::Encoding::UnivCharDet::Defs::EUCKR_TYPICAL_DISTRIBUTION_RATIO;
} # _init

sub get_order ($$$) {
  if ((ord substr $_[1], $_[2], 1) >= 0xB0) {
    return 94 * ((ord substr $_[1], $_[2], 1) - 0xB0) + (ord substr $_[1], $_[2] + 1, 1) - 0xA1;
  } else {
    return -1;
  }
} # get_order

package Web::Encoding::UnivCharDet::CharDistribAnalysis::GB2312;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharDistribAnalysis);

sub _init ($) {
  $_[0]->{char_to_freq_order} = Web::Encoding::UnivCharDet::Defs::GB2312CharToFreqOrder;
  $_[0]->{typical_distribution_ratio} = Web::Encoding::UnivCharDet::Defs::GB2312_TYPICAL_DISTRIBUTION_RATIO;
} # _init

sub get_order ($$$) {
  if ((ord substr $_[1], $_[2], 1) >= 0xB0) {
    return 94 * ((ord substr $_[1], $_[2], 1) - 0xB0) + (ord substr $_[1], $_[2] + 1, 1) - 0xA1;
  } else {
    return -1;
  }
} # get_order

package Web::Encoding::UnivCharDet::CharDistribAnalysis::Big5;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharDistribAnalysis);

sub _init ($) {
  $_[0]->{char_to_freq_order} = Web::Encoding::UnivCharDet::Defs::Big5CharToFreqOrder;
  $_[0]->{typical_distribution_ratio} = Web::Encoding::UnivCharDet::Defs::BIG5_TYPICAL_DISTRIBUTION_RATIO;
} # _init

sub get_order ($$$) {
  if ((ord substr $_[1], $_[2], 1) >= 0xA4) {
    if ((ord substr $_[1], $_[2] + 1, 1) >= 0xA1) {
      return 157 * ((ord substr $_[1], $_[2], 1) - 0xA4) + (ord substr $_[1], $_[2] + 1, 1) - 0xA1 + 63;
    } else {
      return 157 * ((ord substr $_[1], $_[2], 1) - 0xA4) + (ord substr $_[1], $_[2] + 1, 1) - 0x40;
    }
  } else {
    return -1;
  }
} # get_order

package Web::Encoding::UnivCharDet::CharDistribAnalysis::SJIS;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharDistribAnalysis);

sub _init ($) {
  $_[0]->{char_to_freq_order} = Web::Encoding::UnivCharDet::Defs::JISCharToFreqOrder;
  $_[0]->{typical_distribution_ratio} = Web::Encoding::UnivCharDet::Defs::JIS_TYPICAL_DISTRIBUTION_RATIO;
} # _init

sub get_order ($$$) {
  my $order;
  if ((ord substr $_[1], $_[2], 1) >= 0x81 and
      (ord substr $_[1], $_[2], 1) <= 0x9F) {
    $order = 188 * ((ord substr $_[1], $_[2], 1) - 0x81);
  } elsif ((ord substr $_[1], $_[2], 1) >= 0xE0 and
           (ord substr $_[1], $_[2], 1) <= 0xEF) {
    $order = 188 * ((ord substr $_[1], $_[2], 1) - 0xE0 + 31);
  } else {
    return -1;
  }
  $order += (ord substr $_[1], $_[2] + 1, 1) - 0x40;
  $order-- if (ord substr $_[1], $_[2] + 1, 1) > 0x7F;
  return $order;
} # get_order

package Web::Encoding::UnivCharDet::CharDistribAnalysis::EUCJP;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharDistribAnalysis);

sub _init ($) {
  $_[0]->{char_to_freq_order} = Web::Encoding::UnivCharDet::Defs::JISCharToFreqOrder;
  $_[0]->{typical_distribution_ratio} = Web::Encoding::UnivCharDet::Defs::JIS_TYPICAL_DISTRIBUTION_RATIO;
} # _init

sub get_order ($$$) {
  if ((ord substr $_[1], $_[2], 1) >= 0xA0) {
    return 94 * ((ord substr $_[1], $_[2], 1) - 0xA1) + (ord substr $_[1], $_[2] + 1, 1) - 0xA1;
  } else {
    return -1;
  }
} # get_order

1;

=head1 LICENSE

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at <http://mozilla.org/MPL/2.0/>.

=cut
