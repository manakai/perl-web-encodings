use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps', 'modules', '*', 'lib');
use Test::X1;
use Test::More;
use Web::Encoding;

test {
  my $c = shift;
  is encode_web_utf8 "\x{4e00}", "\xE4\xB8\x80";
  done $c;
} n => 1;

test {
  my $c = shift;
  is decode_web_utf8 "\xE4\xB8\x80", "\x{4e00}";
  done $c;
} n => 1;

for my $test (
  [undef, undef],
  ['' => undef],
  [0 => undef],
  ['UTF-8' => 'utf-8'],
  ['utf-8' => 'utf-8'],
  ["\x0Cutf-8\x0D\x0A" => 'utf-8'],
  ['utf 8' => undef],
  ['utf8' => 'utf-8'],
  ['utf8n' => undef],
  [866 => 'ibm866'],
  ['us-ascii' => 'windows-1252'],
  ['iso-2022-CN' => 'replacement'],
  ['x-user-Defined' => 'x-user-defined'],
  ['replacement' => undef],
  ['cesu-8' => undef],
) {
  test {
    my $c = shift;
    is encoding_label_to_name $test->[0], $test->[1];
    is !!is_encoding_label $test->[0], (defined $test->[1] && $test->[0] !~ /\s/);
    done $c;
  } n => 2, name => [encoding_label_to_name => $test->[0]];
}

for my $name (qw(utf-8 iso-2022-jp windows-1252 koi8-r x-user-defined
                 replacement)) {
  test {
    my $c = shift;
    ok is_ascii_compat_encoding_name $name;
    done $c;
  } n => 1, name => ['is_ascii_compat_encoding_name', $name];
}

for my $name (undef, qw(utf-16be utf-16le)) {
  test {
    my $c = shift;
    ok not is_ascii_compat_encoding_name $name;
    done $c;
  } n => 1, name => ['is_ascii_compat_encoding_name', $name];
}

for my $test (
  ['utf-8' => 'utf-8'],
  ['utf-16be' => 'utf-8'],
  ['utf-16le' => 'utf-8'],
  ['x-user-defined' => 'windows-1252', 'x-user-defined'],
  ['replacement' => 'utf-8'],
  ['windows-1252' => 'windows-1252'],
) {
  test {
    my $c = shift;
    is fixup_html_meta_encoding_name $test->[0], $test->[1];
    is get_output_encoding_key $test->[0], $test->[2] // $test->[1];
    done $c;
  } n => 2, name => ['fixup_html_meta_encoding_name', $test->[0]];
}

for my $test (
  [undef, undef],
  ['' => undef],
  [en => undef],
  [EN => undef],
  [ja => 'shift_jis'],
  ['ja-JP' => undef],
  [ru => 'windows-1251'],
  ['en-gb' => undef],
  ['zh-tw' => 'big5'],
  ['zh-CN' => 'gb18030'],
  [ko => 'euc-kr'],
  [hoge => undef],
  ['*' => 'windows-1252'],
) {
  test {
    my $c = shift;
    is locale_default_encoding_name $test->[0], $test->[1];
    done $c;
  } n => 1, name => ['locale_default_encoding_name', $test->[0]];
}

for my $test (
  [undef, undef],
  [0 => undef],
  [foo => undef],
  ['UTF-8' => undef],
  ['utf8' => undef],
  ['windows-1252' => 'windows-1252'],
  ['shift_jis' => 'Shift_JIS'],
  ['iso-8859-4' => 'ISO-8859-4'],
  ['utf-8' => 'UTF-8'],
  ['replacement' => 'replacement'],
  ['x-user-defined' => 'x-user-defined'],
) {
  test {
    my $c = shift;
    is encoding_name_to_compat_name $test->[0], $test->[1];
    done $c;
  } n => 1, name => ['encoding_name_to_compat_name', $test->[1]];
}

run_tests;

=head1 LICENSE

Copyright 2011-2016 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
