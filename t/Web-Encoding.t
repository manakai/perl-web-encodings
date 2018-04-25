use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps', 'modules', '*', 'lib');
use Test::X1;
use Test::More;
use Web::Encoding;

sub u ($) {
  my $x = $_[0];
  utf8::upgrade $x;
  return $x;
} # u

for (
  [undef, ''],
  ['', ''],
  ["\x00", "\x00"],
  ['abc', 'abc'],
  [u 'abc', 'abc'],
  ["\x80\xC0", "\xC2\x80\xC3\x80"],
  [u "\x80\xC0", "\xC2\x80\xC3\x80"],
  ["\x{D800}", "\xEF\xBF\xBD"],
  ["\x{DFFF}", "\xEF\xBF\xBD"],
  ["\x{110000}", "\xEF\xBF\xBD"],
) {
  my ($input, $output) = @$_;
  test {
    my $c = shift;
    my $result = encode_web_utf8 $input;
    is $result, $output;
    ok ! utf8::is_utf8 $result;
    done $c;
  } n => 2, name => 'encode_web_utf8';

  test {
    my $c = shift;
    my $result = encode_web_charset "utf-8", $input;
    is $result, $output;
    ok ! utf8::is_utf8 $result;
    done $c;
  } n => 2, name => 'encode_web_charset utf-8';
}

for (
  [undef, '', ''],
  ['', ''],
  ['0', '0'],
  ["\x00", "\x00"],
  ["\xC0\x80", "\x{FFFD}\x{FFFD}"],
  ["\xEF\xBB\xBF\xED\xA0\x80", "\x{FFFD}\x{FFFD}\x{FFFD}", "\x{FEFF}\x{FFFD}\x{FFFD}\x{FFFD}"],
  ["\xE4\xB8\x80", "\x{4e00}"],
) {
  my ($input, $output, $output2) = @$_;
  $output2 = $output if not defined $output2;
  test {
    my $c = shift;
    is decode_web_utf8 $input, $output, 'with BOM';
    is decode_web_utf8_no_bom $input, $output2, 'w/o BOM';
    is decode_web_charset ("utf-8", $input), $output, 'charset';
    done $c;
  } n => 3, name => ['decode_web_utf8', $input];
}

test {
  my $c = shift;
  "\x91" =~ /(.)/;
  my $result = decode_web_utf8 $1;
  is $result, "\x{FFFD}";
  done $c;
} n => 1, name => 'decode_web_utf8 regexp';

test {
  my $c = shift;
  "\x91" =~ /(.)/;
  my $result = decode_web_utf8_no_bom $1;
  is $result, "\x{FFFD}";
  done $c;
} n => 1, name => 'decode_web_utf8_no_bom regexp';

test {
  my $c = shift;
  my $input = u "abc";
  eval { decode_web_utf8 $input };
  like $@, qr{^Cannot decode string with wide characters at \Q@{[__FILE__]}\E line @{[__LINE__-1]}\.};
  done $c;
} n => 1, name => 'decode_web_utf8 utf8 flagged string';

test {
  my $c = shift;
  my $input = "\x{5333}abc";
  eval { decode_web_utf8 $input };
  like $@, qr{^Cannot decode string with wide characters at \Q@{[__FILE__]}\E line @{[__LINE__-1]}\.};
  done $c;
} n => 1, name => 'decode_web_utf8 utf8 flagged string';

test {
  my $c = shift;
  my $input = u "abc";
  eval { decode_web_utf8_no_bom $input };
  like $@, qr{^Cannot decode string with wide characters at \Q@{[__FILE__]}\E line @{[__LINE__-1]}\.};
  done $c;
} n => 1, name => 'decode_web_utf8_no_bom utf8 flagged string';

test {
  my $c = shift;
  my $input = "\x{5333}abc";
  eval { decode_web_utf8_no_bom $input };
  like $@, qr{^Cannot decode string with wide characters at \Q@{[__FILE__]}\E line @{[__LINE__-1]}\.};
  done $c;
} n => 1, name => 'decode_web_utf8_no_bom utf8 flagged string';

for my $name (qw(utf-8 shift_jis windows-1252 utf-16be utf-16le)) {
  test {
    my $c = shift;
    my $result = encode_web_charset ($name, undef);
    is $result, '';
    ok ! utf8::is_utf8 $result;
    done $c;
  } n => 2, name => 'encode_web_charset undef';

  test {
    my $c = shift;
    my $result = encode_web_charset ($name, '');
    is $result, '';
    ok ! utf8::is_utf8 $result;
    done $c;
  } n => 2, name => 'encode_web_charset empty';
}

