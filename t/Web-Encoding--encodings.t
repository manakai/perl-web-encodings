use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use Test::HTCT::Parser;
use Web::Encoding;
use Web::Encoding::Decoder;
use Web::Encoding::Sniffer;

my $tests_path = path (__FILE__)->parent->parent->child
    ('t_deps/tests/charset/encodings');

for my $test_file_path ($tests_path->children (qr/\.dat$/)) {
  my $file_name = $test_file_path->relative ($tests_path);
  my $Encoding;
  for_each_test $test_file_path, {
    b => {is_list => 1},
    c => {is_list => 1},
    errors => {is_list => 1},
  }, sub {
    my $test = shift;

    my $encoding = $Encoding;
    if (defined $test->{encoding}) {
      $encoding = $Encoding = $test->{encoding}->[0];
    }

    my $bytes;
    if (defined $test->{b}) {
      $bytes = [map {
        my $v = encode_web_utf8 $_;
        $v = '' if $v eq '_';
        $v =~ s/\\x([0-9A-Fa-f]{2})/pack 'C', hex $1/ge;
        $v;
      } @{$test->{b}->[0]}];
      $bytes = [''] unless @$bytes;
    }
    my $chars;
    if (defined $test->{c}) {
      $chars = [map {
        my $v = $_;
        $v = '' if $v eq '_';
        $v =~ s/\\u\{([0-9A-Fa-f]+)\}/chr hex $1/ge;
        $v;
      } @{$test->{c}->[0]}];
      $chars = [''] unless @$chars;
    }

    if (defined $bytes or defined $chars) {
      die "#encoding not specified" unless defined $encoding;
      die "Test has no #b or #c" unless defined $bytes and defined $bytes;
      die "Test has none of #bc and #cb (#b |@{$test->{b}->[0]}| #c |@{$test->{c}->[0]}|)" unless $test->{bc} or $test->{cb};
    }

    if ($test->{bc}) {
      my $opts = {map { $_ => 1 } @{$test->{bc}->[1]}};
      for (
        [1, 1, $opts->{nobomsniffing} || $opts->{nobom}],
        #[1, 0, $opts->{nobomsniffing} || $opts->{nobom}],
        [0, 1, $opts->{bomsniffing} || $opts->{nobom}],
        [0, 0, $opts->{bomsniffing} || $opts->{bom}],
      ) {
        my ($BOMSniffing, $Ignore, $skip) = @$_;
        next if $skip;

        test {
          my $c = shift;
          my $enc = $encoding;
          if ($BOMSniffing) {
            $enc = 'iso-2022-kr' if $enc eq 'replacement';
            my $sniffer = Web::Encoding::Sniffer->new_from_context ('');
            $sniffer->detect (
              (join '', @$bytes),
              override => $enc,
            );
            $enc = $sniffer->encoding;
          }
          my $decoder = Web::Encoding::Decoder->new_from_encoding_key ($enc);
          $decoder->ignore_bom ($Ignore);
          my @error;
          $decoder->onerror (sub {
            my %args = @_;
            my $value = $args{value} || '';
            $value =~ s/(.)/sprintf '\x%02X', ord $1/ges;
            push @error, join ';',
                $args{index},
                $args{level},
                $args{type} . (defined $args{text} ? '$' . $args{text} : ''),
                $value;
          });
          my $result = '';
          $result .= join '', @{$decoder->bytes ($_)} for @$bytes;
          $result .= join '', @{$decoder->eof};
          is $result, join '', @$chars;
          is $decoder->used_encoding_key, $test->{used}->[0] || $encoding;
          $test->{errors}->[0] = [sort { $a cmp $b } @{$test->{errors}->[0] or []}];
          @error = sort { $a cmp $b } @error;
          is join ("\n", @error), join ("\n", @{$test->{errors}->[0] or []}), "errors";
          done $c;
        } n => 3, name => [$file_name, "decoder $BOMSniffing/$Ignore", $test->{name}->[0] || join "\n", @{$test->{b}->[0]}];

        test {
          my $c = shift;
          my $enc = $encoding;
          if ($BOMSniffing) {
            $enc = 'iso-2022-kr' if $enc eq 'replacement';
            my $sniffer = Web::Encoding::Sniffer->new_from_context ('');
            $sniffer->detect (
              (join '', @$bytes),
              override => $enc,
            );
            $enc = $sniffer->encoding;
          }
          my $decoder = Web::Encoding::Decoder->new_from_encoding_key ($enc);
          $decoder->ignore_bom ($Ignore);
          my @error;
          $decoder->onerror (sub {
            my %args = @_;
            my $value = $args{value} || '';
            $value =~ s/(.)/sprintf '\x%02X', ord $1/ges;
            push @error, join ';',
                $args{index},
                $args{level},
                $args{type} . (defined $args{text} ? '$' . $args{text} : ''),
                $value;
          });
          $decoder->fatal (1);
          my $result = '';
          eval {
            $result .= join '', @{$decoder->bytes ($_)} for @$bytes;
            $result .= join '', @{$decoder->eof};
          };
          $test->{errors}->[0] = [sort { $a cmp $b } @{$test->{errors}->[0] or []}];
          @error = sort { $a cmp $b } @error;
          if (($test->{errors}->[1]->[0] || '') eq 'fatal') {
            like $@, qr{^Input has invalid bytes}, 'exception';
            ok 1;
            is join ("\n", @error), join ("\n", grep { /;m;/ } @{$test->{errors}->[0] or []}), "errors (fatal)";
          } else {
            ok ! $@, 'no exception';
            is $result, join '', @$chars;
            is join ("\n", @error), join ("\n", grep { not /;m;(?!iso2022jp:jis78)/ } @{$test->{errors}->[0] or []}), "errors";
          }
          done $c;
        } n => 3, name => [$file_name, "decoder $BOMSniffing/$Ignore with fatal", $test->{name}->[0] || join "\n", @{$test->{b}->[0]}];

        if (not $BOMSniffing and $Ignore) {
          test {
            my $c = shift;
            my $result = decode_web_charset $encoding, join '', @$bytes;
            is $result, join '', @$chars;
            done $c;
          } n => 1, name => [$file_name, 'decode_web_charset', $test->{name}->[0] || join "\n", @{$test->{b}->[0]}];
        }

        if (not $BOMSniffing and $Ignore and $encoding eq 'utf-8') {
          test {
            my $c = shift;
            my $result = decode_web_utf8 join '', @$bytes;
            is $result, join '', @$chars;
            done $c;
          } n => 1, name => [$file_name, 'utf-8 bc', $test->{name}->[0] || join "\n", @{$test->{b}->[0]}];
        }

        if (not $BOMSniffing and not $Ignore and $encoding eq 'utf-8') {
          test {
            my $c = shift;
            my $result = decode_web_utf8_no_bom join '', @$bytes;
            is $result, join '', @$chars;
            done $c;
          } n => 1, name => [$file_name, 'utf-8 no BOM bc', $test->{name}->[0] || join "\n", @{$test->{b}->[0]}];
        }
      } # for
    } # $test->{bc}

    if ($test->{cb}) {
      test {
        my $c = shift;
        my $result = encode_web_charset $encoding, join '', @$chars;
        is $result, join '', @$bytes;
        ok ! (utf8::is_utf8 $result), "no utf8 flag";
        done $c;
      } n => 2, name => [$file_name, 'cb', $test->{name}->[0] || join "\n", @{$test->{c}->[0]}];

      if ($encoding eq 'utf-8') {
        test {
          my $c = shift;
          my $result = encode_web_utf8 join '', @$chars;
          is $result, join '', @$bytes;
          ok ! utf8::is_utf8 $result;
          done $c;
        } n => 2, name => [$file_name, 'utf-8 cb', $test->{name}->[0] || join "\n", @{$test->{c}->[0]}];
      }
    } # $test->{cb}
  };
} # $test_file_path

