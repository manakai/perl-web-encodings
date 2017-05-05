use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use Test::X1;
use Test::More;
use Web::Encoding;
use Web::Encoding::Decoder;

for my $key (undef, '', 'abc', '0', "\x{5533}", 'iso-2022-kr',
             'SHIFT_JIS', 'euc') {
  test {
    my $c = shift;
    my $decoder = Web::Encoding::Decoder->new_from_encoding_key ($key);
    eval {
      $decoder->bytes ("a");
    };
    like $@, qr{^Bad encoding key \|\Q$key\E\|};
    eval {
      $decoder->eof;
    };
    like $@, qr{^Bad encoding key \|\Q$key\E\|};
    done $c;
  } n => 2;
}

run_tests;

=head1 LICENSE

Copyright 2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
