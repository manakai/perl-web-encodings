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

sub bom_sniffing ($;$) {
  if (@_ > 1) {
    $_[0]->{bom_sniffing} = $_[1];
  }
  return $_[0]->{bom_sniffing};
} # bom_sniffing

sub used_encoding_key ($) {
  return $_[0]->{key};
} # used_encoding_key

sub _u16 ($$$) {
  #$states, $u, \@s;
  if ($_[1] < 0xD800 or 0xDFFF < $_[1]) {
    if (defined $_[0]->{lead_surrogate}) {
      push @{$_[2]}, "\x{FFFD}"; # or error
    }
    push @{$_[2]}, chr $_[1];
  } elsif ($_[1] <= 0xDBFF) { # [U+D800, U+DBFF]
    if (defined $_[0]->{lead_surrogate}) {
      push @{$_[2]}, "\x{FFFD}"; # or error
    }
    $_[0]->{lead_surrogate} = $_[1];
  } else { # [U+DC00, U+DFFF]
    if (defined $_[0]->{lead_surrogate}) {
      push @{$_[2]}, chr (0x10000
                          + ((delete ($_[0]->{lead_surrogate}) - 0xD800) << 10)
                          + $_[1] - 0xDC00);
    } else {
      push @{$_[2]}, "\x{FFFD}"; # or error
    }
  }
} # _u16

sub _decode_16 ($$$$$) {
  my $states = $_[0];
  my $offset = $_[1];
  #my $is_last = $_[3];
  #my $endian = $_[4]

  if (not defined $_[2]) {
    carp "Use of uninitialized value an argument";
    return '';
  } elsif (utf8::is_utf8 $_[2]) {
    croak "Cannot decode string with wide characters";
  }

  my @s;
  my $len = length $_[2];
  if (defined $states->{lead_byte}) {
    if ($len) {
      my $lead = unpack 'C', delete $states->{lead_byte};
      my $sec = unpack 'C', substr $_[2], 0, 1;
      if ($_[4] eq 'n') {
        _u16 $states, $lead * 0x100 + $sec, \@s;
      } else {
        _u16 $states, $sec * 0x100 + $lead, \@s;
      }
      $offset++;
    } else { # empty
      if ($_[3]) { # $is_last
        push @s, "\x{FFFD}"; # or error
        delete $states->{lead_surrogate};
      }
    }
  }
  my $Length = ($len - $offset) / 2;
  my $length = int $Length;
  my $i = 0;
  while ($i < $length) {
    _u16 $states, (unpack $_[4], substr $_[2], $offset + $i * 2, 2), \@s;
    $i++;
  }
  if (defined $states->{lead_surrogate} and $_[3]) { # $is_last
    push @s, "\x{FFFD}"; # or error
  } elsif ($length != $Length) {
    if ($_[3]) { # $is_last
      push @s, "\x{FFFD}"; # or error
    } else {
      $states->{lead_byte} = substr $_[2], -1;
    }
  }
  return join '', @s;
} # _decode_16

