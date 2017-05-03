package Web::Encoding::Decoder;
use strict;
use warnings;
our $VERSION = '1.0';
use Carp;
use Web::Encoding;

push our @CARP_NOT, qw(Web::Encoding);

sub new_from_encoding_key ($$) {
  return bless {
    key => $_[1],
    states => {},
  }, $_[0];
} # new_from_encoding_key

sub ignore_bom ($;$) {
  if (@_ > 1) {
    $_[0]->{ignore_bom} = $_[1];
  }
  return $_[0]->{ignore_bom};
} # ignore_bom

sub fatal ($;$) {
  if (@_ > 1) {
    $_[0]->{fatal} = 1;
  }
  return $_[0]->{fatal};
} # fatal

## Specification: Encoding Standard and
## <https://wiki.suikawiki.org/n/Encoding%20Validation>.
sub onerror ($;$) {
  if (@_ > 1) {
    $_[0]->{onerror} = $_[1];
  }
  return $_[0]->{onerror} || sub { };
} # onerror

sub _onerror ($) {
  my $onerror = $_[0]->{onerror};
  return $_[0]->{fatal} ? sub {
    my %args = @_;
    my $fatal = delete $args{fatal};
    $onerror->(%args);
    die "Input has invalid bytes" if $fatal;
  } : $onerror || sub { };
} # _onerror

sub used_encoding_key ($) {
  return $_[0]->{key};
} # used_encoding_key

sub _u16 ($$$$$) {
  #$states, $u, \@s, $onerror, $index;
  if ($_[1] < 0xD800 or 0xDFFF < $_[1]) {
    if (defined $_[0]->{lead_surrogate}) {
      $_[3]->(type => 'utf-16:lone high surrogate', level => 'm', fatal => 1,
              index => $_[0]->{index} + $_[4] - 2,
              text => sprintf '0x%04X', $_[0]->{lead_surrogate});
      push @{$_[2]}, "\x{FFFD}";
      delete $_[0]->{lead_surrogate};
    }
    push @{$_[2]}, chr $_[1];
  } elsif ($_[1] <= 0xDBFF) { # [U+D800, U+DBFF]
    if (defined $_[0]->{lead_surrogate}) {
      $_[3]->(type => 'utf-16:lone high surrogate', level => 'm', fatal => 1,
              index => $_[0]->{index} + $_[4] - 2,
              text => sprintf '0x%04X', $_[0]->{lead_surrogate});
      push @{$_[2]}, "\x{FFFD}";
      delete $_[0]->{lead_surrogate};
    }
    $_[0]->{lead_surrogate} = $_[1];
  } else { # [U+DC00, U+DFFF]
    if (defined $_[0]->{lead_surrogate}) {
      push @{$_[2]}, chr (0x10000
                          + ((delete ($_[0]->{lead_surrogate}) - 0xD800) << 10)
                          + $_[1] - 0xDC00);
    } else {
      $_[3]->(type => 'utf-16:lone low surrogate', level => 'm', fatal => 1,
              index => $_[0]->{index} + $_[4],
              text => sprintf '0x%04X', $_[1]);
      push @{$_[2]}, "\x{FFFD}";
    }
  }
} # _u16

sub _decode_16 ($$$$$) {
  my $states = $_[0];
  #my $onerror = $_[1];
  #my $is_last = $_[3];
  #my $endian = $_[4]

  my $offset = 0;
  $states->{index} = 0 unless defined $states->{index};

  my @s;
  my $len = length $_[2];
  if (defined $states->{lead_byte}) {
    if ($len) {
      my $lead = unpack 'C', delete $states->{lead_byte};
      my $sec = unpack 'C', substr $_[2], 0, 1;
      if ($_[4] eq 'n') {
        _u16 $states, $lead * 0x100 + $sec, \@s, $_[1], -1;
      } else {
        _u16 $states, $sec * 0x100 + $lead, \@s, $_[1], -1;
      }
      $offset++;
    } else { # empty
      if ($_[3]) { # $is_last
        $_[1]->(type => 'utf-16:lone byte', level => 'm', fatal => 1,
                index => $states->{index} - 1, value => $states->{lead_byte});
        push @s, "\x{FFFD}";
        delete $states->{lead_surrogate};
      }
    }
  }
  my $Length = ($len - $offset) / 2;
  my $length = int $Length;
  my $i = 0;
  while ($i < $length) {
    _u16 $states, (unpack $_[4], substr $_[2], $offset + $i * 2, 2), \@s, $_[1], $offset + $i * 2;
    $i++;
  }
  if (defined $states->{lead_surrogate} and $_[3]) { # $is_last
    $_[1]->(type => 'utf-16:lone high surrogate', level => 'm', fatal => 1,
            index => $states->{index} + $len - 2,
            text => sprintf '0x%04X', $_[0]->{lead_surrogate});
    push @s, "\x{FFFD}";
  } elsif ($length != $Length) {
    if ($_[3]) { # $is_last
      $_[1]->(type => 'utf-16:lone byte', level => 'm', fatal => 1,
              index => $states->{index} + $len - 1,
              value => substr $_[2], -1);
      push @s, "\x{FFFD}";
    } else {
      $states->{lead_byte} = substr $_[2], -1;
    }
  }

  $states->{index} += $len;

  ## @s can't contain an empty string for the convenience of later BOM
  ## stripping.
  return \@s;
} # _decode_16

