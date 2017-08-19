use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use JSON::PS;
use Web::Encoding::UnivCharDet;

my $data_path = path (__FILE__)->parent->parent->child
    ('t_deps/tests/charset/univchardet/mozilla');
my $json_path = $data_path->child ('tests.json');

my $tests = json_bytes2perl $json_path->slurp;

my $Filters = {
  "" => {},
  "ja_parallel_state_machine" => {ja => 1},
  "ko_parallel_state_machine" => {ko => 1},
  "zh_parallel_state_machine" => {zh_hant => 1, zh_hans => 1},
  "zhtw_parallel_state_machine" => {zh_hant => 1},
  "zhcn_parallel_state_machine" => {zh_hans => 1},
  "cjk_parallel_state_machine" => {ja => 1, zh_hant => 1, zh_hans => 1,
                                   ko => 1},
  "universal_charset_detector" => {ja => 1, zh_hant => 1, zh_hans => 1,
                                   ko => 1, non_cjk => 1},
};

for my $test (@$tests) {
  next if @{$test->[2]} == 1 and $test->[2]->[0] eq '';
  test {
    my $c = shift;

    my $det = Web::Encoding::UnivCharDet->new;
    for (@{$test->[2]}) {
      %{$det->filter} = %{$Filters->{$_} or die "Filter |$_| not defined"};
      my $charset = $det->detect_byte_string
          ($data_path->child ($test->[0])->slurp) || 'windows-1252';
      my $expected = lc $test->[1];
      $expected = 'windows-1252' if $expected eq 'default';
      is $charset, $expected, $_;
    }

    done $c;
  } n => scalar @{$test->[2]}, name => [$test->[0]];
}

run_tests;

=head1 LICENSE

Copyright 2013-2014 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
