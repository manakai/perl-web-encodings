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

sub be ($) {
  my $pointer = shift;
  my $lead = int ($pointer / 94);
  my $trail = $pointer % 94;
  return pack 'CC', $lead + 0xA1, $trail + 0xA1;
} # be

sub bytes ($) {
  my $s = shift;
  $s =~ s/(.)/sprintf '\\x%02X', ord $1/ges;
  return $s;
} # bytes

for my $name (qw(jis0208)) {
  $Decoder->{$name} = [map { defined $_ ? chr $_ : undef } @{$json->{$name}}];

  ## <https://encoding.spec.whatwg.org/#index-shift_jis-pointer>
  my $map = {};
  my $mape = {};
  for (0..$#{$json->{$name}}) {
    my $v = $json->{$name}->[$_];

    unless (8272 <= $_ and $_ <= 8835) {
      if (defined $v) {
        if (defined $map->{$v}) {
          #warn sprintf "U+%04X %s %s\n", $v, bytes $map->{$v}, bytes b $_;
          $Decoder->{noncanons}->{$_} = 1;
        }
        $map->{$v} //= b $_;
      }
    }

    if (defined $v) {
      if (defined $mape->{$v} and $_ < 8836) {
        #warn sprintf "U+%04X %s %s\n", $v, bytes $mape->{$v}, bytes be $_;
        $Decoder->{noncanone}->{$_} = 1;
      }
      $mape->{$v} //= be $_;
    }
  }
  $map->{0x0080} = "\x00\x80";
  $map->{0x00A5} = "\x00\x5C";
  $mape->{0x00A5} = "\x00\x5C";
  $map->{0x203E} = "\x00\x7E";
  $mape->{0x203E} = "\x00\x7E";
  $map->{$_} = pack 'CC', 0, $_ - 0xFF61 + 0xA1 for 0xFF61 .. 0xFF9F;
  $mape->{$_} = pack 'CC', 0x8E, $_ - 0xFF61 + 0xA1 for 0xFF61 .. 0xFF9F;
  $map->{0x2212} = $map->{0xFF0D};
  $mape->{0x2212} = $mape->{0xFF0D};
  $Encoder->{bmpsjis} = join '', map {
    $map->{$_} // "\x00\x00";
  } 0x0000..0xFFFF;
  $Encoder->{bmpeuc} = join '', map {
    $mape->{$_} // "\x00\x00";
  } 0x0000..0xFFFF;
  for (keys %$map) {
    next if $_ < 0x10000;
    die sprintf "U+%04X", $_;
  }
  for (keys %$mape) {
    next if $_ < 0x10000;
    die sprintf "U+%04X", $_;
  }
}

for my $name (qw(jis0212)) {
  $Decoder->{$name} = [map { defined $_ ? chr $_ : undef } @{$json->{$name}}];
}

$Data::Dumper::Sortkeys = 1;
print '$Web::Encoding::_JIS::EncodeBMPSJIS = ';
print Dumper $Encoder->{bmpsjis};
print '$Web::Encoding::_JIS::EncodeBMPEUC = ';
print Dumper $Encoder->{bmpeuc};
print '$Web::Encoding::_JIS::DecodeIndex = ';
print Dumper $Decoder->{jis0208};
print '$Web::Encoding::_JIS::DecodeIndex0212 = ';
print Dumper $Decoder->{jis0212};
print '$Web::Encoding::_JIS::NonCanonicalSJIS = ';
print Dumper $Decoder->{noncanons};
print '$Web::Encoding::_JIS::NonCanonicalEUC = ';
print Dumper $Decoder->{noncanone};
print "1;";

## License: Public Domain.
