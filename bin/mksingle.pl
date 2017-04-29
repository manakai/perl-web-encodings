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

for my $name (keys %$json) {
  next unless @{$json->{$name}} == 128;

  for (@{$json->{$name}}) {
    if (defined $_ and $_ == 0xFFFD) {
      die "$name has mapping from a byte to U+FFFD";
    }
  }
  #$Decoder->{$name} = [map { defined $_ ? chr $_ : "\x{FFFD}" } @{$json->{$name}}];
  $Decoder->{$name} = join '', map { defined $_ ? chr $_ : "\x{FFFD}" } @{$json->{$name}};

  my $map = {};
  for (0..$#{$json->{$name}}) {
    my $v = $json->{$name}->[$_];
    if (defined $v) {
      $map->{chr $v} = pack 'C', 0x80 + $_;
    }
  }
  $Encoder->{$name} = $map;
}

$Data::Dumper::Sortkeys = 1;
print '$Web::Encoding::_Single::Encoder = ';
print Dumper $Encoder;
print '$Web::Encoding::_Single::Decoder = ';
print Dumper $Decoder;
print "1;";

## License: Public Domain.
