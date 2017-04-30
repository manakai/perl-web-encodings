use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use Test::HTCT::Parser;
use Web::Encoding;
use Web::Encoding::Decoder;

my $tests_path = path (__FILE__)->parent->parent->child
    ('t_deps/tests/charset/encodings');

for my $test_file_path ($tests_path->children (qr/\.dat$/)) {
  my $file_name = $test_file_path->relative ($tests_path);
  my $Encoding;
  for_each_test $test_file_path, {
    b => {is_list => 1},
    c => {is_list => 1},
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
        [1, 0, $opts->{nobomsniffing} || $opts->{nobom}],
        [0, 1, $opts->{bomsniffing} || $opts->{nobom}],
        [0, 0, $opts->{bomsniffing} || $opts->{bom}],
      ) {
        my ($BOMSniffing, $Ignore, $skip) = @$_;
        next if $skip;
        test {
          my $c = shift;
          my $decoder = Web::Encoding::Decoder->new_from_encoding_key ($encoding);
          $decoder->bom_sniffing ($BOMSniffing);
          $decoder->ignore_bom ($Ignore);
          my $result = '';
          $result .= $decoder->bytes ($_) for @$bytes;
          $result .= $decoder->eof;
          is $result, join '', @$chars;
          is $decoder->used_encoding_key, $test->{used}->[0] || $encoding;
          done $c;
        } n => 2, name => [$file_name, "decoder $BOMSniffing/$Ignore", $test->{name}->[0] || join "\n", @{$test->{b}->[0]}];

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
        ok ! utf8::is_utf8 $result;
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

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
