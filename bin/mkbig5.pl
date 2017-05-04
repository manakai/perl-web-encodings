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
  my $lead = int ($pointer / 157) + 0x81;
  my $trail = $pointer % 157;
  my $offset = $trail < 0x3F ? 0x40 : 0x62;
  return pack 'CC', $lead, $trail + $offset;
} # b

sub bytes ($) {
  my $s = shift;
  $s =~ s/(.)/sprintf '\\x%02X', ord $1/ges;
  return $s;
} # bytes

for my $name (qw(big5)) {
  $Decoder->{$name} = [map { defined $_ ? chr $_ : undef } @{$json->{$name}}];

  ## <https://encoding.spec.whatwg.org/#big5-decoder>
  $Decoder->{$name}->[1133] = "\x{00CA}\x{0304}";
  $Decoder->{$name}->[1135] = "\x{00CA}\x{030C}";
  $Decoder->{$name}->[1164] = "\x{00EA}\x{0304}";
  $Decoder->{$name}->[1166] = "\x{00EA}\x{030C}";

  ## <https://encoding.spec.whatwg.org/#index-big5-pointer>
  my $map = {};
  my $pmap = {};
  for (0..$#{$json->{$name}}) {
    next if $_ < (0xA1 - 0x81) * 157;

    my $v = $json->{$name}->[$_];
    if (defined $v) {
      if (defined $map->{$v}) {
        #warn sprintf "Duplicate: U+%04X = (%s, %s)\n",
        #    $v,
        #    (bytes $map->{$v}),
        #    (bytes b $_);
        if ($v == 0x2550 or
            $v == 0x255E or
            $v == 0x2561 or
            $v == 0x256A or
            $v == 0x5341 or
            $v == 0x5345) {
          $Decoder->{noncanon}->{$pmap->{$v}} = 1;
          $map->{$v} = b $_;
          $pmap->{$v} = $_;
        } else {
          $Decoder->{noncanon}->{$_} = 1;
        }
      } else {
        $map->{$v} = b $_;
        $pmap->{$v} = $_;
      }
    }
  }
  $Encoder->{bmp} = join '', map {
    $map->{$_} // "\x00\x00";
  } 0x0000..0xFFFF;
  for (keys %$map) {
    next if $_ < 0x10000;
    $Encoder->{nonbmp}->{$_} = $map->{$_};
  }
}

$Data::Dumper::Sortkeys = 1;
print '$Web::Encoding::_Big5::EncodeBMP = ';
print Dumper $Encoder->{bmp};
print '$Web::Encoding::_Big5::EncodeNonBMP = ';
print Dumper $Encoder->{nonbmp};
print '$Web::Encoding::_Big5::DecodeIndex = ';
print Dumper $Decoder->{big5};
print '$Web::Encoding::_Big5::NonCanonical = ';
print Dumper $Decoder->{noncanon};
print "1;";

## License: Public Domain.
