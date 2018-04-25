package Web::Encoding;
use strict;
use warnings;
no warnings 'utf8';
our $VERSION = '7.0';
use Carp;
use Web::Encoding::_Defs;

our @EXPORT = qw(
  encode_web_utf8
  decode_web_utf8
  decode_web_utf8_no_bom
  encode_web_charset
  decode_web_charset
  is_ascii_compat_charset_name
  encoding_names
);

sub import ($;@) {
  my $from_class = shift;
  my ($to_class, $file, $line) = caller;
  no strict 'refs';
  for (@_ ? @_ : @{$from_class . '::EXPORT'}) {
    my $code = $from_class->can ($_)
        or croak qq{"$_" is not exported by the $from_class module at $file line $line};
    *{$to_class . '::' . $_} = $code;
  }
} # import

sub encode_web_utf8 ($) {
  if (not defined $_[0]) {
    carp "Use of uninitialized value in subroutine entry";
    return '';
  } else {
    my $x = $_[0];
    if (utf8::is_utf8 $x) {
      $x =~ s/[^\x00-\x{D7FF}\x{E000}-\x{10FFFF}]/\x{FFFD}/g;
    } else {
      utf8::upgrade $x;
    }
    utf8::encode $x;
    return $x;
  }
} # encode_web_utf8

sub _decode8 ($$$;$$) {
  # $states, $x, $final, $index_offset, $onerror
  my $x = defined $_[0]->{lead} ? (delete $_[0]->{lead}) . $_[1] : $_[1]; # string copy!
  $x =~ s{
      ([\xC2-\xDF]        [\x80-\xBF]|
       \xE0               [\xA0-\xBF][\x80-\xBF]|
       [\xE1-\xEC\xEE\xEF][\x80-\xBF][\x80-\xBF]|
       \xED               [\x80-\x9F][\x80-\xBF]|
       \xF0               [\x90-\xBF][\x80-\xBF][\x80-\xBF]|
       [\xF1-\xF3]        [\x80-\xBF][\x80-\xBF][\x80-\xBF]|
       \xF4               [\x80-\x8F][\x80-\xBF][\x80-\xBF])|

   ((?:[\xC2-\xDF]                                      |
       \xE0               [\xA0-\xBF]?                  |
       [\xE1-\xEC\xEE\xEF][\x80-\xBF]?                  |
       \xED               [\x80-\x9F]?                  |
       \xF0               (?:[\x90-\xBF][\x80-\xBF]?|)  |
       [\xF1-\xF3]        (?:[\x80-\xBF][\x80-\xBF]?|)  |
       \xF4               (?:[\x80-\x8F][\x80-\xBF]?|))(\z)?)|

      ([^\x00-\x7F])
  }{
    if (defined $1) {
      $1;
    } elsif (defined $2) {
      if ($_[2] or not defined $3) {
        my $length = length $2;
        if ($_[4]) {
          $_[4]->(type => 'utf-8:bad bytes', level => 'm', fatal => 1,
                  index => $_[3] + $-[2], value => $2);
        }
        qq{\xEF\xBF\xBD}; # U+FFFD
      } else {
        $_[0]->{lead} .= $2;
        '';
      }
    } else { # $4
      $_[4]->(type => 'utf-8:bad bytes', level => 'm', fatal => 1,
              index => $_[3] + $-[4], value => $4) if $_[4];
      qq{\xEF\xBF\xBD}; # U+FFFD
    }
  }gex;
  utf8::decode ($x);
  return $x;
} # _decode8

sub decode_web_utf8 ($) {
  if (not defined $_[0]) {
    carp "Use of uninitialized value in subroutine entry";
    return '';
  } elsif (utf8::is_utf8 $_[0]) {
    croak "Cannot decode string with wide characters";
  } else {
    return _decode8
        ({},
         substr ($_[0], 0, 3) eq "\xEF\xBB\xBF" ? substr $_[0], 3 : $_[0],
         1);
  }
} # decode_web_utf8