for my $name (qw(utf-8 windows-1252 replacement utf-16be utf-16le)) {
  test {
    my $c = shift;
    is decode_web_charset ($name, undef), '';
    done $c;
  } n => 1, name => 'decode_web_charset undef';

  test {
    my $c = shift;
    is decode_web_charset ($name, ''), '';
    done $c;
  } n => 1, name => 'decode_web_charset empty';

  test {
    my $c = shift;
    my $input = u "abc";
    eval { decode_web_charset $name, $input };
    like $@, qr{^Cannot decode string with wide characters at \Q@{[__FILE__]}\E line @{[__LINE__-1]}\.};
    done $c;
  } n => 1, name => ['decode_web_charset utf8 flagged string', $name];

  test {
    my $c = shift;
    my $input = "\x{5333}abc";
    eval { decode_web_charset $name, $input };
    like $@, qr{^Cannot decode string with wide characters at \Q@{[__FILE__]}\E line @{[__LINE__-1]}\.};
    done $c;
  } n => 1, name => ['decode_web_charset utf8 flagged string', $name];
}

for my $input (
  undef,
  '',
  '0',
  'x',
  (u 'x'),
  "\x{5533}",
  "\x{110000}",
) {
  test {
    my $c = shift;
    eval { encode_web_charset 'replacement', $input };
    like $@, qr{^The replacement encoding has no encoder at \Q@{[__FILE__]}\E line @{[__LINE__-1]}\.};
    done $c;
  } n => 1, name => 'encode_web_charset replacement';
}

for my $key (undef, '', "ac", "iso-2022-kr", "EUC", "unicode",
             "SHIFT_JIS", "\x{4563}") {
  test {
    my $c = shift;
    eval {
      encode_web_charset $key, '';
    };
    like $@, qr{^Bad encoding key \|\Q$key\E\| at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => ['encode_web_charset bad key', $key];

  test {
    my $c = shift;
    eval {
      decode_web_charset $key, '';
    };
    like $@, qr{^Bad encoding key \|\Q$key\E\| at \Q@{[__FILE__]}\E line \Q@{[__LINE__-2]}\E};
    done $c;
  } n => 1, name => ['decode_web_charset bad key', $key];
}

test {
  my $c = shift;
  my $result = encode_web_charset "utf-16be", "\x{110000}";
  is $result, "\xFF\xFD";
  ok ! utf8::is_utf8 $result;
  my $result2 = encode_web_charset "utf-16le", "\x{110000}";
  is $result2, "\xFD\xFF";
  ok ! utf8::is_utf8 $result2;
  done $c;
} n => 4;

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
  ['replacement' => 'replacement'],
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
    ok !is_utf16_encoding_key $name;
    done $c;
  } n => 2, name => ['is_ascii_compat_encoding_name', $name];
}

for my $name (qw(utf-16be utf-16le)) {
  test {
    my $c = shift;
    ok not is_ascii_compat_encoding_name $name;
    ok is_utf16_encoding_key $name;
    done $c;
  } n => 2, name => ['is_ascii_compat_encoding_name', $name];
}

for my $test (
  ['utf-8' => 'utf-8'],
  ['utf-16be' => 'utf-8'],
  ['utf-16le' => 'utf-8'],
  ['x-user-defined' => 'windows-1252'],
  ['replacement' => 'replacement'],
  ['windows-1252' => 'windows-1252'],
) {
  test {
    my $c = shift;
    is fixup_html_meta_encoding_name $test->[0], $test->[1];
    done $c;
  } n => 1, name => ['fixup_html_meta_encoding_name', $test->[0]];
}

for my $test (
  ['utf-8' => 'utf-8'],
  ['utf-16be' => 'utf-8'],
  ['utf-16le' => 'utf-8'],
  ['x-user-defined' => 'x-user-defined'],
  ['replacement' => 'utf-8'],
  ['windows-1252' => 'windows-1252'],
) {
  test {
    my $c = shift;
    is get_output_encoding_key $test->[0], $test->[1];
    done $c;
  } n => 1, name => ['get_output_encoding_key', $test->[0]];
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

test {
  my $c = shift;

  is ref encoding_names, 'ARRAY';
  is encoding_names->[0], 'utf-8';
  is encoding_names->[-1], 'replacement';
  ok grep { $_ eq 'windows-1252' } @{+encoding_names};

  done $c;
} n => 4, name => 'encoding_names';

run_tests;

=head1 LICENSE

Copyright 2011-2018 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
