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
  my $trail = $pointer % 190;
  my $offset = $trail < 0x3F ? 0x40 : 0x41;
  return pack 'CC', $lead, $trail + $offset;
} # b

sub bytes ($) {
  my $s = shift;
  $s =~ s/(.)/sprintf '\\x%02X', ord $1/ges;
  return $s;
} # bytes

for my $name (qw(gb18030)) {
  $Decoder->{$name} = [map { defined $_ ? chr $_ : undef } @{$json->{$name}}];

  my $map = {};
  for (0..$#{$json->{$name}}) {
    my $v = $json->{$name}->[$_];
    if (defined $v) {
      if (defined $map->{$v}) {
        # U+3000 \xA1\xA1 \xA3\xA0
        #warn sprintf "U+%04X %s %s\n", $v, bytes $map->{$v}, bytes b $_;
        #$Decoder->{noncanon}->{$_} = 1;
      } else {
        $map->{$v} = b $_;
      }
    }
  }
  delete $map->{0x20AC};
  $Encoder->{bmp} = join '', map {
    $map->{$_} // "\x00\x00";
  } 0x0000..0xFFFF;
  for (keys %$map) {
    next if $_ < 0x10000;
    die sprintf "U+%04X", $_;
  }
}

$Data::Dumper::Sortkeys = 1;
print '$Web::Encoding::_GB::EncodeBMP = ';
print Dumper $Encoder->{bmp};
print '$Web::Encoding::_GB::DecodeIndex = ';
print Dumper $Decoder->{gb18030};
print '$Web::Encoding::_GB::Ranges = ';
print Dumper $json->{'gb18030-ranges'};
print "1;";

## License: Public Domain.
