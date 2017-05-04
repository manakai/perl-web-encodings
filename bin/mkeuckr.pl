use strict;
use warnings;
use JSON::PS;
use Path::Tiny;
use Data::Dumper;

my $json_path = path (__FILE__)->parent->parent->child
    ('local/encoding-indexes.json');
my $json = json_bytes2perl $json_path->slurp;

my $Encoder = {};
my $Decoder = {};

sub b ($) {
  my $pointer = shift;
  my $lead = int ($pointer / 190) + 0x81;
  my $trail = $pointer % 190 + 0x41;
  return pack 'CC', $lead, $trail;
} # b

sub bytes ($) {
  my $s = shift;
  $s =~ s/(.)/sprintf '\\x%02X', ord $1/ges;
  return $s;
} # bytes

for my $name (qw(euc-kr)) {
  $Decoder->{$name} = [map { defined $_ ? chr $_ : undef } @{$json->{$name}}];

  my $map = {};
  for (0..$#{$json->{$name}}) {
    my $v = $json->{$name}->[$_];
    if (defined $v) {
      $map->{$v} = b $_;
    }
  }
  $Encoder->{bmp} = join '', map {
    $map->{$_} // "\x00\x00";
  } 0x0000..0xFFFF;
}

$Data::Dumper::Sortkeys = 1;
print '$Web::Encoding::_EUCKR::EncodeBMP = ';
print Dumper $Encoder->{bmp};
print '$Web::Encoding::_EUCKR::DecodeIndex = ';
print Dumper $Decoder->{'euc-kr'};
print "1;";

## License: Public Domain.
