package Web::Encoding::Decoder;
use strict;
use warnings;
our $VERSION = '1.0';
use Carp;
use Web::Encoding;

push our @CARP_NOT, qw(Web::Encoding);

sub new_from_encoding_key ($$) {
  return bless {
    key => $_[1],
    states => {},
  }, $_[0];
} # new_from_encoding_key

sub ignore_bom ($;$) {
  if (@_ > 1) {
    $_[0]->{ignore_bom} = $_[1];
  }
  return $_[0]->{ignore_bom};
} # ignore_bom

sub fatal ($;$) {
  if (@_ > 1) {
    $_[0]->{fatal} = 1;
  }
  return $_[0]->{fatal};
} # fatal

sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} || sub { };
} # onerror

sub _onerror ($) {
  my $onerror = $_[0]->{onerror};
  return $_[0]->{fatal} ? sub {
    my %args = @_;
    my $fatal = delete $args{fatal};
    $onerror->(%args);
    die "Input has invalid bytes" if $fatal;
  } : $onerror || sub { };
} # _onerror

sub used_encoding_key ($) {
  return $_[0]->{key};
} # used_encoding_key

sub _u16 ($$$$$) {
  #$states, $u, \@s, $onerror, $index;
  if ($_[1] < 0xD800 or 0xDFFF < $_[1]) {
    if (defined $_[0]->{lead_surrogate}) {
      $_[3]->(type => 'utf-16:lone high surrogate', level => 'm', fatal => 1,
              index => $_[0]->{index} + $_[4] - 2,
              text => sprintf '0x%04X', $_[0]->{lead_surrogate});
      push @{$_[2]}, "\x{FFFD}";
      delete $_[0]->{lead_surrogate};
    }
    push @{$_[2]}, chr $_[1];
  } elsif ($_[1] <= 0xDBFF) { # [U+D800, U+DBFF]
    if (defined $_[0]->{lead_surrogate}) {
      $_[3]->(type => 'utf-16:lone high surrogate', level => 'm', fatal => 1,
              index => $_[0]->{index} + $_[4] - 2,
              text => sprintf '0x%04X', $_[0]->{lead_surrogate});
      push @{$_[2]}, "\x{FFFD}";
      delete $_[0]->{lead_surrogate};
    }
    $_[0]->{lead_surrogate} = $_[1];
  } else { # [U+DC00, U+DFFF]
    if (defined $_[0]->{lead_surrogate}) {
      push @{$_[2]}, chr (0x10000
                          + ((delete ($_[0]->{lead_surrogate}) - 0xD800) << 10)
                          + $_[1] - 0xDC00);
    } else {
      $_[3]->(type => 'utf-16:lone low surrogate', level => 'm', fatal => 1,
              index => $_[0]->{index} + $_[4],
              text => sprintf '0x%04X', $_[1]);
      push @{$_[2]}, "\x{FFFD}";
    }
  }
} # _u16

sub _decode_16 ($$$$$) {
  my $states = $_[0];
  #my $onerror = $_[1];
  #my $is_last = $_[3];
  #my $endian = $_[4]
  my $offset = 0;
  my @s;
  my $len = length $_[2];
  if (defined $states->{lead_byte}) {
    if ($len) {
      my $lead = unpack 'C', delete $states->{lead_byte};
      my $sec = unpack 'C', substr $_[2], 0, 1;
      if ($_[4] eq 'n') {
        _u16 $states, $lead * 0x100 + $sec, \@s, $_[1], -1;
      } else {
        _u16 $states, $sec * 0x100 + $lead, \@s, $_[1], -1;
      }
      $offset++;
    } else { # empty
      if ($_[3]) { # $is_last
        $_[1]->(type => 'utf-16:lone byte', level => 'm', fatal => 1,
                index => $states->{index} - 1, value => $states->{lead_byte});
        push @s, "\x{FFFD}";
        delete $states->{lead_surrogate};
      }
    }
  }
  my $Length = ($len - $offset) / 2;
  my $length = int $Length;
  my $i = 0;
  while ($i < $length) {
    _u16 $states, (unpack $_[4], substr $_[2], $offset + $i * 2, 2), \@s, $_[1], $offset + $i * 2;
    $i++;
  }
  if (defined $states->{lead_surrogate} and $_[3]) { # $is_last
    $_[1]->(type => 'utf-16:lone high surrogate', level => 'm', fatal => 1,
            index => $states->{index} + $len - 2,
            text => sprintf '0x%04X', $_[0]->{lead_surrogate});
    push @s, "\x{FFFD}";
  } elsif ($length != $Length) {
    if ($_[3]) { # $is_last
      $_[1]->(type => 'utf-16:lone byte', level => 'm', fatal => 1,
              index => $states->{index} + $len - 1,
              value => substr $_[2], -1);
      push @s, "\x{FFFD}";
    } else {
      $states->{lead_byte} = substr $_[2], -1;
    }
  }

  $states->{index} += $len;

  ## @s can't contain an empty string for the convenience of later BOM
  ## stripping.
  return \@s;
} # _decode_16

