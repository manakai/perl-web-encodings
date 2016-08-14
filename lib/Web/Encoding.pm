package Web::Encoding;
use strict;
use warnings;
our $VERSION = '6.0';
use Carp;
use Encode;
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
    carp "Use of uninitialized value an argument";
    return '';
  } elsif ($_[0] =~ /[^\x00-\x7F]/) {
    my $x = $_[0];
    if (utf8::is_utf8 $_[0]) {
      $x =~ s/[^\x00-\x{D7FF}\x{E000}-\x{10FFFF}]/\x{FFFD}/g;
    } else {
      utf8::upgrade $x;
    }
    utf8::encode $x;
    return $x;
  } else {
    if (utf8::is_utf8 $_[0]) {
      my $x = $_[0];
      utf8::encode $x;
      return $x;
    } else {
      return $_[0];
    }
  }
} # encode_web_utf8

sub decode_web_utf8 ($) {
  if (not defined $_[0]) {
    carp "Use of uninitialized value an argument";
    return '';
  } elsif ($_[0] =~ /[^\x00-\x7F]/) {
    my $x = $_[0] =~ /\A\xEF\xBB\xBF/ ? substr $_[0], 3 : $_[0];
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
  } else {
    return $_[0];
  }
} # decode_web_utf8

sub decode_web_utf8_no_bom ($) {
  if (not defined $_[0]) {
    carp "Use of uninitialized value an argument";
    return '';
  } elsif ($_[0] =~ /[^\x00-\x7F]/) {
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
  } else {
    return $_[0];
  }
} # decode_web_utf8_no_bom

sub encode_web_charset ($$) {
  if ($_[0] eq 'utf-8') {
    return encode_web_utf8 $_[1];
  } else {
    return Encode::encode ($_[0], defined $_[1] ? $_[1] : ''); # XXX
  }
} # encode_web_charset

sub decode_web_charset ($$) {
  if ($_[0] eq 'utf-8') {
    return decode_web_utf8 $_[1];
  } else {
    return Encode::decode ($_[0], $_[1]); # XXX
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

Copyright 2011-2016 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
