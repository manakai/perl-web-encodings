use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use Test::HTCT::Parser;
use Web::Encoding;
use Web::Encoding::Sniffer;

my $tests_path = path (__FILE__)->parent->parent->child
    ('t_deps/tests/charset/sniffing');

for my $test_file_path ($tests_path->children (qr/\.dat$/)) {
  my $file_name = $test_file_path->relative ($tests_path);
  my $Encoding;
  for_each_test $test_file_path, {
    data => {prefixed => 1},
  }, sub {
    my $test = shift;

    test {
      my $c = shift;

      my $bytes = encode_web_utf8 $test->{data}->[0];
      $bytes =~ s/\\x([0-9A-Fa-f]{2})/pack 'C', hex $1/ge;

      my $sniffer = Web::Encoding::Sniffer->new_from_context ($test->{context}->[1]->[0]);
      $sniffer->detect (
        $bytes,
        override => $test->{override}->[1]->[0],
        transport => $test->{transport}->[1]->[0],
        embed => $test->{embed}->[1]->[0],
        reference => $test->{reference}->[1]->[0],
        locale => $test->{locale}->[1]->[0],
      );
      is $sniffer->encoding, $test->{encoding}->[1]->[0];
      is $sniffer->confident ? 'certain' : 'tentative', $test->{confidence}->[1]->[0];
      is $sniffer->source, $test->{source}->[1]->[0];

      done $c;
    } n => 3, name => [$file_name, $test->{name}->[0] || $test->{data}->[0]];
  };
} # $test_file_path

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
