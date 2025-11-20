package Web::Encoding::UnivCharDet::UTFCharsetProber;
use strict;
use warnings;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

## This class simply looks for occurrences of zero bytes, and infers
## whether the file is UTF16 or UTF32 (low-endian or big-endian)
## For instance, files looking like ( \0 \0 \0 [nonzero] )+
## have a good probability to be UTF32BE.  Files looking like ( \0 [nonzero] )+
## may be guessed to be UTF16BE, and inversely for little-endian varieties.

## how many logical characters to scan before feeling confident of prediction
sub MIN_CHARS_FOR_DETECTION () { 20 }
sub MIN_CHARS_FOR_DETECTION_2 () { 5 }
## a fixed constant ratio of expected zeros or non-zeros in modulo-position.
sub EXPECTED_RATIO () { 0.94 }
sub EXPECTED_RATIO_2 () { 0.7 }
sub EXPECTED_RATIO_3 () { 0.1 }

sub new ($) {
  my $self = bless {}, $_[0];
  $self->reset;
  return $self;
} # new

sub reset ($) {
  my $self = $_[0];
  $self->{state} = 'detecting';
  $self->{position} = 0;
  $self->{zeros_at_mod} = [0, 0, 0, 0];
  $self->{nonzeros_at_mod} = [0, 0, 0, 0];
  $self->{quad} = [0, 0, 0, 0];
  delete $self->{invalid_utf16be};
  delete $self->{invalid_utf16le};
  delete $self->{invalid_utf32be};
  delete $self->{invalid_utf32le};
  delete $self->{first_half_surrogate_pair_detected_16be};
  delete $self->{first_half_surrogate_pair_detected_16le};
} # reset

sub _approx_32bit_chars ($) {
  my $x = $_[0]->{position} / 4.0;
  return $x < 1.0 ? 1.0 : $x;
} # _approx_32bit_chars

sub _approx_16bit_chars ($) {
  my $x = $_[0]->{position} / 2.0;
  return $x < 1.0 ? 1.0 : $x;
} # _approx_16bit_chars

sub _is_likely_utf32be ($$$) {
  my $self = $_[0];
  my $approx_chars = $self->_approx_32bit_chars;
  return (
    $approx_chars >= $_[1] and
    $self->{zeros_at_mod}->[0] / $approx_chars > EXPECTED_RATIO and
    $self->{zeros_at_mod}->[1] / $approx_chars > EXPECTED_RATIO and
    $self->{zeros_at_mod}->[2] / $approx_chars > $_[2] and
    $self->{nonzeros_at_mod}->[3] / $approx_chars > EXPECTED_RATIO and
    not $self->{invalid_utf32be}
  );
} # _is_likely_utf32be

sub _is_likely_utf32le ($$$) {
  my $self = $_[0];
  my $approx_chars = $self->_approx_32bit_chars;
  return (
    $approx_chars >= $_[1] and
    $self->{nonzeros_at_mod}->[0] / $approx_chars > EXPECTED_RATIO and
    $self->{zeros_at_mod}->[1] / $approx_chars > $_[2] and
    $self->{zeros_at_mod}->[2] / $approx_chars > EXPECTED_RATIO and
    $self->{zeros_at_mod}->[3] / $approx_chars > EXPECTED_RATIO and
    not $self->{invalid_utf32le}
  );
} # _is_likely_utf32le

sub _is_likely_utf16be ($$$) {
  my $self = $_[0];
  my $approx_chars = $self->_approx_16bit_chars;
  return (
    $approx_chars >= $_[1] and
    ($self->{nonzeros_at_mod}->[1] + $self->{nonzeros_at_mod}->[3]) / $approx_chars > EXPECTED_RATIO and
    ($self->{zeros_at_mod}->[0] + $self->{zeros_at_mod}->[2]) / $approx_chars > $_[2] and
    not $self->{invalid_utf16be}
  );
} # _is_likely_utf16be

sub _is_likely_utf16le ($$$) {
  my $self = $_[0];
  my $approx_chars = $self->_approx_16bit_chars;
  return (
    $approx_chars >= $_[1] and
    ($self->{nonzeros_at_mod}->[0] + $self->{nonzeros_at_mod}->[2]) / $approx_chars > EXPECTED_RATIO and
    ($self->{zeros_at_mod}->[1] + $self->{zeros_at_mod}->[3]) / $approx_chars > $_[2] and
    not $self->{invalid_utf16le}
  );
} # _is_likely_utf16le