sub decode_web_utf8_no_bom ($) {
  if (not defined $_[0]) {
    carp "Use of uninitialized value an argument";
    return '';
  } elsif (utf8::is_utf8 $_[0]) {
    croak "Cannot decode string with wide characters";
  } else {
    return _decode8 {}, $_[0], 1;
  }
} # decode_web_utf8_no_bom

sub _encode_16 ($$) {
  if (not defined $_[0]) {
    carp "Use of uninitialized value an argument";
    return '';
  }
  my @s;
  for (split //, $_[0]) {
    my $c = ord $_;
    if ($c <= 0xFFFF) {
      push @s, pack $_[1], $c;
    } elsif ($c <= 0x10FFFF) {
      $c -= 0x10000;
      push @s, pack $_[1].$_[1], ($c >> 10) + 0xD800, ($c & 0x3FF) + 0xDC00;
    } else {
      push @s, $_[1] eq 'n' ? "\xFF\xFD" : "\xFD\xFF";
    }
  }
  return join '', @s;
} # _encode_16

sub _encode_mb ($$$$$) {
  my @s;
  pos ($_[0]) = 0;
  while ($_[0] =~ m{\G(?:([\x00-\x7F]+)|(.))}gs) {
    if (defined $1) {
      push @s, $1;
      utf8::downgrade $s[-1];
    } else {
      my $c = ord $2;
      if ($c > 0xFFFF) {
        my $v = $_[2]->{$c};
        if (defined $v) {
          push @s, $v;
          next;
        } else {
          #
        }
      } else {
        my $v = substr $_[1], $c * 2, 2;
        if ($v eq "\x00\x00") {
          #
        } elsif (substr ($v, 0, 1) eq "\x00") {
          push @s, substr $v, 1, 1;
          next;
        } else {
          push @s, $v;
          next;
        }
      }

      if ($c == 0x20AC) {
        push @s, $_[4] == 2 ? "\xA2\xE3" : "\x80";
        next;
      }

      if (@{$_[3]}) {
        ## <https://encoding.spec.whatwg.org/#index-gb18030-ranges-pointer>

        my $pointer;
        if ($c == 0xE5E5) {
          #
        } elsif ($c == 0xE7C7) {
          $pointer = 7457;
        } else {
          for (@{$_[3]}) {
            if ($_->[1] <= $c) {
              $pointer = $_->[0] + $c - $_->[1];
            }
          }
        }

        if (defined $pointer) {
          my $byte1 = int ($pointer / (10 * 126 * 10));
          $pointer = $pointer % (10 * 126 * 10);
          my $byte2 = int ($pointer / (10 * 126));
          $pointer = $pointer % (10 * 126);
          my $byte3 = int ($pointer / 10);
          my $byte4 = $pointer % 10;
          push @s, pack 'CCCC',
              $byte1 + 0x81, $byte2 + 0x30, $byte3 + 0x81, $byte4 + 0x30;
          next;
        }
      }

      push @s, sprintf '&#%d;', $c;
    }
  } # while
  return join '', @s;
} # _encode_mb