sub _gb ($$$$$) {
  # $b1 $b2 $out $index_offset $onerror
  if ($_[1] < 0x40 or $_[1] == 0x7F or $_[1] == 0xFF) {
    push @{$_[2]}, "\x{FFFD}";
    $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
            index => $_[3], value => pack 'CC', $_[0], $_[1]);
    push @{$_[2]}, chr $_[1] if $_[1] < 0x80;
  } else {
    my $pointer = ($_[0] - 0x81) * 190 + $_[1] - ($_[1] < 0x7F ? 0x40 : 0x41);
    my $c = $Web::Encoding::_GB::DecodeIndex->[$pointer];
    if (defined $c) {
      if ($pointer == (0xA3 - 0x81) * 190 + 0xA0 - 0x41) {
        $_[4]->(type => 'encoding:not canonical', level => 'w',
                index => $_[3], value => pack 'CC', $_[0], $_[1]);
      }
      push @{$_[2]}, $c;
    } else {
      if ($_[1] < 0x80) {
        push @{$_[2]}, "\x{FFFD}", chr $_[1];
        $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
                index => $_[3], value => pack 'CC', $_[0], $_[1]);
      } else {
        push @{$_[2]}, "\x{FFFD}";
        $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
                index => $_[3], value => pack 'CC', $_[0], $_[1]);
      }
    }
  }
} # _gb

sub _gb4 ($$$$$$) {
  # $b1b2 $b3 $b4 $out $index_offset $onerror
  my $pointer = ($_[0]->[0] - 0x81) * (10 * 126 * 10)
      + ($_[0]->[1] - 0x30) * (10 * 126)
      + ($_[1] - 0x81) * 10
      + $_[2] - 0x30;

  if (($pointer > 39419 and $pointer < 189000) or $pointer > 1237575) {
    push @{$_[3]}, "\x{FFFD}";
    $_[5]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
            index => $_[4],
            value => pack 'CCCC', $_[0]->[0], $_[0]->[1], $_[1], $_[2]);
    return undef;
  }

  if ($pointer == 7457) {
    push @{$_[3]}, "\x{E7C7}";
    return undef;
  }

  my $offset;
  my $cp;
  for (@{$Web::Encoding::_GB::Ranges}) {
    if ($_->[0] <= $pointer) {
      $offset = $_->[0];
      $cp = $_->[1];
    }
  }
  push @{$_[3]}, chr ($cp + $pointer - $offset);
  return undef;
} # _gb4

sub _b5 ($$$$$) {
  # $b1 $b2 $out $index_offset $onerror
  if ((0x7F <= $_[1] and $_[1] <= 0xA0) or $_[1] == 0xFF) {
    push @{$_[2]}, "\x{FFFD}";
    $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
            index => $_[3], value => pack 'CC', $_[0], $_[1]);
    push @{$_[2]}, chr $_[1] if $_[1] < 0x80;
  } else {
    my $pointer = ($_[0] - 0x81) * 157
        + $_[1] - ($_[1] < 0x7F ? 0x40 : 0x62);
    my $c = $Web::Encoding::_Big5::DecodeIndex->[$pointer];
    if (defined $c) {
      if ($pointer < (0xA1 - 0x81) * 157) {
        $_[4]->(type => 'big5:hkscs', level => 'w',
                index => $_[3], value => pack 'CC', $_[0], $_[1]);
      } elsif ($Web::Encoding::_Big5::NonCanonical->{$pointer}) {
        $_[4]->(type => 'encoding:not canonical', level => 'w',
                index => $_[3], value => pack 'CC', $_[0], $_[1]);
      }
      push @{$_[2]}, $c;
    } else {
      if ($_[1] < 0x80) {
        push @{$_[2]}, "\x{FFFD}", chr $_[1];
        $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
                index => $_[3], value => pack 'CC', $_[0], $_[1]);
      } else {
        push @{$_[2]}, "\x{FFFD}";
        $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
                index => $_[3], value => pack 'CC', $_[0], $_[1]);
      }
    }
  }
} # _b5

sub _kr ($$$$$) {
  # $b1 $b2 $out $index_offset $onerror
  if ($_[1] < 0x41 or $_[1] == 0xFF) {
    push @{$_[2]}, "\x{FFFD}";
    $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
            index => $_[3], value => pack 'CC', $_[0], $_[1]);
    push @{$_[2]}, chr $_[1] if $_[1] < 0x80;
  } else {
    my $pointer = ($_[0] - 0x81) * 190 + $_[1] - 0x41;
    my $c = $Web::Encoding::_EUCKR::DecodeIndex->[$pointer];
    if (defined $c) {
      push @{$_[2]}, $c;
    } else {
      if ($_[1] < 0x80) {
        push @{$_[2]}, "\x{FFFD}", chr $_[1];
        $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
                index => $_[3], value => pack 'CC', $_[0], $_[1]);
      } else {
        push @{$_[2]}, "\x{FFFD}";
        $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
                index => $_[3], value => pack 'CC', $_[0], $_[1]);
      }
    }
  }
} # _kr

