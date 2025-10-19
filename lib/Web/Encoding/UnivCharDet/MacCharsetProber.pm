package Web::Encoding::UnivCharDet::MacCharsetProber;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::Encoding::UnivCharDet::CharsetProber;

package Web::Encoding::UnivCharDet::MacCharsetProber::MacRoman;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub FREQ_CAT_NUM () { 4 }
sub UDF () { 0 }
sub OTH () { 1 }
sub ASC () { 2 }
sub ASS () { 3 }
sub ACV () { 4 }
sub ACO () { 5 }
sub ASV () { 6 }
sub ASO () { 7 }
sub ODD () { 8 }
sub CLASS_NUM () { 9 }

# The change from Latin1 is that we explicitly look for extended characters
# that are infrequently-occurring symbols, and consider them to always be
# improbable. This should let MacRoman get out of the way of more likely
# encodings in most situations.

my $MacRoman_CharToClass = [
    OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,  # 00 - 07
    OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,  # 08 - 0F
    OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,  # 10 - 17
    OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,  # 18 - 1F
    OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,  # 20 - 27
    OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,  # 28 - 2F
    OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,  # 30 - 37
    OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,  # 38 - 3F
    OTH, ASC, ASC, ASC, ASC, ASC, ASC, ASC,  # 40 - 47
    ASC, ASC, ASC, ASC, ASC, ASC, ASC, ASC,  # 48 - 4F
    ASC, ASC, ASC, ASC, ASC, ASC, ASC, ASC,  # 50 - 57
    ASC, ASC, ASC, OTH, OTH, OTH, OTH, OTH,  # 58 - 5F
    OTH, ASS, ASS, ASS, ASS, ASS, ASS, ASS,  # 60 - 67
    ASS, ASS, ASS, ASS, ASS, ASS, ASS, ASS,  # 68 - 6F
    ASS, ASS, ASS, ASS, ASS, ASS, ASS, ASS,  # 70 - 77
    ASS, ASS, ASS, OTH, OTH, OTH, OTH, OTH,  # 78 - 7F
    ACV, ACV, ACO, ACV, ACO, ACV, ACV, ASV,  # 80 - 87
    ASV, ASV, ASV, ASV, ASV, ASO, ASV, ASV,  # 88 - 8F
    ASV, ASV, ASV, ASV, ASV, ASV, ASO, ASV,  # 90 - 97
    ASV, ASV, ASV, ASV, ASV, ASV, ASV, ASV,  # 98 - 9F
    OTH, OTH, OTH, OTH, OTH, OTH, OTH, ASO,  # A0 - A7
    OTH, OTH, ODD, ODD, OTH, OTH, ACV, ACV,  # A8 - AF
    OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,  # B0 - B7
    OTH, OTH, OTH, OTH, OTH, OTH, ASV, ASV,  # B8 - BF
    OTH, OTH, ODD, OTH, ODD, OTH, OTH, OTH,  # C0 - C7
    OTH, OTH, OTH, ACV, ACV, ACV, ACV, ASV,  # C8 - CF
    OTH, OTH, OTH, OTH, OTH, OTH, OTH, ODD,  # D0 - D7
    ASV, ACV, ODD, OTH, OTH, OTH, OTH, OTH,  # D8 - DF
    OTH, OTH, OTH, OTH, OTH, ACV, ACV, ACV,  # E0 - E7
    ACV, ACV, ACV, ACV, ACV, ACV, ACV, ACV,  # E8 - EF
    ODD, ACV, ACV, ACV, ACV, ASV, ODD, ODD,  # F0 - F7
    ODD, ODD, ODD, ODD, ODD, ODD, ODD, ODD,  # F8 - FF
];

