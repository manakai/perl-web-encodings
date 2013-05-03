package Web::Encoding::UnivCharDet::ContextAnalysis;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::Encoding::UnivCharDet::Defs;

package Web::Encoding::UnivCharDet::ContextAnalysis::Japanese;
our $VERSION = '1.0';

sub NUM_OF_CATEGORY () { 8 }
sub MINIMUM_DATA_THRESHOLD () { 4 }
sub ENOUGH_REL_THRESHOLD () { 100 }
sub MAX_REL_THRESHOLD () { 1000 }

sub new ($) {
  my $self = bless {}, $_[0];
  $self->reset (0);
  return $self;
} # new

sub reset ($$) {
  my $self = $_[0];
  $self->{total_rel} = 0;
  $self->{rel_sample}->[$_] = 0 for 0..(NUM_OF_CATEGORY - 1);
  $self->{need_to_skip_char_num} = 0;
  $self->{last_char_order} = -1;
  $self->{done} = 0;
  $self->{data_threshold} = $_[1] ? 0 : MINIMUM_DATA_THRESHOLD;
} # reset

sub handle_data ($$$) {
  my $self = $_[0];
  return if $self->{done};
  for (my $i = $self->{need_to_skip_char_num}; $i < (length $_[1]) - 1; ) {
    my ($order, $char_len) = $self->get_order ($_[1], $i);
    $i += $char_len;
    if ($i > length $_[1]) {
      $self->{need_to_skip_char_num} = $i - length $_[1];
      $self->{last_char_order} = -1;
    } else {
      if ($order != -1 and $self->{last_char_order} != -1) {
        $self->{total_rel}++;
        if ($self->{total_rel} > MAX_REL_THRESHOLD) {
          $self->{done} = 1;
          last;
        }
        $self->{rel_sample}->[Web::Encoding::UnivCharDet::Defs::jp2CharContext->[$self->{last_char_order}]->[$order]]++;
      }
      $self->{last_char_order} = $order;
    }
  } # $i
} # handle_data

sub handle_one_char ($$$) {
  my $self = $_[0];
  if ($self->{total_rel} > MAX_REL_THRESHOLD) {
    $self->{done} = 1;
  }
  return if $self->{done};

  my ($order) = $_[3] == 2 ? $self->get_order ($_[1], $_[2]) : -1;
  if ($order != -1 and $self->{last_char_order} != -1) {
    $self->{total_rel}++;
    $self->{rel_sample}->[Web::Encoding::UnivCharDet::Defs::jp2CharContext->[$self->{last_char_order}]->[$order]]++;
  }
  $self->{last_char_order} = $order;
} # handle_one_char

sub DONT_KNOW () { -1 }

sub get_confidence ($) {
  my $self = $_[0];
  if ($self->{total_rel} > $self->{data_threshold}) {
    return (($self->{total_rel} - $self->{rel_sample}->[0]) / $self->{total_rel});
  } else {
    return DONT_KNOW;
  }
} # get_confidence

sub got_enough_data ($) {
  return $_[0]->{total_rel} > ENOUGH_REL_THRESHOLD;
} # got_enough_data

package Web::Encoding::UnivCharDet::ContextAnalysis::SJIS;
push our @ISA, qw(Web::Encoding::UnivCharDet::ContextAnalysis::Japanese);
our $VERSION = '1.0';

sub get_order ($$$) {
  my $char_len = 1;
  if (((ord substr $_[1], $_[2], 1) >= 0x81 and
       (ord substr $_[1], $_[2], 1) <= 0x9F) or
      ((ord substr $_[1], $_[2], 1) >= 0xE0 and
       (ord substr $_[1], $_[2], 1) <= 0xFC)) {
    $char_len = 2;
  }

  if ((substr $_[1], $_[2], 1) eq "\202" and
      (ord substr $_[1], $_[2] + 1, 1) >= 0x9F and
      (ord substr $_[1], $_[2] + 1, 1) <= 0xF1) {
    return ((ord substr $_[1], $_[2] + 1, 1) - 0x9F, $char_len);
  }

  return (-1, $char_len);
} # get_order

package Web::Encoding::UnivCharDet::ContextAnalysis::EUCJP;
push our @ISA, qw(Web::Encoding::UnivCharDet::ContextAnalysis::Japanese);
our $VERSION = '1.0';

sub get_order ($$$) {
  my $char_len = 1;
  if ((ord substr $_[1], $_[2], 1) == 0x8E or
      ((ord substr $_[1], $_[2], 1) >= 0xA1 and
       (ord substr $_[1], $_[2], 1) <= 0xFE)) {
    $char_len = 2;
  } elsif ((ord substr $_[1], $_[2], 1) == 0x8F) {
    $char_len = 3;
  }

  if ((ord substr $_[1], $_[2], 1) == 0xA4 and
      ((ord substr $_[1], $_[2] + 1, 1) >= 0xA1 and
       (ord substr $_[1], $_[2] + 1, 1) <= 0xF3)) {
    return ((ord substr $_[1], $_[2] + 1, 1) - 0xA1, $char_len);
  }

  return (-1, $char_len);
} # get_order

1;

=head1 LICENSE

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at <http://mozilla.org/MPL/2.0/>.

=cut