sub _sjis ($$$$$) {
  # $b1 $b2 $out $index_offset $onerror
  unless (0x40 <= $_[1] and $_[1] <= 0xFC and not $_[1] == 0x7F) {
    push @{$_[2]}, "\x{FFFD}";
    $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
            index => $_[3], value => pack 'CC', $_[0], $_[1]);
    push @{$_[2]}, chr $_[1] if $_[1] < 0x80;
  } else {
    my $pointer = ($_[0] - ($_[0] < 0xA0 ? 0x81 : 0xC1)) * 188
        + $_[1] - ($_[1] < 0x7F ? 0x40 : 0x41);
    my $c = $Web::Encoding::_JIS::DecodeIndex->[$pointer];
    if (defined $c) {
      if ((8272 <= $pointer and $pointer <= 8835) or
          $Web::Encoding::_JIS::NonCanonicalSJIS->{$pointer}) {
        $_[4]->(type => 'encoding:not canonical', level => 'w',
                index => $_[3], value => pack 'CC', $_[0], $_[1]);
      }
      push @{$_[2]}, $c;
    } elsif (8836 <= $pointer and $pointer <= 10715) {
      ## EUDC.  Though they are not roundtrippable, we don't emit any
      ## warning here, as we will report them at Unicode character
      ## validation.  PUA code points are not interoperable anyway.
      push @{$_[2]}, chr (0xE000 - 8836 + $pointer);
    } else {
      if ($_[1] < 0x80) {
        push @{$_[2]}, "\x{FFFD}", chr $_[1];
        $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
                index => $_[3], value => pack 'CC', $_[0], $_[1]);
      } else {
        push @{$_[2]}, "\x{FFFD}";
        $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
                index => $_[3], value => pack 'CC', $_[0], $_[1]);
      }
    }
  }
} # _sjis

sub _jis ($$$$$$) {
  # $b1 $b2 $out $index_offset $onerror $delta
  unless (0xA1 <= $_[1] and $_[1] <= 0xFE) {
    push @{$_[2]}, "\x{FFFD}";
    $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
            index => $_[3],
            value => pack 'CC', $_[0] - $_[5], $_[1] - $_[5]);
  } elsif ($_[0] == 0x8E) {
    if ($_[1] <= 0xDF) {
      push @{$_[2]}, chr (0xFF61 - 0xA1 + $_[1]);
    } else {
      push @{$_[2]}, "\x{FFFD}";
      $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
              index => $_[3],
              value => pack 'CC', $_[0] - $_[5], $_[1] - $_[5]);
    }
  } else {
    my $pointer = ($_[0] - 0xA1) * 94 + $_[1] - 0xA1;
    my $c = $Web::Encoding::_JIS::DecodeIndex->[$pointer];
    if (defined $c) {
      push @{$_[2]}, $c;
      if ($Web::Encoding::_JIS::NonCanonicalEUC->{$pointer}) {
        $_[4]->(type => 'encoding:not canonical', level => 'w',
                index => $_[3],
                value => pack 'CC', $_[0] - $_[5], $_[1] - $_[5]);
      }
    } else {
      push @{$_[2]}, "\x{FFFD}";
      $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
              index => $_[3],
              value => pack 'CC', $_[0] - $_[5], $_[1] - $_[5]);
    }
  }
} # _jis

sub _eucjp0212 ($$$$$) {
  # $b1 $b2 $out $index_offset $onerror
  unless (0xA1 <= $_[1] and $_[1] <= 0xFE) {
    push @{$_[2]}, "\x{FFFD}";
    $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
            index => $_[3], value => pack 'CCC', 0x8F, $_[0], $_[1]);
  } else {
    my $pointer = ($_[0] - 0xA1) * 94 + $_[1] - 0xA1;
    my $c = $Web::Encoding::_JIS::DecodeIndex0212->[$pointer];
    if (defined $c) {
      push @{$_[2]}, $c;
      $_[4]->(type => 'eucjp:0212', level => 'w',
              index => $_[3], value => pack 'CCC', 0x8F, $_[0], $_[1]);
    } else {
      push @{$_[2]}, "\x{FFFD}";
      $_[4]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
              index => $_[3], value => pack 'CCC', 0x8F, $_[0], $_[1]);
    }
  }
} # _eucjp0212

sub _decode_mb ($$$$$) {
  # $states $s $final $onerror $char
  $_[0]->{index} = 0 unless defined $_[0]->{index};
  my @s;
  pos ($_[1]) = 0;
  if (defined $_[0]->{lead_byte}) {
    if ($_[1] =~ /\G([\x40-\xFF])/gc) {
      $_[4]->($_[0]->{lead_byte}, ord $1, \@s, $_[0]->{index} - 1, $_[3]);
      delete $_[0]->{lead_byte};
    } elsif ($_[1] eq '' and not $_[2]) {
      #
    } else {
      push @s, "\x{FFFD}";
      $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
              index => $_[0]->{index} - 1, value => pack 'C', $_[0]->{lead_byte});
      delete $_[0]->{lead_byte};
    }
  } # lead_byte
  while ($_[1] =~ m{
    \G(?:
      ([\x81-\xFE](?:[\x40-\xFF]|(\z)?)) |
      ([\x80\xFF]) |
      ([\x00-\x7F]+)
    )
  }gx) {
    if (defined $1) {
      if (2 == length $1) {
        $_[4]->(ord substr ($1, 0, 1), ord substr ($1, 1, 1), \@s, $_[0]->{index} + $-[0], $_[3]);
      } else {
        if (defined $2 and not $_[2]) {
          $_[0]->{lead_byte} = ord $1;
        } else {
          push @s, "\x{FFFD}";
          $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
                  index => $_[0]->{index} + $-[0], value => $1);
        }
      }
    } elsif (defined $3) {
      push @s, "\x{FFFD}";
      $_[3]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
              index => $_[0]->{index} + $-[0], value => $3);
    } else {
      push @s, $4;
    }
  }
  $_[0]->{index} += length $_[1];
  return \@s;
} # _decode_mb

