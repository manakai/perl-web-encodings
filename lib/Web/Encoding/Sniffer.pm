package Web::Encoding::Sniffer;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::Encoding;

sub new_from_context ($$) {
  return bless {
    context => $_[1], # html responsehtml xml css responsetext classicscript
  }, $_[0];
} # new_from_context

sub confident ($) {
  return $_[0]->{confident};
} # confident

sub encoding ($) {
  return $_[0]->{encoding};
} # encoding

sub source ($) {
  return $_[0]->{source};
} # source

my $Prescanner = {};

## override  - override encoding label (valid or invalid) or undef
## transport - transport encoding label (valid or invalid) or undef
## reference - reference's encoding label (valid or invalid) or undef
## embed     - embedding context's encoding or undef
sub detect ($$;%) {
  my ($self, undef, %args) = @_;

  ## BOM
  if ($_[1] =~ /^\xFE\xFF/) {
    $self->{encoding} = 'utf-16be';
    $self->{confident} = 1;
    $self->{source} = 'bom';
    return;
  } elsif ($_[1] =~ /^\xFF\xFE/) {
    $self->{encoding} = 'utf-16le';
    $self->{confident} = 1;
    $self->{source} = 'bom';
    return;
  } elsif ($_[1] =~ /^\xEF\xBB\xBF/) {
    $self->{encoding} = 'utf-8';
    $self->{confident} = 1;
    $self->{source} = 'bom';
    return;
  }

  ## Override
  if (defined $args{override}) {
    my $name = encoding_label_to_name $args{override};
    if (defined $name) {
      $self->{encoding} = $name;
      $self->{confident} = 1;
      $self->{source} = 'override';
      return;
    }
  } else {

    ## HTTP charset
    if (defined $args{transport}) {
      my $name = encoding_label_to_name $args{transport};
      if (defined $name) {
        $self->{encoding} = $name;
        $self->{confident} = 1;
        $self->{source} = 'transport';
        return;
      }
    }

    ## Prescan
    my $prescanner = $Prescanner->{$self->{context}};
    if (defined $prescanner) {
      my $name = $prescanner->($_[1]);
      if (defined $name) {
        $self->{encoding} = $name;
        delete $self->{confident};
        $self->{source} = $self->{context};
        return;
      }
    }

    ## Environment - explicit
    if (defined $args{reference}) {
      my $name = encoding_label_to_name $args{reference};
      if (defined $name) {
        $self->{encoding} = $name;
        delete $self->{confident}; # in fact, irrelevant
        $self->{source} = 'reference';
        return;
      }
    }

    ## Environment - implicit
    if (defined $args{embed}) {
      $self->{encoding} = $args{embed};
      delete $self->{confident};
      $self->{source} = 'embed';
      return;
    }

    if ($self->{context} eq 'html') {
      ## UNIVCHARDET
      require Web::Encoding::UnivCharDet;
      my $det = Web::Encoding::UnivCharDet->new;
      # XXX locale-dependent configuration
      my $name = encoding_label_to_name $det->detect_byte_string ($_[1]);
      if ($name) {
        $self->{encoding} = $name;
        delete $self->{confident};
        $self->{source} = 'univchardet';
        return;
      }

      ## Locale
      if (defined $args{locale}) {
        my $name = encoding_label_to_name (
          locale_default_encoding_name $args{locale} ||
          locale_default_encoding_name [split /-/, $args{locale}, 2]->[0]
        );
        $name = 'windows-1252' if not defined $name;

        $self->{encoding} = $name;
        delete $self->{confident};
        $self->{source} = 'locale';
        return;
      }
    } # context
  }

  ## The encoding
  $self->{encoding} = 'utf-8';
  delete $self->{confident};
  $self->{source} = 'default';
  return;
} # detect

1;

=head1 LICENSE

Copyright 2007-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