sub _encode_iso2022jp ($$$) {
  # $states $s $final

  my @s;

  for (split //, $_[1]) {
    my $c = ord $_;
    
    if ($c == 0x000E or $c == 0x000F or $c == 0x1B) {
      if (defined $_[0]->{state} and not $_[0]->{state} eq 'J') {
        delete $_[0]->{state};
        push @s, "\x1B\x28\x42";
      }
      push @s, '&#65533;'; # U+FFFD
    } elsif ($c == 0x5C or $c == 0x7E) {
      if (defined $_[0]->{state}) {
        delete $_[0]->{state};
        push @s, "\x1B\x28\x42";
      }
      push @s, pack 'C', $c;
    } elsif ($c <= 0x7F) {
      if (defined $_[0]->{state} and not $_[0]->{state} eq 'J') {
        delete $_[0]->{state};
        push @s, "\x1B\x28\x42";
      }
      push @s, pack 'C', $c;
    } elsif ($c == 0xA5) {
      if (not defined $_[0]->{state} or not $_[0]->{state} eq 'J') {
        $_[0]->{state} = 'J';
        push @s, "\x1B\x28\x4A";
      }
      push @s, "\x5C";
    } elsif ($c == 0x203E) {
      if (not defined $_[0]->{state} or not $_[0]->{state} eq 'J') {
        $_[0]->{state} = 'J';
        push @s, "\x1B\x28\x4A";
      }
      push @s, "\x7E";
    } elsif ($c > 0xFFFF) {
      if (defined $_[0]->{state} and not $_[0]->{state} eq 'J') {
        delete $_[0]->{state};
        push @s, "\x1B\x28\x42";
      }
      push @s, sprintf '&#%d;', $c;
    } else {
      if (0xFF61 <= $c and $c <= 0xFF9F) {
        $c = $Web::Encoding::_JIS::KatakanaHF->[$c - 0xFF61];
      }

      my $v = substr $Web::Encoding::_JIS::EncodeBMPEUC, $c * 2, 2;
      if ($v =~ /^[\xA1-\xFE]/) {
        if (not defined $_[0]->{state} or not $_[0]->{state} eq 'B') {
          $_[0]->{state} = 'B';
          push @s, "\x1B\x24\x42";
        }
        $v =~ tr/\x80-\xFF/\x00-\x7F/;
        push @s, $v;
      } else {
        if (defined $_[0]->{state} and not $_[0]->{state} eq 'J') {
          delete $_[0]->{state};
          push @s, "\x1B\x28\x42";
        }
        push @s, sprintf '&#%d;', $c;
      }
    }
  }

  if ($_[2]) {
    if (defined $_[0]->{state}) {
      delete $_[0]->{state};
      push @s, "\x1B\x28\x42";
    }
  }

  return join '', @s;
} # _encode_iso2022jp

sub _is_single ($) {
  return (($Web::Encoding::_Defs->{encodings}->{$_[0]} || {})->{single_byte});
} # _is_single

sub encode_web_charset ($$) {
  if ($_[0] eq 'utf-8') {
    return encode_web_utf8 $_[1];
  } elsif (_is_single $_[0]) {
    if (not defined $_[1]) {
      carp "Use of uninitialized value an argument";
      return '';
    }
    require Web::Encoding::_Single;
    my $s = $_[1]; # string copy!
    my $Map = $Web::Encoding::_Single::Encoder->{$_[0]};
    $s =~ s{([^\x00-\x7F])}{
      defined $Map->{$1} ? $Map->{$1} : sprintf '&#%d;', ord $1;
    }ge;
    utf8::downgrade $s if utf8::is_utf8 $s;
    return $s;
  } elsif ($_[0] eq 'utf-16be') {
    return _encode_16 $_[1], 'n';
  } elsif ($_[0] eq 'utf-16le') {
    return _encode_16 $_[1], 'v';
  } elsif ($_[0] eq 'gb18030') {
    require Web::Encoding::_GB;
    return _encode_mb $_[1], $Web::Encoding::_GB::EncodeBMP, {},
        $Web::Encoding::_GB::Ranges, 2;
  } elsif ($_[0] eq 'gbk') {
    require Web::Encoding::_GB;
    return _encode_mb $_[1], $Web::Encoding::_GB::EncodeBMP, {}, [], 1;
  } elsif ($_[0] eq 'big5') {
    require Web::Encoding::_Big5;
    return _encode_mb $_[1],
        $Web::Encoding::_Big5::EncodeBMP,
        $Web::Encoding::_Big5::EncodeNonBMP, [], 0;
  } elsif ($_[0] eq 'shift_jis') {
    require Web::Encoding::_JIS;
    return _encode_mb $_[1], $Web::Encoding::_JIS::EncodeBMPSJIS, {}, [], 0;
  } elsif ($_[0] eq 'euc-jp') {
    require Web::Encoding::_JIS;
    return _encode_mb $_[1], $Web::Encoding::_JIS::EncodeBMPEUC, {}, [], 0;
  } elsif ($_[0] eq 'euc-kr') {
    require Web::Encoding::_EUCKR;
    return _encode_mb $_[1], $Web::Encoding::_EUCKR::EncodeBMP, {}, [], 0;
  } elsif ($_[0] eq 'iso-2022-jp') {
    require Web::Encoding::_JIS;
    return _encode_iso2022jp {}, $_[1], 1;
  } elsif ($_[0] eq 'replacement') {
    croak "The replacement encoding has no encoder";
  } else {
    croak "Bad encoding key |$_[0]|";
  }
} # encode_web_charset