sub _decode_sjis ($$$$) {
  # $states $s $final $onerror
  $_[0]->{index} = 0 unless defined $_[0]->{index};
  my @s;
  pos ($_[1]) = 0;
  if (defined $_[0]->{lead_byte}) {
    if ($_[1] =~ /\G([\x40-\xFF])/gc) {
      _sjis $_[0]->{lead_byte}, ord $1, \@s, $_[0]->{index} - 1, $_[3];
      delete $_[0]->{lead_byte};
    } elsif ($_[1] eq '' and not $_[2]) {
      #
    } else {
      push @s, "\x{FFFD}";
      $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
              index => $_[0]->{index} - 1, value => pack 'C', $_[0]->{lead_byte});
      delete $_[0]->{lead_byte};
    }
  } # lead_byte
  while ($_[1] =~ m{
    \G(?:
      ([\x81-\x9F\xE0-\xFC](?:[\x40-\xFF]|(\z)?)) |
      ([\xA0-\xDF\xFD\xFE\xFF]) |
      ([\x00-\x7F\x80]+)
    )
  }gx) {
    if (defined $1) {
      if (2 == length $1) {
        _sjis ord substr ($1, 0, 1), ord substr ($1, 1, 1), \@s, $_[0]->{index} + $-[0], $_[3];
      } else {
        if (defined $2 and not $_[2]) {
          $_[0]->{lead_byte} = ord $1;
        } else {
          push @s, "\x{FFFD}";
          $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
                  index => $_[0]->{index} + $-[0], value => $1);
        }
      }
    } elsif (defined $3) {
      my $c = ord $3;
      if (0xA1 <= $c and $c <= 0xDF) {
        push @s, chr (0xFF61 - 0xA1 + $c);
      } else {
        push @s, "\x{FFFD}";
        $_[3]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
                index => $_[0]->{index} + $-[0], value => $3);
      }
    } else {
      push @s, $4;
    }
  }
  $_[0]->{index} += length $_[1];
  return \@s;
} # _decode_sjis

sub _decode_eucjp ($$$$) {
  # $states $s $final $onerror
  $_[0]->{index} = 0 unless defined $_[0]->{index};
  my @s;
  pos ($_[1]) = 0;
  if ($_[0]->{is_0212}) {
    if (defined $_[0]->{lead_byte}) {
      if ($_[1] =~ /\G([\x80-\xFF])/gc) {
        _eucjp0212 $_[0]->{lead_byte}, ord $1, \@s, $_[0]->{index} - 2, $_[3];
        delete $_[0]->{lead_byte};
        delete $_[0]->{is_0212};
      } elsif ($_[1] eq '' and not $_[2]) {
        #
      } else {
        push @s, "\x{FFFD}";
        $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
                index => $_[0]->{index} - 2,
                value => pack 'CC', 0x8F, $_[0]->{lead_byte});
        delete $_[0]->{lead_byte};
        delete $_[0]->{is_0212};
      }
    } else {
      if ($_[1] =~ /\G([\x80-\xFF])([\x80-\xFF])?/gc) {
        if (defined $2) {
          _eucjp0212 ord $1, ord $2, \@s, $_[0]->{index} - 1, $_[3];
          delete $_[0]->{is_0212};
        } else {
          if (1 == length $_[1] and not $_[2]) {
            $_[0]->{lead_byte} = ord $1;
          } else {
            push @s, "\x{FFFD}";
            $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
                    index => $_[0]->{index} - 1,
                    value => "\x8F" . $1);
            delete $_[0]->{is_0212};
          }
        }
      } elsif ($_[1] eq '' and not $_[2]) {
        #
      } else {
        push @s, "\x{FFFD}";
        $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
                index => $_[0]->{index} - 1, value => "\x8F");
        delete $_[0]->{is_0212};
      }
    }
  } elsif (defined $_[0]->{lead_byte}) {
    if ($_[1] =~ /\G([\x80-\xFF])/gc) {
      _jis $_[0]->{lead_byte}, ord $1, \@s, $_[0]->{index} - 1, $_[3], 0;
      delete $_[0]->{lead_byte};
    } elsif ($_[1] eq '' and not $_[2]) {
      #
    } else {
      push @s, "\x{FFFD}";
      $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
              index => $_[0]->{index} - 1, value => pack 'C', $_[0]->{lead_byte});
      delete $_[0]->{lead_byte};
    }
  } # lead_byte
  while ($_[1] =~ m{
    \G(?:
      ([\x8E\xA1-\xFE](?:[\x80-\xFF]|(\z)?)) |
      \x8F ( (?:[\x80-\xFF] (?:[\x80-\xFF] |) |) (\z)? ) |
      ([\x80-\x8D\x90-\xA0\xFF]) |
      ([\x00-\x7F]+)
    )
  }gx) {
    if (defined $1) {
      if (2 == length $1) {
        _jis ord substr ($1, 0, 1), ord substr ($1, 1, 1), \@s, $_[0]->{index} + $-[0], $_[3], 0;
      } else {
        if (defined $2 and not $_[2]) {
          $_[0]->{lead_byte} = ord $1;
        } else {
          push @s, "\x{FFFD}";
          $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
                  index => $_[0]->{index} + $-[0], value => $1);
        }
      }
    } elsif (defined $3) {
      if (2 == length $3) {
        _eucjp0212 ord substr ($3, 0, 1), ord substr ($3, 1, 1), \@s, $_[0]->{index} + $-[0], $_[3];
      } else {
        if (defined $4 and not $_[2]) {
          $_[0]->{lead_byte} = length $3 ? ord $3 : undef;
          $_[0]->{is_0212} = 1;
        } else {
          push @s, "\x{FFFD}";
          $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
                  index => $_[0]->{index} + $-[0], value => "\x8F" . $3);
        }
      }
    } elsif (defined $5) {
      my $c = ord $5;
      push @s, "\x{FFFD}";
      $_[3]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
              index => $_[0]->{index} + $-[0], value => $5);
    } else {
      push @s, $6;
    }
  }
  $_[0]->{index} += length $_[1];
  return \@s;
} # _decode_eucjp

