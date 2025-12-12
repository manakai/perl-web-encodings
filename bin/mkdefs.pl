use strict;
use warnings;
use JSON::PS;
use Data::Dumper;

local $/ = undef;
my $data = json_bytes2perl (scalar <>); 
$data->{encodings}->{"x-user-defined"}->{single_byte} = 1; 
$data->{names} = ["utf-8", (grep { not $_ eq "utf-8" and not $_ eq "replacement" } sort { $a cmp $b } keys %{$data->{encodings}}), "replacement"];
for my $d (values %{$data->{encodings}}) {
  delete $d->{url};
  delete $d->{suikawiki};
  for (values %{$d->{labels}}) {
    delete $_->{url};
  }
}

$Data::Dumper::Sortkeys = 1; 
$Data::Dumper::Useqq = 1; 
my $pm = Dumper $data; 
$pm =~ s/VAR1/Web::Encoding::_Defs/; 
print "$pm\n";

## License: Public Domain.