sub bytes ($$) {
  my $key = $_[0]->{key};
  if (not defined $_[1]) {
    carp "Use of uninitialized value an argument";
    return '';
  } elsif (utf8::is_utf8 $_[1]) {
    croak "Cannot decode string with wide characters";
  } elsif ($_[1] eq '') {
    return '';
  }

  my $prefix = '';
  my $offset = 0;
  if ($_[0]->{bom_sniffing} and not $_[0]->{states}->{bom_seen}) {
    if (delete $_[0]->{states}->{has_ff}) {
      if ($_[1] =~ /^\xFE/) {
        $_[0]->{key} = $key = 'utf-16le';
        $offset = 1;
        $_[0]->{states}->{bom_seen} = 1;
      } else {
        $prefix = "\xFF";
        $_[0]->{states}->{bom_seen} = 1;
      }
    } elsif (delete $_[0]->{states}->{has_fe}) {
      if ($_[1] =~ /^\xFF/) {
        $_[0]->{key} = $key = 'utf-16be';
        $offset = 1;
        $_[0]->{states}->{bom_seen} = 1;
      } else {
        $prefix = "\xFE";
        $_[0]->{states}->{bom_seen} = 1;
      }
    } else {
      if ($_[1] =~ /^\xEF\xBB\xBF/) {
        # XXX need to wait until an entire BOM is read
        $_[0]->{key} = $key = 'utf-8';
        $_[0]->{states}->{bom_seen} = 1;
      } elsif ($_[1] =~ /^\xFE\xFF/) {
        $_[0]->{key} = $key = 'utf-16be';
        $offset = 2;
        $_[0]->{states}->{bom_seen} = 1;
      } elsif ($_[1] =~ /^\xFF\xFE/) {
        $_[0]->{key} = $key = 'utf-16le';
        $offset = 2;
        $_[0]->{states}->{bom_seen} = 1;
      } elsif ($_[1] eq "\xFE") {
        $_[0]->{states}->{has_fe} = 1;
        return '';
      } elsif ($_[1] eq "\xFF") {
        $_[0]->{states}->{has_ff} = 1;
        return '';
      } else {
        $_[0]->{states}->{bom_seen} = 1;
      }
    }
  }
  if ($key eq 'utf-8') {
    # XXX this is not streamable
    if (length $prefix) { # \xFF or \xFE
      return "\x{FFFD}" . Web::Encoding::decode_web_utf8_no_bom $_[1];
    } elsif ($_[0]->{bom_sniffing} or $_[0]->{ignore_bom}) {
      return Web::Encoding::decode_web_utf8 $_[1];
    } else {
      return Web::Encoding::decode_web_utf8_no_bom $_[1];
    }
  } elsif (Web::Encoding::_is_single $key) {
    require Web::Encoding::_Single;
    my $s = $prefix . $_[1]; # string copy!
    my $Map = \($Web::Encoding::_Single::Decoder->{$_[0]->{key}});
    #$s =~ s{([\x80-\xFF])}{$Map->[-0x80 + ord $1]}g;
    $s =~ s{([\x80-\xFF])}{substr $$Map, -0x80 + ord $1, 1}ge;
    #return undef if $s =~ /\x{FFFD}/ and error mode is fatal;
    return $s;
  } elsif ($key eq 'utf-16be') {
    if ($_[0]->{ignore_bom} and not $_[0]->{states}->{bom_seen}) {
      if (delete $_[0]->{states}->{has_fe}) {
        if ($_[1] =~ /^\xFF/) {
          $offset = 1;
        } else {
          _decode_16 $_[0]->{states}, $offset, "\xFE", 0, 'n'; # returns empty
        }
        $_[0]->{states}->{bom_seen} = 1;
      } else {
        if ($_[1] =~ /^\xFE\xFF/) {
          $offset = 2;
          $_[0]->{states}->{bom_seen} = 1;
        } elsif ($_[1] eq "\xFE") {
          $_[0]->{states}->{has_fe} = 1;
          return '';
        } else {
          $_[0]->{states}->{bom_seen} = 1;
        }
      }
    } elsif (length $prefix) { # \xFF or \xFE
      _decode_16 $_[0]->{states}, $offset, $prefix, 0, 'n'; # returns empty
    }
    return _decode_16 $_[0]->{states}, $offset, $_[1], 0, 'n';
  } elsif ($key eq 'utf-16le') {
    if ($_[0]->{ignore_bom} and not $_[0]->{states}->{bom_seen}) {
      if (delete $_[0]->{states}->{has_ff}) {
        if ($_[1] =~ /^\xFE/) {
          $offset = 1;
        } else {
          _decode_16 $_[0]->{states}, $offset, "\xFF", 0, 'v'; # returns empty
        }
        $_[0]->{states}->{bom_seen} = 1;
      } else {
        if ($_[1] =~ /^\xFF\xFE/) {
          $offset = 2;
          $_[0]->{states}->{bom_seen} = 1;
        } elsif ($_[1] eq "\xFF") {
          $_[0]->{states}->{has_ff} = 1;
          return '';
        } else {
          $_[0]->{states}->{bom_seen} = 1;
        }
      }
    } elsif (length $prefix) { # \xFF or \xFE
      _decode_16 $_[0]->{states}, $offset, $prefix, 0, 'v'; # returns empty
    }
    return _decode_16 $_[0]->{states}, $offset, $_[1], 0, 'v';
  } elsif ($key eq 'replacement') {
    if (not $_[0]->{states}->{written}) {
      $_[0]->{states}->{written} = 1;
      return "\x{FFFD}";
    } else {
      return '';
    }
  } else {
    require Encode;
    return Encode::decode ($key, $prefix . $_[1]); # XXX
  }
} # bytes

sub eof ($) {
  my $key = $_[0]->{key};
  if ($key eq 'utf-8') {
    if ($_[0]->{states}->{has_ff} or $_[0]->{states}->{has_fe}) {
      return "\x{FFFD}";
    } else {
      return '';
    }
  } elsif (Web::Encoding::_is_single $key) {
    require Web::Encoding::_Single;
    my $prefix = '';
    $prefix = "\xFF" if $_[0]->{states}->{has_ff};
    $prefix = "\xFE" if $_[0]->{states}->{has_fe};
    my $Map = \($Web::Encoding::_Single::Decoder->{$_[0]->{key}});
    #$prefix =~ s{([\x80-\xFF])}{$Map->[-0x80 + ord $1]}g;
    $prefix =~ s{([\x80-\xFF])}{substr $$Map, -0x80 + ord $1, 1}ge;
    #return undef if $prefix =~ /\x{FFFD}/ and error mode is fatal;
    return $prefix;
  } elsif ($key eq 'utf-16be') {
    my $prefix = '';
    $prefix = "\xFF" if $_[0]->{states}->{has_ff};
    $prefix = "\xFE" if $_[0]->{states}->{has_fe};
    return _decode_16 $_[0]->{states}, 0, $prefix, 1, 'n';
  } elsif ($key eq 'utf-16le') {
    my $prefix = '';
    $prefix = "\xFF" if $_[0]->{states}->{has_ff};
    $prefix = "\xFE" if $_[0]->{states}->{has_fe};
    return _decode_16 $_[0]->{states}, 0, $prefix, 1, 'v';
  } elsif ($key eq 'replacement') {
    if (not $_[0]->{states}->{written} and
        ($_[0]->{states}->{has_ff} or $_[0]->{states}->{has_fe})) {
      $_[0]->{states}->{written} = 1;
      return "\x{FFFD}";
    } else {
      return '';
    }
  } else {
    my $prefix = '';
    $prefix = "\xFF" if $_[0]->{states}->{has_ff};
    $prefix = "\xFE" if $_[0]->{states}->{has_fe};
    require Encode;
    return Encode::decode ($key, $prefix); # XXX
  }
} # eof

1;

=head1 LICENSE

Copyright 2011-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