sub _decode_gb18030 ($$$$) {
  # $states $s $final $onerror
  $_[0]->{index} = 0 unless defined $_[0]->{index};
  my @s;
  pos ($_[1]) = 0;
  if (defined $_[0]->{lead_byte}) {
    if ($_[1] =~ /\G([\x30-\x39\x40-\xFF])/gc) {
      my $b2 = ord $1;
      if (0x30 <= $b2 and $b2 <= 0x39) {
        if (defined $_[0]->{lead_surrogate}) {
          $_[0]->{lead_surrogate} = _gb4 $_[0]->{lead_surrogate}, $_[0]->{lead_byte}, $b2, \@s, $_[0]->{index} - 2, $_[3];
        } else {
          $_[0]->{lead_surrogate} = [$_[0]->{lead_byte}, $b2];
        }
      } else {
        if (defined $_[0]->{lead_surrogate}) {
          push @s, "\x{FFFD}", chr $_[0]->{lead_surrogate}->[1];
          $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
                  index => $_[0]->{index} - 3,
                  value => pack 'CC', @{delete $_[0]->{lead_surrogate}});
        }
        _gb $_[0]->{lead_byte}, $b2, \@s, $_[0]->{index} - 1, $_[3];
      }
      delete $_[0]->{lead_byte};
    } elsif ($_[1] eq '' and not $_[2]) {
      #
    } else {
      push @s, "\x{FFFD}";
      if (defined $_[0]->{lead_surrogate}) {
        push @s, chr $_[0]->{lead_surrogate}->[1] unless $_[2];
        $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
                index => $_[0]->{index} - 3,
                value => pack 'CCC', @{delete $_[0]->{lead_surrogate}}, $_[0]->{lead_byte});
      } else {
        $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
                index => $_[0]->{index} - 1, value => pack 'C', $_[0]->{lead_byte});
      }
      delete $_[0]->{lead_byte};
    }
  } elsif (defined $_[0]->{lead_surrogate}) {
    if ($_[1] eq '') {
      if ($_[2]) { # final
        push @s, "\x{FFFD}";
        $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
                index => $_[0]->{index} - 2,
                value => pack 'CC', @{$_[0]->{lead_surrogate}});
        delete $_[0]->{lead_surrogate};
      }
    }
  } # lead_surrogate

  while ($_[1] =~ m{
    \G(?:
      ([\x81-\xFE](?:[\x30-\x39\x40-\xFF]|(\z)?)) |
      ([\x80\xFF]) |
      ([\x00-\x7F]+)
    )
  }gx) {
    if (defined $1) {
      if (2 == length $1) {
        my $b1 = ord substr ($1, 0, 1);
        my $b2 = ord substr ($1, 1, 1);
        if (0x30 <= $b2 and $b2 <= 0x39) {
          if (defined $_[0]->{lead_surrogate}) {
            $_[0]->{lead_surrogate} = _gb4 $_[0]->{lead_surrogate}, $b1, $b2, \@s, $_[0]->{index} + $-[0] - 2, $_[3];
          } else {
            $_[0]->{lead_surrogate} = [$b1, $b2];
          }
        } else {
          if (defined $_[0]->{lead_surrogate}) {
            push @s, "\x{FFFD}", chr $_[0]->{lead_surrogate}->[1];
            $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
                    index => $_[0]->{index} + $-[0] - 2,
                    value => (pack 'CC', @{delete $_[0]->{lead_surrogate}}));
          }
          _gb $b1, $b2, \@s, $_[0]->{index} + $-[0], $_[3];
        }
      } else {
        if (defined $2 and not $_[2]) {
          $_[0]->{lead_byte} = ord $1;
        } else {
          push @s, "\x{FFFD}";
          if (defined $_[0]->{lead_surrogate}) {
            push @s, chr $_[0]->{lead_surrogate}->[1];
            $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
                    index => $_[0]->{index} + $-[0] - 2,
                    value => (pack 'CC', @{delete $_[0]->{lead_surrogate}}).$1);
          } else {
            $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
                    index => $_[0]->{index} + $-[0], value => $1);
          }
        }
      }
    } elsif (defined $3) {
      if (defined $_[0]->{lead_surrogate}) {
        push @s, "\x{FFFD}", chr $_[0]->{lead_surrogate}->[1];
        $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
                index => $_[0]->{index} + $-[0] - 2,
                value => pack 'CC', @{delete $_[0]->{lead_surrogate}});
      }
      if ($3 eq "\x80") {
        $_[3]->(type => 'encoding:not canonical', level => 'w',
                index => $_[0]->{index} + $-[0], value => $3);
        push @s, "\x{20AC}";
      } else {
        my $c = ord $3;
        push @s, "\x{FFFD}";
        $_[3]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
                index => $_[0]->{index} + $-[0], value => $3);
      }
    } else {
      if (defined $_[0]->{lead_surrogate}) {
        push @s, "\x{FFFD}", chr $_[0]->{lead_surrogate}->[1];
        $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
                index => $_[0]->{index} + $-[0] - 2,
                value => pack 'CC', @{delete $_[0]->{lead_surrogate}});
      }
      push @s, $4;
    }
  }
  $_[0]->{index} += length $_[1];
  return \@s;
} # _decode_gb18030