for my $name (qw(big5 shift_jis gb18030)) {
  test {
    my $c = shift;
    my $input_path = $tests_path->child ("full/${name}_in.txt");
    my $ref_path = $tests_path->child ("full/${name}_in_ref.txt");
    my $result = decode_web_charset $name, $input_path->slurp;
    is $result, decode_web_utf8 $ref_path->slurp;
    done $c;
  } n => 1, name => ['test_data in', $name];

  test {
    my $c = shift;
    my $input_path = $tests_path->child ("full/${name}_out.txt");
    my $ref_path = $tests_path->child ("full/${name}_out_ref.txt");
    my $result = encode_web_charset $name, decode_web_utf8 $input_path->slurp;
    is $result, $ref_path->slurp;

path (__FILE__)->parent->parent->child ("local/hoge.txt")->spew ($result);
    done $c;
  } n => 1, name => ['test_data out', $name];
} # $name

test {
  my $c = shift;
  my $input_path = $tests_path->child ('full/gb18030_in.txt');
  my $ref_path = $tests_path->child ('full/gb18030_in_ref.txt');
  my $result = decode_web_charset 'gbk', $input_path->slurp;
  is $result, decode_web_utf8 $ref_path->slurp;
  done $c;
} n => 1, name => 'test_data in gbk';

