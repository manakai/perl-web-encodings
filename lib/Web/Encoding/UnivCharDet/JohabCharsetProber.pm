package Web::Encoding::UnivCharDet::JohabCharsetProber;
use strict;
use warnings;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';
use Web::Encoding::UnivCharDet::Defs;
use Web::Encoding::UnivCharDet::Defs3;

sub new ($$) {
  my $self = bless {}, $_[0];
  $self->{is_preferred_lang} = $_[1];
  $self->{coding_sm} = Web::Encoding::UnivCharDet::CodingStateMachine->new
      (Web::Encoding::UnivCharDet::Defs::JohabSMModel);
  $self->reset;
  return $self;
} # new

sub reset ($) {
  my $self = $_[0];
  $self->{coding_sm}->reset;
  $self->{state} = 'detecting';
  $self->{distribution_analyser} = Web::Encoding::UnivCharDet::CharDistribAnalysis::Johab->new;
  $self->{distribution_analyser}->reset ($self->{is_preferred_lang});
  $self->{distribution_analyser}->{_parent} = ref $self;
  $self->{last_char} = "\x00\x00";
  $self->{current_word_length} = 0;
  $self->{avg_word_length} = 0;
} # reset

sub get_charset_name ($) { 'x-johab' }

sub handle_data ($$$;$) {
  my $self = $_[0];
  my $start_pos = $_[2] || 0;
  my $limit_pos = defined $_[3] ? $_[3] : length $_[1];
  for my $i ($start_pos..($limit_pos - 1)) {
    my $c = ord substr $_[1], $i, 1;
    my $coding_state = $self->{coding_sm}->next_state (substr $_[1], $i, 1);
    # eItsMe is used for other purpose.
    if ($coding_state == Web::Encoding::UnivCharDet::Defs::eStart) {
      my $char_len = $self->{coding_sm}->get_current_char_len;
      my $is_sep = 0;
      if ($i == $start_pos) {
        (substr $self->{last_char}, 1, 1) = substr $_[1], $start_pos, 1;
        $self->{distribution_analyser}->handle_one_char
            ($self->{last_char}, 0, $char_len);
        $is_sep = 1 unless $self->{last_char} =~ /^[\x84-\xD3]/;
      } else {
        $self->{distribution_analyser}->handle_one_char
            ($_[1], $i-1, $char_len);
        $is_sep = 1 unless substr ($_[1], $i-1, $char_len) =~ /^[\x84-\xD3]/;
      }
      if ($is_sep) {
        if ($self->{current_word_length}) {
          $self->{avg_word_length} = 0.9 * $self->{avg_word_length} + 0.1 * $self->{current_word_length};
          $self->{current_word_length} = 0;
        }
      } else {
        $self->{current_word_length}++;
      }
    }
  }

  substr ($self->{last_char}, 0, 1) = substr $_[1], $limit_pos - 1, 1;

  if ($self->{state} eq 'detecting') {
    if ($self->{coding_sm}->{error_count}) {
      #
    } elsif ($self->{distribution_analyser}->got_enough_data and
             $self->get_confidence > Web::Encoding::UnivCharDet::Defs::SHORTCUT_THRESHOLD) {
      $self->{state} = 'found it';
    }
  }
  
  return $self->{state};
} # handle_data

sub get_confidence ($) {
  my $self = $_[0];
  my $conf = $self->{distribution_analyser}->get_confidence;
  if ($conf < 0.5 and not $self->{coding_sm}->{error_count}) {
    $conf = 0.5;
  }

  {
    my $avg = $self->{avg_word_length};
    my $mu  = 3.0;
    my $sigma = 1.0;
    my $diff = $avg - $mu;
    my $score = exp( - ($diff * $diff) / (2 * $sigma * $sigma) );

    my $factor = 0.7 + 0.3 * $score;
    $conf *= $factor;
    $conf = 0.1 if $conf < 0.1;
  }
  
  return $conf;
} # get_confidence

sub got_min_data ($) {
  return $_[0]->{distribution_analyser}->got_min_data;
} # got_min_data

sub dump_status ($) {
  my $self = $_[0];
  printf "%s [%s] (%s, %s, %s, l=%d)\n",
      $self->get_confidence,
      $self->get_charset_name,
      $self->{state},
      $self->{coding_sm}->_dump_status,
      $self->{distribution_analyser}->_dump_status,
      $self->{avg_word_length};
} # dump_status

sub dump_status_for_json ($) {
  my $self = $_[0];
  return {
    type => $self->get_charset_name,
    charset => $self->get_charset_name,
    confidence => $self->get_confidence,
    coding_sm => $self->{coding_sm}->dump_status_for_json,
    distribution_analyser => $self->{distribution_analyser}->dump_status_for_json,
    avg_word_length => $self->{avg_word_length},
  };
} # dump_status_for_json

package Web::Encoding::UnivCharDet::CharDistribAnalysis::Johab;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharDistribAnalysis);
use Web::Encoding::UnivCharDet::CharDistribAnalysis;

sub _init ($) {
  $_[0]->{char_to_freq_order} = Web::Encoding::UnivCharDet::Defs::EUCKRCharToFreqOrder;
  $_[0]->{typical_distribution_ratio} = Web::Encoding::UnivCharDet::Defs::EUCKR_TYPICAL_DISTRIBUTION_RATIO;
} # _init

sub johab_to_euckr ($$) {
  my $x = ord substr $Web::Encoding::UnivCharDet::Defs::JohabCho,
      ($_[0] >> 2) & 0x1F, 1;
  my $y = ord substr $Web::Encoding::UnivCharDet::Defs::JohabJung,
      (($_[0] << 3) | ($_[1] >> 5)) & 0x1F, 1;
  my $z = ord substr $Web::Encoding::UnivCharDet::Defs::JohabJong,
      $_[1] & 0x1F, 1;

  if ($x == 0xff || $y == 0xff || $z == 0xff) {
    return -1;
  } else {
    return unpack 's', substr $Web::Encoding::UnivCharDet::Defs::JohabToEUCKROrder, ($x * 21*28 + $y * 28 + $z)*2, 2;
  }
} # johab_to_euckr

sub get_order ($$$) {
  my $c = ord substr $_[1], $_[2], 1;
  if (0x88 <= $c and $c <= 0xD3) {
    return johab_to_euckr $c, ord substr $_[1], $_[2] + 1, 1;
  } else {
    return -1;
  }
} # get_order


1;

=head1 AUTHOR

Wakaba <wakaba@suikawiki.org>.

=head1 ACKNOWLEDGEMENTS

This module derived from
<https://gitlab.freedesktop.org/uchardet/uchardet>.

=head1 LICENSE

/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is mozilla.org code.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 1998
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

=cut