sub decode_web_charset ($$) {
  if ($_[0] eq 'utf-8') { # shortcut
    return decode_web_utf8 $_[1];
  } else {
    require Web::Encoding::Decoder;
    my $decoder = Web::Encoding::Decoder->new_from_encoding_key ($_[0]);
    $decoder->ignore_bom (1);
    return join '', @{$decoder->bytes ($_[1])}, @{$decoder->eof};
  }
} # decode_web_charset

push @EXPORT, qw(encoding_label_to_name);
sub encoding_label_to_name ($) {
  ## Get an encoding
  ## <https://encoding.spec.whatwg.org/#concept-encoding-get>.
  my $label = $_[0] || '';
  $label =~ s/\A[\x09\x0A\x0C\x0D\x20]+//; ## ASCII whitespace
  $label =~ s/[\x09\x0A\x0C\x0D\x20]+\z//; ## ASCII whitespace
  $label =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  ## Returns the encoding key.
  return $Web::Encoding::_Defs->{supported_labels}->{$label}; # or undef
} # encoding_label_to_name

push @EXPORT, qw(is_encoding_label);
sub is_encoding_label ($) {
  my $label = $_[0] || '';
  $label =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
  return !!$Web::Encoding::_Defs->{supported_labels}->{$label};
} # is_encoding_label

push @EXPORT, qw(encoding_name_to_compat_name);
sub encoding_name_to_compat_name ($) {
  return (($Web::Encoding::_Defs->{encodings}->{$_[0] || ''} || {})->{compat_name});
} # encoding_name_to_compat_name

push @EXPORT, qw(is_utf16_encoding_key);
sub is_utf16_encoding_key ($) {
  return (($Web::Encoding::_Defs->{encodings}->{$_[0] || ''} || {})->{utf16});
} # is_utf16_encoding_key

push @EXPORT, qw(is_ascii_compat_encoding_name);
sub is_ascii_compat_encoding_name ($) {
  return (($Web::Encoding::_Defs->{encodings}->{$_[0] || ''} || {})->{ascii_compat});
} # is_ascii_compat_encoding_name

push @EXPORT, qw(get_output_encoding_key);
sub get_output_encoding_key ($) {
  return (($Web::Encoding::_Defs->{encodings}->{$_[0] || ''} || {})->{output}); # or undef
} # get_output_encoding_key

push @EXPORT, qw(fixup_html_meta_encoding_name);
sub fixup_html_meta_encoding_name ($) {
  return (($Web::Encoding::_Defs->{encodings}->{$_[0] || ''} || {})->{html_decl_mapped}); # or undef
} # fixup_html_meta_encoding_name

# XXX can this deleted?
sub is_ascii_compat_charset_name ($) {
  my $name = $_[0] or return 0;
  if ($name =~ m{^
    utf-8|
    iso-8859-[0-9]+|
    us-ascii|
    shift_jis|
    euc-jp|
    windows-[0-9]+|
    iso-2022-[0-9a-zA-Z-]+|
    hz-gb-2312
  $}xi) {
    return 1;
  } else {
    return 0;
  }
} # is_ascii_compat_charset_name

push @EXPORT, qw(locale_default_encoding_name);
sub locale_default_encoding_name ($) {
  my $locale = $_[0] or return undef;
  $locale =~ tr/A-Z/a-z/;
  return $Web::Encoding::_Defs->{locale_default}->{$locale}; # or undef
} # locale_default_encoding_name

sub encoding_names () {
  return $Web::Encoding::_Defs->{names};
} # encoding_names

1;

=head1 LICENSE

Copyright 2011-2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