sub _esc ($$$$$) {
  # $states $s $final $onerror $out
  my $length = length $_[0]->{lead_escape};
  if ($length == 0) {
    if ($_[1] =~ m{\G(\x24[\x40\x42]?|\x28[BIJ]?)}gc) {
      $_[0]->{lead_escape} .= $1;
    }
  } elsif ($length == 1) {
    if ($_[0]->{lead_escape} eq "\x24" and $_[1] =~ m{\G([\x40\x42])}gc) {
      $_[0]->{lead_escape} .= $1;
    } elsif ($_[0]->{lead_escape} eq "\x28" and $_[1] =~ m{\G([BIJ])}gc) {
      $_[0]->{lead_escape} .= $1;
    }
  }

  my $new_state;
  if ($_[0]->{lead_escape} eq "\x24\x42") {
    $new_state = '0208';
  } elsif ($_[0]->{lead_escape} eq "\x24\x40") {
    $new_state = '6226';
    $_[3]->(type => 'iso2022jp:jis78', level => 'm',
            index => $_[0]->{index} + pos ($_[1]) - 2 - 1,
            value => "\x1B\x24\x40");
  } elsif ($_[0]->{lead_escape} eq "\x28\x42") {
    $new_state = 'ASCII';
  } elsif ($_[0]->{lead_escape} eq "\x28\x4A") {
    $new_state = 'Latin';
  } elsif ($_[0]->{lead_escape} eq "\x28\x49") {
    $new_state = 'Katakana';
  } else {
    if (not $_[2] and $_[1] =~ m{\G\z}gc) {
      return;
    } else {
      push @{$_[4]}, "\x{FFFD}", $_[0]->{lead_escape};
      $_[3]->(type => 'iso2022jp:lone escape', level => 'm', fatal => 1,
              index => $_[0]->{index} + pos ($_[1]) - length ($_[0]->{lead_escape}) - 1,
              value => "\x1B");
      delete $_[0]->{after_escape};
      delete $_[0]->{lead_escape};
      return;
    }
  }

  if ($_[0]->{after_escape}) {
    push @{$_[4]}, "\x{FFFD}";
    $_[3]->(type => 'iso2022jp:redundant escape',
            level => 'm', fatal => 1,
            index => $_[0]->{index} + pos ($_[1]) - length ($_[0]->{lead_escape}) - 1 - 3,
            value => {
              '0208' => "\x1B\x24\x42",
              '6226' => "\x1B\x24\x40",
              'ASCII' => "\x1B\x28\x42",
              'Latin' => "\x1B\x28\x4A",
              'Katakana' => "\x1B\x28\x49",
            }->{$_[0]->{state}});
  }
  $_[0]->{state} = $new_state;
  $_[0]->{after_escape} = 1;
  delete $_[0]->{lead_escape};
} # _esc