sub _validate_utf32_characters ($$) {
  my ($self, $quad) = @_;
  if ($quad->[0] != 0 or
      $quad->[1] > 0x10 or
      ($quad->[0] == 0 and $quad->[1] == 0 and 0xD8 <= $quad->[2] <= 0xDF)) {
    $self->{invalid_utf32be} = 1;
  }
  if ($quad->[3] != 0 or
      $quad->[2] > 0x10 or
      ($quad->[3] == 0 and $quad->[2] == 0 and 0xD8 <= $quad->[1] <= 0xDF)) {
    $self->{invalid_utf32le} = 1;
  }
} # _validate_utf32_characters

sub _validate_utf16_characters ($$) {
  my ($self, $pair) = @_;
  if (not $self->{first_half_surrogate_pair_detected_16be}) {
    if (0xD8 <= $pair->[0] <= 0xDB) {
      $self->{first_half_surrogate_pair_detected_16be} = 1;
    } elsif (0xDC <= $pair->[0] <= 0xDF) {
      $self->{invalid_utf16be} = 1;
    }
  } else {
    if (0xDC <= $pair->[0] <= 0xDF) {
      $self->{first_half_surrogate_pair_detected_16be} = 0;
    } else {
      $self->{invalid_utf16be} = 1;
    }
  }
  if (not $self->{first_half_surrogate_pair_detected_16le}) {
    if (0xD8 <= $pair->[1] <= 0xDB) {
      $self->{first_half_surrogate_pair_detected_16le} = 1;
    } elsif (0xDC <= $pair->[1] <= 0xDF) {
      $self->{invalid_utf16le} = 1;
    }
  } else {
    if (0xDC <= $pair->[1] <= 0xDF) {
      $self->{first_half_surrogate_pair_detected_16le} = 0;
    } else {
      $self->{invalid_utf16le} = 1;
    }
  }
} # _validate_utf16_characters
  
sub handle_data ($$$;$) {
  my $self = $_[0];
  my $start_pos = $_[2] || 0;
  my $limit_pos = defined $_[3] ? $_[3] : length $_[1];
  for my $i ($start_pos..($limit_pos - 1)) {
    my $c = ord substr $_[1], $i, 1;
    
    my $mod4 = $self->{position} % 4;
    $self->{quad}->[$mod4] = $c;
    if ($mod4 == 3) {
      $self->_validate_utf32_characters ($self->{quad});
      $self->_validate_utf16_characters ($self->{quad});
      $self->_validate_utf16_characters ([$self->{quad}->[2], $self->{quad}->[3]]);
    }
    if ($c == 0) {
      $self->{zeros_at_mod}->[$mod4] += 1;
    } else {
      $self->{nonzeros_at_mod}->[$mod4] += 1;
    }
    $self->{position} += 1;
  } # $c

  if ($self->{state} eq 'found it' or
      $self->{state} eq 'not me') {
    return $self->{state};
  }
  if ($self->get_confidence > 0.80) {
    $self->{state} = 'found it';
  } elsif ($self->{position} > 4 * 1024) {
    ## if we get to 4kb into the file, and we can't conclude it's UTF,
    ## let's give up
    $self->{state} = 'not me';
  }
  return $self->{state};
} # handle_data

sub get_charset_name ($) {
  my $self = $_[0];

  return "utf-32be" if $self->_is_likely_utf32be (MIN_CHARS_FOR_DETECTION, EXPECTED_RATIO);
  return "utf-32le" if $self->_is_likely_utf32le (MIN_CHARS_FOR_DETECTION, EXPECTED_RATIO);
  return "utf-16be" if $self->_is_likely_utf16be (MIN_CHARS_FOR_DETECTION, EXPECTED_RATIO);
  return "utf-16le" if $self->_is_likely_utf16le (MIN_CHARS_FOR_DETECTION, EXPECTED_RATIO);

  return "utf-32be" if $self->_is_likely_utf32be (MIN_CHARS_FOR_DETECTION_2, EXPECTED_RATIO_2);
  return "utf-32le" if $self->_is_likely_utf32le (MIN_CHARS_FOR_DETECTION_2, EXPECTED_RATIO_2);
  return "utf-16be" if $self->_is_likely_utf16be (MIN_CHARS_FOR_DETECTION_2, EXPECTED_RATIO_2);
  return "utf-16le" if $self->_is_likely_utf16le (MIN_CHARS_FOR_DETECTION_2, EXPECTED_RATIO_2);

  my $approx_chars16 = $self->_approx_16bit_chars;
  if (($self->{zeros_at_mod}->[0] + $self->{zeros_at_mod}->[2]) / $approx_chars16 > EXPECTED_RATIO_3) {
    return 'utf-16be';
  }
  if (($self->{zeros_at_mod}->[1] + $self->{zeros_at_mod}->[3]) / $approx_chars16 > EXPECTED_RATIO_3) {
    return 'utf-16le';
  }

  return undef;
} # get_charset_name

