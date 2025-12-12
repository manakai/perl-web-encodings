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
my $Decoder2 = {};

for my $name (keys %$json) {
  next unless @{$json->{$name}} == 128 or @{$json->{$name}} == 256;
  my $offset = @{$json->{$name}} == 128 ? 0x80 : 0x00;

  for (@{$json->{$name}}) {
    if (defined $_ and $_ == 0xFFFD) {
      die "$name has mapping from a byte to U+FFFD";
    }
  }
  if (grep { ref $_ } @{$json->{$name}}) {
    $Decoder2->{$name} = [map { defined $_ ? ref $_ ? (join '', map { chr $_ } @$_) : chr $_ : "\x{FFFD}" } @{$json->{$name}}];
  } else {
    $Decoder->{$name} = join '', map { defined $_ ? chr $_ : "\x{FFFD}" } @{$json->{$name}};
  }

  my $map = {};
  for (0..$#{$json->{$name}}) {
    my $v = $json->{$name}->[$_];
    if (defined $v and not ref $v) {
      $map->{chr $v} //= pack 'C', $offset + $_;
    }
  }
  $Encoder->{$name} = $map;
}

$Data::Dumper::Sortkeys = 1;
print '$Web::Encoding::_Single::Encoder = ';
print Dumper $Encoder;
print '$Web::Encoding::_Single::Decoder = ';
print Dumper $Decoder;
print '$Web::Encoding::_Single::Decoder2 = ';
print Dumper $Decoder2;
print "1;";

## License: Public Domain.
