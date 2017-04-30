use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps', 'modules', '*', 'lib');
use Test::X1;
use Test::More;
use Web::Encoding;
use JSON::PS;

sub u ($) {
  my $x = $_[0];
  utf8::upgrade $x;
  return $x;
} # u

for my $test (
  ["windows-1252", undef, ''],
) {
  test {
    my $c = shift;
    my $out = decode_web_charset $test->[0], $test->[1];
    is $out, $test->[2];
    done $c;
  } n => 1, name => ['decode_web_charset', $test->[0]];
}

for my $test (
  ["windows-1252", "", ""],
  ["windows-1252", undef, ""],
  ["windows-1252", "0", "0"],
  ["windows-1252", "\x00", "\x00"],
  ["windows-1252", "\xFE\x{20AC}\xCCabc\x90x", "\xFE\x80\xCCabc\x90x"],
  ["windows-1252", "\x80\xFE\xDD\xAC421\xA0\xFE", "&#128;\xFE\xDD\xAC421\xA0\xFE"],
  ["windows-1252", u "\x80\xFE\xDD\xAC421\xA0\xFE", "&#128;\xFE\xDD\xAC421\xA0\xFE"],
  ["windows-1251", "\x80\xFE\xDD\xAC421\xA0\xFE", "&#128;&#254;&#221;\xAC421\xA0&#254;"],
  ["windows-1252", "\x{FFFD}", "&#65533;"],
  ["windows-1252", "\x{FFFE}", "&#65534;"],
  ["windows-1252", "\x{FFFF}", "&#65535;"],
  ["windows-1252", "\x{D800}", "&#55296;"],
  ["windows-1252", "\x{10FFFF}", "&#1114111;"],
  ["windows-1252", "\x{110000}", "&#1114112;"],
  ["windows-1252", u "", ""],
  ["windows-1252", u "bageaegagea", "bageaegagea"],
  ["x-user-defined", "\x{F780}x\x{F781}", "\x80x\x81"],
  ["iso-8859-8", "\x80\xFE\xDD\xAC421\xA0\xFE", "\x80&#254;&#221;\xAC421\xA0&#254;"],
  ["iso-8859-8-i", "\x80\xFE\xDD\xAC421\xA0\xFE", "\x80&#254;&#221;\xAC421\xA0&#254;"],
) {
  test {
    my $c = shift;
    my $out = encode_web_charset $test->[0], $test->[1];
    is $out, $test->[2];
    ok ! utf8::is_utf8 $out;
    done $c;
  } n => 2;
}

{
  my $json_path = path (__FILE__)->parent->parent->child ('local/encoding-indexes.json');
  my $json = json_bytes2perl $json_path->slurp;

  my $input = join '', map { pack 'C', $_ } 0x00..0xFF;
  for my $name (keys %{$json}) {
    my $def = $json->{$name};
    next unless @$def == 128;

    my $decoded = join '', (map { chr $_ } 0..0x7F), (map {
      defined $_ ? chr $_ : "\x{FFFD}";
    } @$def);
    test {
      my $c = shift;
      {
        my $result = decode_web_charset $name, $input;
        is $result, $decoded;
      }
      {
        my $result = decode_web_charset $name, '';
        is $result, '';
      }
      {
        my $result = decode_web_charset $name, '0';
        is $result, '0';
      }
      done $c;
    } n => 3, name => ['decode', $name];

    my $input = join '', (map { chr $_ } 0..0x7F), (map {
      defined $_ ? chr $_ : '';
    } @$def);
    my $encoded = join '', map { pack 'C', $_ } 0x00..0x7F, map {
      defined $def->[$_] ? 0x80 + $_ : ();
    } 0x00..0x7F;
    test {
      my $c = shift;
      my $result = encode_web_charset $name, $input;
      is $result, $encoded;
      ok ! utf8::is_utf8 $result;
      done $c;
    } n => 2, name => ['encode', $name];
  }
}

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
