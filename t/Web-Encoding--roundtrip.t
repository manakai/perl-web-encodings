use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps', 'modules', '*', 'lib');
use Test::X1;
use Test::More;
use Web::Encoding;

my $data_path = path (__FILE__)->parent->parent->child ('t_deps/tests/largedata');
for (qw(
  complete.html
  htmlspec.html
  era-defs.json
)) {
  my $path = $data_path->child ($_);

  test {
    my $c = shift;
    my $bytes = $path->slurp;
    my $text = decode_web_utf8 $bytes;
    my $rebytes = encode_web_utf8 $text;
    is $rebytes, $bytes;
    done $c;
  } n => 1, name => ['reencode', $path];
}

run_tests;

=head1 LICENSE

Copyright 2020 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
