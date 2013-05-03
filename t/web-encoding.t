use strict;
use warnings;
use Path::Class;
use lib glob file (__FILE__)->dir->parent->subdir ('t_deps', 'modules', '*', 'lib');
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

run_tests;

=head1 LICENSE

Copyright 2011-2013 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
