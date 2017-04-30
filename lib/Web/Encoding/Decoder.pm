package Web::Encoding::Decoder;
use strict;
use warnings;
our $VERSION = '1.0';
use Carp;
use Web::Encoding;

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

sub bom_sniffing ($;$) {
  if (@_ > 1) {
    $_[0]->{bom_sniffing} = $_[1];
  }
  return $_[0]->{bom_sniffing};
} # bom_sniffing

sub used_encoding_key ($) {
  return $_[0]->{key};
} # used_encoding_key

sub bytes ($$) {
  my $key = $_[0]->{key};
  my $offset = 0;
  if ($_[0]->{bom_sniffing}) {
    if ($_[1] =~ /^\xEF\xBB\xBF/) {
      $_[0]->{key} = $key = 'utf-8';
    } elsif ($_[1] =~ /^\xFE\xFF/) {
      $_[0]->{key} = $key = 'utf-16be';
      $offset = 2;
    } elsif ($_[1] =~ /^\xFF\xFE/) {
      $_[0]->{key} = $key = 'utf-16le';
      $offset = 2;
    }
  } elsif ($_[0]->{ignore_bom}) {
    if ($key eq 'utf-16be' and $_[1] =~ /^\xFE\xFF/) {
      $offset = 2;
    } elsif ($key eq 'utf-16le' and $_[1] =~ /^\xFF\xFE/) {
      $offset = 2;
    }
  }
  if ($key eq 'utf-8') {
    if ($_[0]->{bom_sniffing} or $_[0]->{ignore_bom}) {
      return Web::Encoding::decode_web_utf8 $_[1];
    } else {
      return Web::Encoding::decode_web_utf8_no_bom $_[1];
    }
  } elsif (Web::Encoding::_is_single $key) {
    if (not defined $_[1]) {
      carp "Use of uninitialized value an argument";
      return '';
    } elsif (utf8::is_utf8 $_[1]) {
      croak "Cannot decode string with wide characters";
    }
    require Web::Encoding::_Single;
    my $s = $_[1]; # string copy!
    my $Map = \($Web::Encoding::_Single::Decoder->{$_[0]->{key}});
    #$s =~ s{([\x80-\xFF])}{$Map->[-0x80 + ord $1]}g;
    $s =~ s{([\x80-\xFF])}{substr $$Map, -0x80 + ord $1, 1}ge;
    #return undef if $s =~ /\x{FFFD}/ and error mode is fatal;
    return $s;
  } elsif ($key eq 'utf-16be') {
    return Web::Encoding::_decode_16 $_[0]->{states}, $offset, $_[1], 1, 'n';
  } elsif ($key eq 'utf-16le') {
    return Web::Encoding::_decode_16 $_[0]->{states}, $offset, $_[1], 1, 'v';
  } elsif ($key eq 'replacement') {
    if (not defined $_[1]) {
      carp "Use of uninitialized value an argument";
      return '';
    } elsif (utf8::is_utf8 $_[1]) {
      croak "Cannot decode string with wide characters";
    } elsif (not $_[0]->{states}->{written} and length $_[1]) {
      $_[0]->{states}->{written} = 1;
      return "\x{FFFD}";
    } else {
      return '';
    }
  } else {
    require Encode;
    return Encode::decode ($key, $_[1]); # XXX
  }
} # bytes

sub eof ($) {
  return '';
} # eof

1;

=head1 LICENSE

Copyright 2011-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
