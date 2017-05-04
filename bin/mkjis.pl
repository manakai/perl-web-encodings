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
  my $lead = int ($pointer / 188);
  my $lead_offset = $lead < 0x1F ? 0x81 : 0xC1;
  my $trail = $pointer % 188;
  my $offset = $trail < 0x3F ? 0x40 : 0x41;
  return pack 'CC', $lead + $lead_offset, $trail + $offset;
} # b

sub bytes ($) {
  my $s = shift;
  $s =~ s/(.)/sprintf '\\x%02X', ord $1/ges;
  return $s;
} # bytes

for my $name (qw(jis0208)) {
  $Decoder->{$name} = [map { defined $_ ? chr $_ : undef } @{$json->{$name}}];

  ## <https://encoding.spec.whatwg.org/#index-shift_jis-pointer>
  my $map = {};
  for (0..$#{$json->{$name}}) {
    next if 8272 <= $_ and $_ <= 8835;

    my $v = $json->{$name}->[$_];
    if (defined $v) {
      $map->{$v} //= b $_;
    }
  }
  ## <https://encoding.spec.whatwg.org/#big5>
  $map->{0x0080} = "\x00\x80";
  $map->{0x00A5} = "\x00\x5C";
  $map->{0x203E} = "\x00\x7E";
  $map->{$_} = pack 'CC', 0, $_ - 0xFF61 + 0xA1 for 0xFF61 .. 0xFF9F;
  $map->{0x2212} = $map->{0xFF0D};
  $Encoder->{bmpsjis} = join '', map {
    $map->{$_} // "\x00\x00";
  } 0x0000..0xFFFF;
}

$Data::Dumper::Sortkeys = 1;
print '$Web::Encoding::_JIS::EncodeBMPSJIS = ';
print Dumper $Encoder->{bmpsjis};
print '$Web::Encoding::_JIS::DecodeIndex = ';
print Dumper $Decoder->{jis0208};
print "1;";

## License: Public Domain.