sub _decode_iso2022jp ($$$$) {
  # $states $s $final $onerror
  $_[0]->{index} = 0 unless defined $_[0]->{index};
  $_[0]->{state} = 'ASCII' unless defined $_[0]->{state};
  my @s;

  pos ($_[1]) = 0;

  if (defined $_[0]->{lead_escape}) {
    _esc $_[0], $_[1], $_[2], $_[3], \@s;
  }

  if (defined $_[0]->{lead_byte}) {
    if ($_[1] =~ m{\G([\x21-\x7E])}gc) {
      _jis 0x80 + $_[0]->{lead_byte}, 0x80 + ord $1, \@s, $_[0]->{index} - 1, $_[3], 0x80;
      delete $_[0]->{after_escape};
      delete $_[0]->{lead_byte};
    } elsif ($_[1] =~ m{\G([^\x1B])}gc) {
      push @s, "\x{FFFD}";
      $_[3]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
              index => $_[0]->{index} - 1,
              value => (pack 'C', $_[0]->{lead_byte}) . $1);
      delete $_[0]->{after_escape};
      delete $_[0]->{lead_byte};
    } elsif ($_[2]) {
      push @s, "\x{FFFD}";
      $_[3]->(type => 'multibyte:lone lead byte', level => 'm', fatal => 1,
              index => $_[0]->{index} - 1,
              value => pack 'C', $_[0]->{lead_byte});
      delete $_[0]->{lead_byte};
    }
  } # lead_byte

  my $length = length $_[1];
  while (pos ($_[1]) < $length) {
    if ($_[0]->{state} eq 'ASCII') {
      if ($_[1] =~ m{\G([\x00-\x0D\x10-\x1A\x1C-\x7F]+)}gc) {
        push @s, $1;
        delete $_[0]->{after_escape};
      } elsif ($_[1] =~ m{\G([^\x1B])}gc) {
        push @s, "\x{FFFD}";
        $_[3]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
                index => $_[0]->{index} + $-[0], value => $1);
        delete $_[0]->{after_escape};
      }
    } elsif ($_[0]->{state} eq 'Latin') {
      if ($_[1] =~ m{\G([\x00-\x0D\x10-\x1A\x1C-\x7F]+)}gc) {
        push @s, $1;
        $s[-1] =~ tr/\x5C\x7E/\xA5\x{203E}/;
        delete $_[0]->{after_escape};
      } elsif ($_[1] =~ m{\G([^\x1B])}gc) {
        push @s, "\x{FFFD}";
        $_[3]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
                index => $_[0]->{index} + $-[0], value => $1);
        delete $_[0]->{after_escape};
      }
    } elsif ($_[0]->{state} eq '0208' or $_[0]->{state} eq '6226') {
      while ($_[1] =~ m{\G([\x21-\x7E])([\x21-\x7E])}gc) {
        _jis 0x80 + ord $1, 0x80 + ord $2, \@s, $_[0]->{index} + $-[0], $_[3], 0x80;
        delete $_[0]->{after_escape};
      }
      if ($_[1] =~ m{\G([\x21-\x7E][^\x1B])}gc) {
        push @s, "\x{FFFD}";
        $_[3]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
                index => $_[0]->{index} + $-[0], value => $1);
        delete $_[0]->{after_escape};
      } elsif (not $_[2] and $_[1] =~ m{\G([\x21-\x7E])\z}gc) {
        $_[0]->{lead_byte} = ord $1;
        delete $_[0]->{after_escape};
      } elsif ($_[1] =~ m{\G([^\x1B])}gc) {
        push @s, "\x{FFFD}";
        $_[3]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
                index => $_[0]->{index} + $-[0], value => $1);
        delete $_[0]->{after_escape};
      }
    } elsif ($_[0]->{state} eq 'Katakana') {
      while ($_[1] =~ m{\G([\x21-\x5F])}gc) {
        push @s, chr (0xFF61 - 0x21 + ord $1);
        delete $_[0]->{after_escape};
      }
      if ($_[1] =~ m{\G([^\x1B])}gc) {
        push @s, "\x{FFFD}";
        $_[3]->(type => 'encoding:unassigned', level => 'm', fatal => 1,
                index => $_[0]->{index} + $-[0], value => $1);
        delete $_[0]->{after_escape};
      }
    }

    if ($_[1] =~ m{\G\x1B}gc) {
      $_[0]->{lead_escape} = '';
      _esc $_[0], $_[1], $_[2], $_[3], \@s;
    }
  } # while

  $_[0]->{index} += length $_[1];

  if ($_[2]) {
    unless ($_[0]->{state} eq 'ASCII') {
      $_[3]->(type => 'iso2022jp:not ascii at end', level => 'w',
              index => $_[0]->{index});
    }
  }

  return \@s;
} # _decode_iso2022jp

