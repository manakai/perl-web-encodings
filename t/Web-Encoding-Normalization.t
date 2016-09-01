use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('t_deps', 'modules', '*', 'lib');
use Test::X1;
use Test::More;
use Web::Encoding::Normalization;

for (
  [''],
  ['0'],
  ["\x81\xFE"],
  ["\xA0", undef, undef, " ", " "],
  ["\xAD"],
  ["\x{1E69}", undef, "\x73\x{0323}\x{0307}"],
  ["\x73\x{0323}\x{0307}", "\x{1E69}", undef],
  ["\x73\x{0307}\x{0323}", "\x{1E69}", "\x73\x{0323}\x{0307}"],
  ["\x{1E0B}\x{0323}", "\x{1E0D}\x{0307}", "\x64\x{0323}\x{0307}"],
  ["\x71\x{0307}\x{0323}", "\x71\x{0323}\x{0307}", "\x71\x{0323}\x{0307}"],
  ["\x{FB01}", undef, undef, "fi", "fi"],
  ["\x{1E9B}\x{0323}", "\x{1E9B}\x{0323}", "\x{017F}\x{0323}\x{0307}", "\x{1E69}", "\x73\x{0323}\x{0307}"],
  ["\x{212B}", "\xC5", "\x41\x{030A}"],
) {
  my ($input, $nfc, $nfd, $nfkc, $nfkd) = @$_;
  $nfc = $input if not defined $nfc;
  $nfd = $input if not defined $nfd;
  $nfkc = $nfc if not defined $nfkc;
  $nfkd = $nfd if not defined $nfkd;
  test {
    my $c = shift;
    my $nfc = to_nfc $input;
    is $nfc, $nfc, 'NFC';
    ok is_nfc $nfc;
    my $nfd = to_nfd $input;
    is $nfd, $nfd, 'NFD';
    ok $nfc eq $nfd || ! is_nfc $nfd;
    is to_nfkc $input, $nfkc, 'NFKC';
    is to_nfkd $input, $nfkd, 'NFKD';
    done $c;
  } n => 6, name => $input;
}

run_tests;

=head1 LICENSE

Copyright 2016 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