test {
  my $c = shift;
  my $input_path = $tests_path->child ('full/jis0208_in.txt');
  my $ref_path = $tests_path->child ('full/jis0208_in_ref.txt');
  my $result = decode_web_charset 'euc-jp', $input_path->slurp;
  is $result, decode_web_utf8 $ref_path->slurp;
  done $c;
} n => 1, name => 'test_data in euc-jp JIS X 0208';

test {
  my $c = shift;
  my $input_path = $tests_path->child ('full/jis0208_out.txt');
  my $ref_path = $tests_path->child ('full/jis0208_out_ref.txt');
  my $result = encode_web_charset 'euc-jp', decode_web_utf8 $input_path->slurp;
  is $result, $ref_path->slurp;
  done $c;
} n => 1, name => 'test_data out euc-jp JIS X 0208';

test {
  my $c = shift;
  my $input_path = $tests_path->child ('full/jis0212_in.txt');
  my $ref_path = $tests_path->child ('full/jis0212_in_ref.txt');
  my $result = decode_web_charset 'euc-jp', $input_path->slurp;
  is $result, decode_web_utf8 $ref_path->slurp;
  done $c;
} n => 1, name => 'test_data in euc-jp JIS X 0212';

test {
  my $c = shift;
  my $input_path = $tests_path->child ('full/euc_kr_in.txt');
  my $ref_path = $tests_path->child ('full/euc_kr_in_ref.txt');
  my $result = decode_web_charset 'euc-kr', $input_path->slurp;
  is $result, decode_web_utf8 $ref_path->slurp;
  done $c;
} n => 1, name => 'test_data in euc-kr';

test {
  my $c = shift;
  my $input_path = $tests_path->child ('full/euc_kr_out.txt');
  my $ref_path = $tests_path->child ('full/euc_kr_out_ref.txt');
  my $result = encode_web_charset 'euc-kr', decode_web_utf8 $input_path->slurp;
  is $result, $ref_path->slurp;
  done $c;
} n => 1, name => 'test_data out euc-kr';

test {
  my $c = shift;
  my $input_path = $tests_path->child ('full/iso_2022_jp_in.txt');
  my $ref_path = $tests_path->child ('full/iso_2022_jp_in_ref.txt');
  my $result = decode_web_charset 'iso-2022-jp', $input_path->slurp;
  is $result, decode_web_utf8 $ref_path->slurp;
  done $c;
} n => 1, name => 'test_data in iso-2022-jp';

test {
  my $c = shift;
  my $input_path = $tests_path->child ('full/iso_2022_jp_out.txt');
  my $ref_path = $tests_path->child ('full/iso_2022_jp_out_ref.txt');
  my $result = encode_web_charset 'iso-2022-jp', decode_web_utf8 $input_path->slurp;
  is $result, $ref_path->slurp;
  done $c;
} n => 1, name => 'test_data out iso-2022-jp';

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
