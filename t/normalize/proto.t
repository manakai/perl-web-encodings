
BEGIN {
    unless ('A' eq pack('U', 0x41)) {
	print "1..0 # Unicode::Normalize cannot pack a Unicode code point\n";
	exit 0;
    }
    unless (0x41 == unpack('U', 'A')) {
	print "1..0 # Unicode::Normalize cannot get a Unicode code point\n";
	exit 0;
    }
}

BEGIN {
    if ($ENV{PERL_CORE}) {
	chdir('t') if -d 't';
	@INC = $^O eq 'MacOS' ? qw(::lib) : qw(../lib);
    }
}

#########################

use strict;
use warnings;
BEGIN { $| = 1; print "1..48\n"; }
my $count = 0;
sub ok ($;$) {
    my $p = my $r = shift;
    if (@_) {
	my $x = shift;
	$p = !defined $x ? !defined $r : !defined $r ? 0 : $r eq $x;
    }
    print $p ? "ok" : "not ok", ' ', ++$count, "\n";
}

use Web::Encoding::_UnicodeNormalize;
BEGIN {
*NFC = \&Web::Encoding::_UnicodeNormalize::NFC;
*NFD = \&Web::Encoding::_UnicodeNormalize::NFD;
*NFKC = \&Web::Encoding::_UnicodeNormalize::NFKC;
*NFKD = \&Web::Encoding::_UnicodeNormalize::NFKD;
*FCC = \&Web::Encoding::_UnicodeNormalize::FCC;
*FCD = \&Web::Encoding::_UnicodeNormalize::FCD;
*reorder = \&Web::Encoding::_UnicodeNormalize::reorder;
}

ok(1);

#########################

# unary op. RING-CEDILLA
ok(        "\x{30A}\x{327}" ne "\x{327}\x{30A}");
ok(NFD     "\x{30A}\x{327}" eq "\x{327}\x{30A}");
ok(NFC     "\x{30A}\x{327}" eq "\x{327}\x{30A}");
ok(NFKD    "\x{30A}\x{327}" eq "\x{327}\x{30A}");
ok(NFKC    "\x{30A}\x{327}" eq "\x{327}\x{30A}");
ok(FCD     "\x{30A}\x{327}" eq "\x{327}\x{30A}");
ok(FCC     "\x{30A}\x{327}" eq "\x{327}\x{30A}");
ok(reorder "\x{30A}\x{327}" eq "\x{327}\x{30A}");

# 9

ok(prototype \&Web::Encoding::_UnicodeNormalize::normalize,'$$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::NFD,  '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::NFC,  '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::NFKD, '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::NFKC, '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::FCD,  '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::FCC,  '$');

ok(prototype \&Web::Encoding::_UnicodeNormalize::check,    '$$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::checkNFD, '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::checkNFC, '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::checkNFKD,'$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::checkNFKC,'$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::checkFCD, '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::checkFCC, '$');

ok(prototype \&Web::Encoding::_UnicodeNormalize::decompose, '$;$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::reorder,   '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::compose,   '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::composeContiguous, '$');

# 27

ok(prototype \&Web::Encoding::_UnicodeNormalize::getCanon,      '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::getCompat,     '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::getComposite,  '$$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::getCombinClass,'$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::isExclusion,   '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::isSingleton,   '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::isNonStDecomp, '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::isComp2nd,     '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::isComp_Ex,     '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::isNFD_NO,      '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::isNFC_NO,      '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::isNFC_MAYBE,   '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::isNFKD_NO,     '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::isNFKC_NO,     '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::isNFKC_MAYBE,  '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::splitOnLastStarter, undef);
ok(prototype \&Web::Encoding::_UnicodeNormalize::normalize_partial, '$$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::NFD_partial,  '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::NFC_partial,  '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::NFKD_partial, '$');
ok(prototype \&Web::Encoding::_UnicodeNormalize::NFKC_partial, '$');

# 48

