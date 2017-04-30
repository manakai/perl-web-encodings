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

sub decode_web_utf8 ($) {
  if (not defined $_[0]) {
    carp "Use of uninitialized value in subroutine entry";
    return '';
  } elsif (utf8::is_utf8 $_[0]) {
    croak "Cannot decode string with wide characters";
  } else {
    my $x = substr ($_[0], 0, 3) eq "\xEF\xBB\xBF" ? substr $_[0], 3 : $_[0];
    $x =~ s{
      ([\xC2-\xDF]        [\x80-\xBF]|
       \xE0               [\xA0-\xBF][\x80-\xBF]|
       [\xE1-\xEC\xEE\xEF][\x80-\xBF][\x80-\xBF]|
       \xED               [\x80-\x9F][\x80-\xBF]|
       \xF0               [\x90-\xBF][\x80-\xBF][\x80-\xBF]|
       [\xF1-\xF3]        [\x80-\xBF][\x80-\xBF][\x80-\xBF]|
       \xF4               [\x80-\x8F][\x80-\xBF][\x80-\xBF])|
      [^\x00-\x7F]
    }{
      if (defined $1) {
        $1;
      } else {
        qq{\xEF\xBF\xBD};
      }
    }gex;
    utf8::decode ($x);
    return $x;
  }
} # decode_web_utf8

sub decode_web_utf8_no_bom ($) {
  if (not defined $_[0]) {
    carp "Use of uninitialized value an argument";
    return '';
  } elsif (utf8::is_utf8 $_[0]) {
    croak "Cannot decode string with wide characters";
  } else {
    my $x = $_[0];
    $x =~ s{
      ([\xC2-\xDF]        [\x80-\xBF]|
       \xE0               [\xA0-\xBF][\x80-\xBF]|
       [\xE1-\xEC\xEE\xEF][\x80-\xBF][\x80-\xBF]|
       \xED               [\x80-\x9F][\x80-\xBF]|
       \xF0               [\x90-\xBF][\x80-\xBF][\x80-\xBF]|
       [\xF1-\xF3]        [\x80-\xBF][\x80-\xBF][\x80-\xBF]|
       \xF4               [\x80-\x8F][\x80-\xBF][\x80-\xBF])|
      [^\x00-\x7F]
    }{
      if (defined $1) {
        $1;
      } else {
        qq{\xEF\xBF\xBD};
      }
    }gex;
    utf8::decode ($x);
    return $x;
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

sub _u16 ($$$) {
  #$states, $u, \@s;
  if ($_[1] < 0xD800 or 0xDFFF < $_[1]) {
    if (defined $_[0]->{lead_surrogate}) {
      push @{$_[2]}, "\x{FFFD}"; # or error
    }
    push @{$_[2]}, chr $_[1];
  } elsif ($_[1] <= 0xDBFF) { # [U+D800, U+DBFF]
    if (defined $_[0]->{lead_surrogate}) {
      push @{$_[2]}, "\x{FFFD}"; # or error
    }
    $_[0]->{lead_surrogate} = $_[1];
  } else { # [U+DC00, U+DFFF]
    if (defined $_[0]->{lead_surrogate}) {
      push @{$_[2]}, chr (0x10000
                          + ((delete ($_[0]->{lead_surrogate}) - 0xD800) << 10)
                          + $_[1] - 0xDC00);
    } else {
      push @{$_[2]}, "\x{FFFD}"; # or error
    }
  }
} # _u16

sub _decode_16 ($$$$$) {
  my $states = $_[0];
  my $offset = $_[1];
  #my $is_last = $_[3];
  #my $endian = $_[4]

  if (not defined $_[2]) {
    carp "Use of uninitialized value an argument";
    return '';
  } elsif (utf8::is_utf8 $_[2]) {
    croak "Cannot decode string with wide characters";
  }

  my @s;
  my $len = length $_[2];
  if (defined $states->{lead_byte}) {
    if ($len) {
      my $lead = unpack 'C', delete $states->{lead_byte};
      my $sec = unpack 'C', substr $_[2], 0, 1;
      if ($_[4] eq 'n') {
        _u16 $states, $lead * 0x100 + $sec, \@s;
      } else {
        _u16 $states, $sec * 0x100 + $lead, \@s;
      }
      $offset++;
    } elsif ($_[3]) { # $is_last
      push @s, "\x{FFFD}"; # or error
    }
  }
  my $Length = ($len - $offset) / 2;
  my $length = int $Length;
  my $i = 0;
  while ($i < $length) {
    _u16 $states, (unpack $_[4], substr $_[2], $offset + $i * 2, 2), \@s;
    $i++;
  }
  if (defined $states->{lead_surrogate} and $_[3]) { # $is_last
    push @s, "\x{FFFD}"; # or error
  } elsif ($length != $Length) {
    if ($_[3]) { # $is_last
      push @s, "\x{FFFD}"; # or error
    } else {
      $states->{lead_byte} = substr $_[2], -1;
    }
  }
  return join '', @s;
} # _decode_16

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
  } elsif ($_[0] eq 'replacement') {
    croak "The replacement encoding has no encoder";
  } else {
    require Encode;
    return Encode::encode ($_[0], defined $_[1] ? $_[1] : ''); # XXX
  }
} # encode_web_charset

sub decode_web_charset ($$) {
  my $key = $_[0];
  my $offset = 0;
  if ($_[1] =~ /^\xEF\xBB\xBF/) {
    $key = 'utf-8';
  } elsif ($_[1] =~ /^\xFE\xFF/) {
    $key = 'utf-16be';
    $offset = 2;
  } elsif ($_[1] =~ /^\xFF\xFE/) {
    $key = 'utf-16le';
    $offset = 2;
  }
  if ($key eq 'utf-8') {
    return decode_web_utf8 $_[1];
  } elsif (_is_single $key) {
    if (not defined $_[1]) {
      carp "Use of uninitialized value an argument";
      return '';
    } elsif (utf8::is_utf8 $_[1]) {
      croak "Cannot decode string with wide characters";
    }
    require Web::Encoding::_Single;
    my $s = $_[1]; # string copy!
    my $Map = \($Web::Encoding::_Single::Decoder->{$_[0]});
    #$s =~ s{([\x80-\xFF])}{$Map->[-0x80 + ord $1]}g;
    $s =~ s{([\x80-\xFF])}{substr $$Map, -0x80 + ord $1, 1}ge;
    #return undef if $s =~ /\x{FFFD}/ and error mode is fatal;
    return $s;
  } elsif ($key eq 'utf-16be') {
    return _decode_16 {}, $offset, $_[1], 1, 'n';
  } elsif ($key eq 'utf-16le') {
    return _decode_16 {}, $offset, $_[1], 1, 'v';
  } elsif ($key eq 'replacement') {
    if (not defined $_[1]) {
      carp "Use of uninitialized value an argument";
      return '';
    } elsif (utf8::is_utf8 $_[1]) {
      croak "Cannot decode string with wide characters";
    } elsif (length $_[1]) {
      return "\x{FFFD}";
    } else {
      return '';
    }
  } else {
    require Encode;
    return Encode::decode ($key, $_[1]); # XXX
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

1;

=head1 LICENSE

Copyright 2011-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
