package Web::Encoding::Normalization;
use strict;
use warnings;
our $VERSION = '1.0';
use Carp;
use Web::Encoding::_UnicodeNormalize;

sub import ($;@) {
  my $from_class = shift;
  my ($to_class, $file, $line) = caller;
  no strict 'refs';
  for (@_ ? @_ : @{$from_class . '::EXPORT'}) {
    my $code = $from_class->can ($_)
        or croak qq{"$_" is not exported by the $from_class module at $file line $line};
    *{$to_class . '::' . $_} = $code;
  }
} # import

our @EXPORT = qw(to_nfc to_nfd to_nfkc to_nfkd);

sub to_nfc ($) { return Web::Encoding::_UnicodeNormalize::NFC ($_[0]) }
sub to_nfd ($) { return Web::Encoding::_UnicodeNormalize::NFD ($_[0]) }
sub to_nfkc ($) { return Web::Encoding::_UnicodeNormalize::NFKC ($_[0]) }
sub to_nfkd ($) { return Web::Encoding::_UnicodeNormalize::NFKD ($_[0]) }

1;

=head1 LICENSE

Copyright 2016 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
