package Web::Encoding::UnivCharDet::CodingStateMachine;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::Encoding::UnivCharDet::Defs;

sub GETFROMPCK ($$) {
  ($_[1]->{data}->[$_[0]>>$_[1]->{idxsft}] >> (($_[0]&$_[1]->{sftmsk})<<$_[1]->{bitsft}))&$_[1]->{unitmsk};
} # GETFROMPCK

sub new ($$) {
  my $self = bless {}, $_[0];
  $self->reset;
  $self->{model} = $_[1];
  return $self;
} # new

sub reset ($) {
  my $self = $_[0];
  $self->{current_state} = Web::Encoding::UnivCharDet::Defs::eStart;
  $self->{error_count} = 0;
  $self->{latin1_state} = 1;
  $self->{latin1_count} = 0;
  $self->{current_char_len} = 0;
} # reset

my $Latin1Type = [
  0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0,
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 0, 0, 1, 0, 1, 0,
  0, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1, 0, 1, 0, 0,
  0, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1, 0, 1, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 7, 0, 7, 7, 0, 6, 5, 5, 2, 5, 5, 5, 5, 5, 5,
  6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
  6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
  6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 5, 5,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
];

sub next_state ($$) {
  my $self = $_[0];
  my $cc = ord $_[1];
  my $byte_cls = GETFROMPCK ($cc, $self->{model}->{class_table});
  my $mb = 0;
  if ($self->{current_state} == Web::Encoding::UnivCharDet::Defs::eStart) {
    if ($self->{current_char_len} > 1) {
      $mb = 1;
    }
    $self->{current_byte_pos} = 0;
    $self->{current_char_len} = $self->{model}->{char_len_table}->[$byte_cls];
  }
  my $state = $self->{current_state} = GETFROMPCK ($self->{current_state} * $self->{model}->{class_factor} + $byte_cls, $self->{model}->{state_table});
  if ($state == Web::Encoding::UnivCharDet::Defs::eError) {
    $self->{error_count}++;
  }
  $self->{current_byte_pos}++;
  if ($self->{latin1_state} == 1 and $Latin1Type->[$cc] == 2) {
    $self->{latin1_state} = 2;
  } elsif ($self->{latin1_state} == 1 and $Latin1Type->[$cc] == 7) {
    $self->{latin1_count}++;
    $self->{latin1_state} = 0;
  } elsif ($self->{latin1_state} == 2 and
           ($Latin1Type->[$cc] == 1 or
            $Latin1Type->[$cc] == 3 or
            $Latin1Type->[$cc] == 4)) {
    $self->{latin1_count}++;
    $self->{latin1_state} = 0;
  } elsif ($Latin1Type->[$cc] == 1) {
    $self->{latin1_state} = 1;
  } elsif ($Latin1Type->[$cc] == 6) {
    $self->{latin1_state} = 3;
  } elsif ($Latin1Type->[$cc] == 5 || $Latin1Type->[$cc] == 2) {
    unless ($mb or $self->{latin1_state} == 3) {
      $self->{latin1_count}++;
    }
    $self->{latin1_state} = 3;
  }
  return $state;
} # next_state

sub get_current_char_len ($) {
  return $_[0]->{current_char_len};
} # get_current_char_len

sub get_coding_state_machine {
  return $_[0]->{model}->{name};
} # get_coding_state_machine

sub _dump_status ($) {
  my $self = $_[0];
  return sprintf "%s / %d l=%d e=%d",
      $self->{current_state},
      $self->{current_byte_pos} || 0,
      $self->{latin1_count},
      $self->{error_count};
} # _dump_status

sub dump_status_for_json ($) {
  my $self = $_[0];
  return {
    current_state => $self->{current_state},
    error_count => $self->{error_count},
    latin1_count => $self->{latin1_count},
  };
} # dump_status_for_json

1;

=head1 LICENSE

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at <http://mozilla.org/MPL/2.0/>.

=cut