# 0 : illegal
# 1 : very unlikely
# 2 : normal
# 3 : very likely
my $MacRomanClassModel = [
# UDF OTH ASC ASS ACV ACO ASV ASO ODD
    0,  0,  0,  0,  0,  0,  0,  0,  0,  # UDF
    0,  3,  3,  3,  3,  3,  3,  3,  1,  # OTH
    0,  3,  3,  3,  3,  3,  3,  3,  1,  # ASC
    0,  3,  3,  3,  1,  1,  3,  3,  1,  # ASS
    0,  3,  3,  3,  1,  2,  1,  2,  1,  # ACV
    0,  3,  3,  3,  3,  3,  3,  3,  1,  # ACO
    0,  3,  1,  3,  1,  1,  1,  3,  1,  # ASV
    0,  3,  1,  3,  1,  1,  3,  3,  1,  # ASO
    0,  1,  1,  1,  1,  1,  1,  1,  1,  # ODD
];

sub new ($) {
  my $self = bless {}, $_[0];
  $self->reset;
  return $self;
} # new

sub reset ($) {
  my $self = $_[0];
  $self->{state} = 'detecting';
  $self->{last_char_class} = OTH;
  $self->{freq_counter}->[$_] = 0 for 0..(FREQ_CAT_NUM - 1);

  # express the prior that MacRoman is a somewhat rare encoding; this
  # can be done by starting out in a slightly improbable state that
  # must be overcome
  $self->{freq_counter}->[2] = 10;
} # reset

sub get_charset_name ($) { 'macintosh' }

sub handle_data ($$) {
  my $self = $_[0];
  my $new_buf1 = $self->filter_with_english_letters ($_[1]);

  for my $i (0..((length $new_buf1) - 1)) {
    my $c = ord substr $new_buf1, $i, 1;
    my $char_class = $MacRoman_CharToClass->[$c];
    my $freq = $MacRomanClassModel->[$self->{last_char_class}*CLASS_NUM + $char_class];
    if ($freq == 0) {
      $self->{state} = 'not me';
      last;
    }
    $self->{freq_counter}->[$freq]++;
    $self->{last_char_class} = $char_class;
  } # $i

  return $self->{state};
} # handle_data

sub get_confidence ($) {
  my $self = $_[0];
  if ($self->{state} eq 'not me') {
    return 0.01;
  }

  my $total = 0;
  for my $i (0..(FREQ_CAT_NUM - 1)) {
    $total += $self->{freq_counter}->[$i];
  }

  my $confidence;
  if ($total < 0.01) {
    $confidence = 0.0;
  } else {
    $confidence = ($self->{freq_counter}->[3] - $self->{freq_counter}->[1] * 20.0) / $total;
  }
  $confidence = 0.0 if $confidence < 0.0;

  ## lower the confidence of MacRoman so that other more accurate
  ## detector can take priority.
  $confidence *= 0.73;

  return $confidence;
} # get_confidence

sub dump_status ($) {
  my $self = $_[0];
  printf " MacRomanProber: %1.3f [%s]\n",
      $self->get_confidence, $self->get_charset_name;
} # dump_status

1;

=head1 AUTHOR

Wakaba <wakaba@suikawiki.org>.

=head1 ACKNOWLEDGEMENTS

This module derived from
<https://github.com/chardet/chardet/commit/c292b52a97e57c95429ef559af36845019b88b33>.

=head1 LICENSE

######################## BEGIN LICENSE BLOCK ########################
# This code was modified from latin1prober.py by Rob Speer <rob@lumino.so>.
# The Original Code is Mozilla Universal charset detector code.
#
# The Initial Developer of the Original Code is
# Netscape Communications Corporation.
# Portions created by the Initial Developer are Copyright (C) 2001
# the Initial Developer. All Rights Reserved.
#
# Contributor(s):
#   Wakaba <wakaba@suikawiki.org>
#   Rob Speer - adapt to MacRoman encoding
#   Mark Pilgrim - port to Python
#   Shy Shalom - original C code
#
# This library is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# This library is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public
# License along with this library; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA
# 02110-1301  USA
######################### END LICENSE BLOCK #########################

=cut
