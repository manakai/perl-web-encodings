use strict;
use warnings;
use Path::Tiny;
use Web::Encoding;
use Time::HiRes qw(time);
use JSON::PS;

my $RootPath = path (__FILE__)->parent->parent;
my $DataPath = $RootPath->child ('local/bench.json');
my $ViewPath = $RootPath->child ('local/bench.html');
my $Data = {};

if (-f $DataPath) {
  $Data = json_bytes2perl $DataPath->slurp;
}

my $name = shift // '';
my $time = time;

my $TestDataPath = $RootPath->child ('t_deps/tests/largedata');
for my $fname (qw(
  complete.html
  htmlspec.html
  era-defs.json
  mimpou.txt
  teams.json
)) {
  my $path = $TestDataPath->child ($fname);
  my $bytes = $path->slurp;
  my $t;
  if ($name eq 'decode') {
    my @byte = map { $bytes } 1..10;
    my $start_time = time;
    for (1..10) {
      utf8::decode $byte[$_-1];
    }
    my $end_time = time;
    $t = ($end_time - $start_time) / 10;
  } elsif ($name =~ /nonascii/) {
    my $start_time = time;
    for (1..10) {
      if ($bytes =~ /[^\x00-\x7F]/) {
        decode_web_utf8 $bytes;
      }
    }
    my $end_time = time;
    $t = ($end_time - $start_time) / 10;
  } else {
    my $start_time = time;
    for (1..10) {
      decode_web_utf8 $bytes;
    }
    my $end_time = time;
    $t = ($end_time - $start_time) / 10;
  }
  $Data->{$name}->{$time}->{$fname} = $t;
}

$DataPath->spew (perl2json_bytes_for_record $Data);

my $fnames = {};
for (values %$Data) {
  for (values %$_) {
    for (keys %$_) {
      $fnames->{$_} = 1;
    }
  }
}
my @fname = sort { $a cmp $b } keys %$fnames;

my $html = sprintf q{
  <!DOCTYPE HTML>
  <Title>Benchmark</title>
  <style>
    td {
      text-align: right;
    }
  </style>
  <table>
    <thead>
      <tr>
        <th rowspan=2>Name
        <th rowspan=2>Date
        <th colspan=%d>Elapsed
      <tr>
        %s
    <tbody>
}, 0+@fname, join '', map { "<th>$_" } @fname;

for my $name (sort { $a cmp $b } keys %$Data) {
  for my $time (sort { $a <=> $b } keys %{$Data->{$name}}) {
    $html .= sprintf q{<tr><th>%s<th>%s},
        $name, scalar gmtime $time;
    for my $field (@fname) {
      my $v = $Data->{$name}->{$time}->{$field};
      if (defined $v) {
        $html .= sprintf q{<td>%.3f ms}, $v * 1000;
      } else {
        $html .= q{<td>};
      }
    }
  }
}

$html .= sprintf q{
  </table>
};

$ViewPath->spew_utf8 ($html);