sub bytes ($$) {
  my $key = $_[0]->{key};
  if (not defined $_[1]) {
    carp "Use of uninitialized value an argument";
    return [];
  } elsif (utf8::is_utf8 $_[1]) {
    croak "Cannot decode string with wide characters";
  } elsif ($_[1] eq '') {
    return [];
  }

  if ($key eq 'utf-8') {
    $_[0]->{states}->{index} = 0 unless defined $_[0]->{states}->{index};
    my $offset = $_[0]->{states}->{index}
               + (defined $_[0]->{states}->{lead} ? -length $_[0]->{states}->{lead} : 0);
    my $decoded = [Web::Encoding::_decode8 $_[0]->{states}, $_[1], 0, $offset, $_[0]->_onerror];
    $_[0]->{states}->{index} += length $_[1];
    if ($_[0]->{ignore_bom} and not $_[0]->{states}->{bom_seen}) {
      if (@$decoded and length $decoded->[0]) {
        if ($decoded->[0] =~ s/^\x{FEFF}//) {
          $_[0]->_onerror->(type => 'bom', level => 's', index => 0);
        }
        $_[0]->{states}->{bom_seen} = 1;
      }
    }
    return $decoded;
  } elsif (Web::Encoding::_is_single $key) {
    require Web::Encoding::_Single;
    my $s = $_[1]; # string copy!
    my $Map = \($Web::Encoding::_Single::Decoder->{$_[0]->{key}});
    #$s =~ s{([\x80-\xFF])}{$Map->[-0x80 + ord $1]}g;
    $s =~ s{([\x80-\xFF])}{substr $$Map, -0x80 + ord $1, 1}ge;
    #return undef if $s =~ /\x{FFFD}/ and error mode is fatal;
    return [$s];
  } elsif ($key eq 'utf-16be') {
    my $decoded = _decode_16 $_[0]->{states}, $_[0]->_onerror, $_[1], 0, 'n';
    if ($_[0]->{ignore_bom} and not $_[0]->{states}->{bom_seen}) {
      if (@$decoded) {
        if ($decoded->[0] =~ s/^\x{FEFF}//) {
          $_[0]->_onerror->(type => 'bom', level => 's', index => 0);
        }
        $_[0]->{states}->{bom_seen} = 1;
      }
    }
    return $decoded;
  } elsif ($key eq 'utf-16le') {
    my $decoded = _decode_16 $_[0]->{states}, $_[0]->_onerror, $_[1], 0, 'v';
    if ($_[0]->{ignore_bom} and not $_[0]->{states}->{bom_seen}) {
      if (@$decoded) {
        if ($decoded->[0] =~ s/^\x{FEFF}//) {
          $_[0]->_onerror->(type => 'bom', level => 's', index => 0);
        }
        $_[0]->{states}->{bom_seen} = 1;
      }
    }
    return $decoded;
  } elsif ($key eq 'replacement') {
    if (not $_[0]->{states}->{written}) {
      $_[0]->{states}->{written} = 1;
      return ["\x{FFFD}"];
    } else {
      return [];
    }
  } else {
    require Encode;
    return [Encode::decode ($key, $_[1])]; # XXX
  }
} # bytes

sub eof ($) {
  my $key = $_[0]->{key};
  if ($key eq 'utf-8') {
    $_[0]->{states}->{index} = 0 unless defined $_[0]->{states}->{index};
    my $offset = $_[0]->{states}->{index} + (defined $_[0]->{states}->{lead} ? -length $_[0]->{states}->{lead} : 0);
    ## Returns zero or more U+FFFD.
    return [Web::Encoding::_decode8 $_[0]->{states}, '', 1, $offset, $_[0]->_onerror];
  } elsif ($key eq 'utf-16be') {
    my $decoded = _decode_16 $_[0]->{states}, $_[0]->_onerror, '', 1, 'n';
    if ($_[0]->{ignore_bom} and not $_[0]->{states}->{bom_seen}) {
      if (@$decoded) {
        if ($decoded->[0] =~ s/^\x{FEFF}//) {
          $_[0]->_onerror->(type => 'bom', level => 's', index => 0);
        }
        $_[0]->{states}->{bom_seen} = 1;
      }
    }
    return $decoded;
  } elsif ($key eq 'utf-16le') {
    my $decoded = _decode_16 $_[0]->{states}, $_[0]->_onerror, '', 1, 'v';
    if ($_[0]->{ignore_bom} and not $_[0]->{states}->{bom_seen}) {
      if (@$decoded) {
        if ($decoded->[0] =~ s/^\x{FEFF}//) {
          $_[0]->_onerror->(type => 'bom', level => 's', index => 0);
        }
        $_[0]->{states}->{bom_seen} = 1;
      }
    }
    return $decoded;
  } else {
    return [];
  }
} # eof

1;

=head1 LICENSE

Copyright 2011-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