sub bytes ($$) {
  my $key = $_[0]->{key};
  if (not defined $_[1]) {
    carp "Use of uninitialized value an argument";
    return [];
  } elsif (utf8::is_utf8 $_[1]) {
    croak "Cannot decode string with wide characters";
  } elsif ($_[1] eq '') {
    return [];
  }

  $_[0]->{states}->{index} = 0 unless defined $_[0]->{states}->{index};
  if ($key eq 'utf-8') {
    my $offset = $_[0]->{states}->{index}
               + (defined $_[0]->{states}->{lead} ? -length $_[0]->{states}->{lead} : 0);
    my $decoded = [Web::Encoding::_decode8 ($_[0]->{states}, $_[1], 0, $offset, $_[0]->_onerror)];

    $_[0]->{states}->{index} += length $_[1];
    if ($_[0]->{ignore_bom} and not $_[0]->{states}->{bom_seen}) {
      if (@$decoded and length $decoded->[0]) {
        if ($decoded->[0] =~ s/^\x{FEFF}//) {
          $_[0]->_onerror->(type => 'bom', level => 's', index => 0);
        }
        $_[0]->{states}->{bom_seen} = 1;
      }
    }
    return $decoded;
  } elsif (Web::Encoding::_is_single ($key)) {
    require Web::Encoding::_Single;
    my $s = $_[1]; # string copy!
    my $Map = \($Web::Encoding::_Single::Decoder->{$_[0]->{key}});
    $s =~ s{([\x80-\xFF])}{substr $$Map, -0x80 + ord $1, 1}ge;
    while ($s =~ m{\x{FFFD}}g) {
      $_[0]->_onerror->(type => 'encoding:unassigned', level => 'm', fatal => 1,
                        index => $_[0]->{states}->{index} + $-[0],
                        value => substr $_[1], $-[0], 1);
    }
    $_[0]->{states}->{index} += length $_[1];
    return [$s];
  } elsif ($key eq 'utf-16be') {
    my $decoded = _decode_16 $_[0]->{states}, $_[0]->_onerror, $_[1], 0, 'n';
    if ($_[0]->{ignore_bom} and not $_[0]->{states}->{bom_seen}) {
      if (@$decoded) {
        if ($decoded->[0] =~ s/^\x{FEFF}//) {
          $_[0]->_onerror->(type => 'bom', level => 's', index => 0);
        }
        $_[0]->{states}->{bom_seen} = 1;
      }
    }
    return $decoded;
  } elsif ($key eq 'utf-16le') {
    my $decoded = _decode_16 $_[0]->{states}, $_[0]->_onerror, $_[1], 0, 'v';
    if ($_[0]->{ignore_bom} and not $_[0]->{states}->{bom_seen}) {
      if (@$decoded) {
        if ($decoded->[0] =~ s/^\x{FEFF}//) {
          $_[0]->_onerror->(type => 'bom', level => 's', index => 0);
        }
        $_[0]->{states}->{bom_seen} = 1;
      }
    }
    return $decoded;
  } elsif ($key eq 'gb18030' or $key eq 'gbk') {
    require Web::Encoding::_GB;
    return _decode_gb18030 $_[0]->{states}, $_[1], 0, $_[0]->_onerror;
  } elsif ($key eq 'big5') {
    require Web::Encoding::_Big5;
    return _decode_mb $_[0]->{states}, $_[1], 0, $_[0]->_onerror, \&_b5;
  } elsif ($key eq 'shift_jis') {
    require Web::Encoding::_JIS;
    return _decode_sjis $_[0]->{states}, $_[1], 0, $_[0]->_onerror;
  } elsif ($key eq 'euc-jp') {
    require Web::Encoding::_JIS;
    return _decode_eucjp $_[0]->{states}, $_[1], 0, $_[0]->_onerror;
  } elsif ($key eq 'euc-kr') {
    require Web::Encoding::_EUCKR;
    return _decode_mb $_[0]->{states}, $_[1], 0, $_[0]->_onerror, \&_kr;
  } elsif ($key eq 'iso-2022-jp') {
    require Web::Encoding::_JIS;
    return _decode_iso2022jp $_[0]->{states}, $_[1], 0, $_[0]->_onerror;
  } elsif ($key eq 'replacement') {
    if (not $_[0]->{states}->{written}) {
      $_[0]->{states}->{written} = 1;
      $_[0]->_onerror->(type => 'encoding:replacement', level => 'm', fatal => 1,
                        index => 0);
      return ["\x{FFFD}"];
    } else {
      return [];
    }
  } else {
    croak "Bad encoding key |$key|";
  }
} # bytes

sub eof ($) {
  my $key = $_[0]->{key};
  if ($key eq 'utf-8') {
    $_[0]->{states}->{index} = 0 unless defined $_[0]->{states}->{index};
    my $offset = $_[0]->{states}->{index} + (defined $_[0]->{states}->{lead} ? -length $_[0]->{states}->{lead} : 0);
    ## Returns zero or more U+FFFD.
    return [Web::Encoding::_decode8 ($_[0]->{states}, '', 1, $offset, $_[0]->_onerror)];
  } elsif ($key eq 'utf-16be') {
    my $decoded = _decode_16 $_[0]->{states}, $_[0]->_onerror, '', 1, 'n';
    if ($_[0]->{ignore_bom} and not $_[0]->{states}->{bom_seen}) {
      if (@$decoded) {
        if ($decoded->[0] =~ s/^\x{FEFF}//) {
          $_[0]->_onerror->(type => 'bom', level => 's', index => 0);
        }
        $_[0]->{states}->{bom_seen} = 1;
      }
    }
    return $decoded;
  } elsif ($key eq 'utf-16le') {
    my $decoded = _decode_16 $_[0]->{states}, $_[0]->_onerror, '', 1, 'v';
    if ($_[0]->{ignore_bom} and not $_[0]->{states}->{bom_seen}) {
      if (@$decoded) {
        if ($decoded->[0] =~ s/^\x{FEFF}//) {
          $_[0]->_onerror->(type => 'bom', level => 's', index => 0);
        }
        $_[0]->{states}->{bom_seen} = 1;
      }
    }
    return $decoded;
  } elsif ($key eq 'gb18030' or $key eq 'gbk') {
    require Web::Encoding::_GB;
    return _decode_gb18030 $_[0]->{states}, '', 1, $_[0]->_onerror;
  } elsif ($key eq 'big5') {
    require Web::Encoding::_Big5;
    return _decode_mb $_[0]->{states}, '', 1, $_[0]->_onerror, \&_b5;
  } elsif ($key eq 'shift_jis') {
    require Web::Encoding::_JIS;
    return _decode_sjis $_[0]->{states}, '', 1, $_[0]->_onerror;
  } elsif ($key eq 'euc-jp') {
    require Web::Encoding::_JIS;
    return _decode_eucjp $_[0]->{states}, '', 1, $_[0]->_onerror;
  } elsif ($key eq 'euc-kr') {
    require Web::Encoding::_EUCKR;
    return _decode_mb $_[0]->{states}, '', 1, $_[0]->_onerror, \&_kr;
  } elsif ($key eq 'iso-2022-jp') {
    require Web::Encoding::_JIS;
    return _decode_iso2022jp $_[0]->{states}, '', 1, $_[0]->_onerror;
  } elsif ($key eq 'replacement' or Web::Encoding::_is_single ($key)) {
    return [];
  } else {
    croak "Bad encoding key |$key|";
  }
} # eof

1;

=head1 LICENSE

Copyright 2011-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