sub get_confidence ($) {
  my $self = $_[0];
  
  return 0.85 if 
      $self->_is_likely_utf16le (MIN_CHARS_FOR_DETECTION, EXPECTED_RATIO) or
      $self->_is_likely_utf16be (MIN_CHARS_FOR_DETECTION, EXPECTED_RATIO) or
      $self->_is_likely_utf32le (MIN_CHARS_FOR_DETECTION, EXPECTED_RATIO) or
      $self->_is_likely_utf32be (MIN_CHARS_FOR_DETECTION, EXPECTED_RATIO);
  
  return 0.60 if 
      $self->_is_likely_utf16le (MIN_CHARS_FOR_DETECTION_2,EXPECTED_RATIO_2) or
      $self->_is_likely_utf16be (MIN_CHARS_FOR_DETECTION_2,EXPECTED_RATIO_2) or
      $self->_is_likely_utf32le (MIN_CHARS_FOR_DETECTION_2,EXPECTED_RATIO_2) or
      $self->_is_likely_utf32be (MIN_CHARS_FOR_DETECTION_2, EXPECTED_RATIO_2);

  my $approx_chars16 = $self->_approx_16bit_chars;
  if (($self->{zeros_at_mod}->[0] + $self->{zeros_at_mod}->[2]) / $approx_chars16 > EXPECTED_RATIO_3) {
    return 0.30;
  }
  if (($self->{zeros_at_mod}->[1] + $self->{zeros_at_mod}->[3]) / $approx_chars16 > EXPECTED_RATIO_3) {
    return 0.30;
  }

  return 0.01;
} # get_confidence

sub dump_status ($) {
  my $self = $_[0];
  printf "UTFCharsetProber: %1.3f [%s] (invalid 32: %d/%d)\n",
      $self->get_confidence, $self->get_charset_name // '',
      $self->{invalid_utf32be} || 0, $self->{invalid_utf32le} || 0;

  my $approx_chars16 = $self->_approx_16bit_chars;
  printf "  UTF-16BE [%d]: [0]%.3f [1]%.3f (invalid: %d)\n",
      $approx_chars16,
      ($self->{zeros_at_mod}->[0] + $self->{zeros_at_mod}->[2]) / $approx_chars16,
      ($self->{nonzeros_at_mod}->[1] + $self->{nonzeros_at_mod}->[3]) / $approx_chars16,
      $self->{invalid_utf16be} || 0;
  printf "  UTF-16LE [%d]: [1]%.3f [0]%.3f (invalid: %d)\n",
      $approx_chars16,
      ($self->{nonzeros_at_mod}->[0] + $self->{nonzeros_at_mod}->[2]) / $approx_chars16,
      ($self->{zeros_at_mod}->[1] + $self->{zeros_at_mod}->[3]) / $approx_chars16,
      $self->{invalid_utf16le} || 0;
      
} # dump_status

sub dump_status_for_json ($) {
  my $self = $_[0];
  return {type => ref $self,
          charset => $self->get_charset_name,
          confidence => $self->get_confidence};
} # dump_status_for_json

1;

=head1 AUTHOR

Wakaba <wakaba@suikawiki.org>.

=head1 ACKNOWLEDGEMENTS

This module derived from the latest version of
<https://github.com/chardet/chardet/blob/main/chardet/utf1632prober.py>
as of 19 October Reiwa 7 (2025), i.e.
<https://github.com/chardet/chardet/commit/c4f7057f57c02af919496c57fe422e2edeef9bc8>.

=head1 LICENSE

######################## BEGIN LICENSE BLOCK ########################
#
# Contributor(s):
#   Wakaba <wakaba@suikawiki.org>
#   Jason Zavaglia
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
