use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;

test {
  my $c = shift;

  eval q{
    use Web::Encoding::Preload;
  };

  ok ! $@;

  is +Web::Encoding::encode_web_utf8 ("\x{4e00}"), "\xE4\xB8\x80";

  done $c;
} n => 2;

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
