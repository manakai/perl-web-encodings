package Web::Encoding;
use strict;
use warnings;
our $VERSION = '4.0';
use Exporter::Lite;
use Encode;
use Web::Encoding::_Defs;

our @EXPORT = qw(
  encode_web_utf8
  decode_web_utf8
  encode_web_charset
  decode_web_charset
  is_ascii_compat_charset_name
);

sub encode_web_utf8 ($) {
  return Encode::encode ('utf-8', $_[0]);
} # encode_web_utf8

sub decode_web_utf8 ($) {
  return Encode::decode ('utf-8', $_[0]); # XXX error-handling
} # decode_web_utf8

sub encode_web_charset ($$) {
  return Encode::encode ($_[0], $_[1]); # XXX
} # encode_web_charset

sub decode_web_charset ($$) {
  return Encode::decode ($_[0], $_[1]); # XXX
} # decode_web_charset

push @EXPORT, qw(encoding_label_to_name);
sub encoding_label_to_name ($) {
  ## Get an encoding
  ## <http://encoding.spec.whatwg.org/#concept-encoding-get>.
  my $label = $_[0] || '';
  $label =~ s/\A[\x09\x0A\x0C\x0D\x20]+//; ## ASCII whitespace
  $label =~ s/[\x09\x0A\x0C\x0D\x20]+\z//; ## ASCII whitespace
  $label =~ tr/A-Z/a-z/; ## ASCII case-insensitive.
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

push @EXPORT, qw(is_ascii_compat_encoding_name);
sub is_ascii_compat_encoding_name ($) {
  my $name = $_[0];
  return 0 if not defined $name;
  return 0 if $name eq 'utf-16be' or $name eq 'utf-16le' or $name eq 'replacement';
  return 1;
} # is_ascii_compat_encoding_name

push @EXPORT, qw(fixup_html_meta_encoding_name);
sub fixup_html_meta_encoding_name ($) {
  return $Web::Encoding::_Defs->{html_decl_map}->{$_[0]} || $_[0];
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

Copyright 2011-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
