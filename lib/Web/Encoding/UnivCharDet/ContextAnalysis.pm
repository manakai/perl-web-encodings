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
  $self->{signature_count} = 0;
  $self->{state} = 0;
  $self->{kana_count} = 0;
  $self->{non_kana_count} = 0;
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

  my $order = -1;
  if ($_[3] == 2) {
    ($order) = $self->get_order ($_[1], $_[2]);
  } else {
    $self->{state} = 0;
  }
  
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
  } elsif ($self->{kana_count} / ($self->{kana_count} + $self->{non_kana_count} + 1e-7) > 0.8) {
    ## Short string of Kana letters
    return 0.5;
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
  my $self = $_[0];
  my $f = ord substr $_[1], $_[2], 1;
  my $s = ord substr $_[1], $_[2] + 1, 1;
  
  my $char_len = 1;
  if ($f == 0x8E or ($f >= 0xA1 and $f <= 0xFE)) {
    $char_len = 2;
  } elsif ($f == 0x8F) {
    $char_len = 3;
  }

  if ($f == 0xA4 and ($s >= 0xA1 and $s <= 0xF3)) {
    $self->{state} = 0;
    $self->{kana_count}++;
    return ($s - 0xA1, $char_len);
  }

  if ($f == 0xA5 and ($s >= 0xA1 and $s <= 0xF3)) {
    $self->{kana_count}++;
  } else {
    $self->{non_kana_count}++;
  }

  ## EUC-JP signatures advocated by the most popular portal site and
  ## the most famous HTML reference site in early-Heisei days (1990s)
  ## of Japan:
  ##   <https://web.archive.org/web/20030202085121/http://docs.yahoo.co.jp/docs/help/mojibake/sonota.html>
  ##   <https://www.tohoho-web.com/wwwxx005.htm#spell-character>
  ##   <https://wiki.suikawiki.org/n/%E6%96%87%E5%AD%97%E3%82%B3%E3%83%BC%E3%83%89%E8%87%AA%E5%8B%95%E5%88%A4%E5%88%A5#section-%E6%96%87%E5%AD%97%E3%82%B3%E3%83%BC%E3%83%89%E3%81%AE%E6%B1%BA%E5%AE%9A%E2%80%A8%E3%83%90%E3%82%A4%E3%83%88%E5%88%97%E7%AD%89%E3%81%8B%E3%82%89%E3%81%AE%E6%8E%A8%E5%AE%9A%E2%80%A8%E5%88%A4%E5%AE%9A%E5%99%A8%E3%82%92%E6%84%8F%E8%AD%98%E3%81%97%E3%81%9F%E8%91%97%E8%80%85%E3%81%AB%E3%82%88%E3%82%8B%E8%A8%98%E8%BF%B0>.
  if (($f == 0xFD and $s == 0xFE) or # 0xFDFE : an unassigned code point
      ($f == 0xF3 and $s == 0xFE) or
      #($f == 0xB9 and $s == 0xA7) or # EUC "孝", SJIS "ｹｧ" (ｹｧ could be part of slang or something, so not a good signature)
      ($f == 0xEB and $s == 0xFD) or
      ($f == 0xC4 and $s == 0xF0) or
      ($f == 0xF3 and $s == 0xFD)) {
    $self->{signature_count}++;
    $self->{state} = 0;
  } elsif ($f == 0xC8 and $s == 0xFE) {
    $self->{state} = 1;
  } elsif ($self->{state} == 1 and $f == 0xC6 and $s == 0xFD) {
    $self->{signature_count}++;
    $self->{state} = 0;
  } else {
    $self->{state} = 0;
  }
  
  return (-1, $char_len);
} # get_order

1;

=head1 LICENSE

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at <http://mozilla.org/MPL/2.0/>.

=cut
