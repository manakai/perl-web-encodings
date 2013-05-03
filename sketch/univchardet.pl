use strict;
use warnings;
use Web::Encoding::UnivCharDet;

my $det = Web::Encoding::UnivCharDet->new;

local $/ = undef;
warn $det->detect_byte_string (<>);

$det->_dump;
