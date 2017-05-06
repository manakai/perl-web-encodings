package Web::Encoding::Sniffer;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::Encoding;

## context
##   html         - HTML (navigate)
##   responsehtml - HTML (responseXML)
##   xml          - XML (navigate, responseXML, responseText)
##   css          - CSS
##   text         - text (navigate)
##   responsetext - non-XML (responseText)
##   classicscript - <script src> with type "classic"
sub new_from_context ($$) {
  return bless {
    context => $_[1],
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

## get an attribute
## <https://www.whatwg.org/specs/web-apps/current-work/#concept-get-attributes-when-sniffing>.
sub _get_attr ($) {
  # 1.
  $_[0] =~ /\G[\x09\x0A\x0C\x0D\x20\x2F]+/gc;

  # 2.
  if ($_[0] =~ /\G>/gc) {
    pos ($_[0])--;
    return undef;
  }
  
  # 3.
  my $attr = {name => '', value => ''};

  # 4.-5.
  if ($_[0] =~ m{\G([^\x09\x0A\x0C\x0D\x20/>][^\x09\x0A\x0C\x0D\x20/>=]*)}gc) {
    $attr->{name} .= $1;
    $attr->{name} =~ tr/A-Z/a-z/;
  }
  return undef if $_[0] =~ m{\G\z}gc;
  return $attr if $_[0] =~ m{\G(?=[/>])}gc;

  # 6.
  $_[0] =~ m{\G[\x09\x0A\x0C\x0D\x20]+}gc;

  # 7.-8.
  return $attr unless $_[0] =~ m{\G=}gc;

  # 9.
  $_[0] =~ m{\G[\x09\x0A\x0C\x0D\x20]+}gc;

  # 10.-12.
  if ($_[0] =~ m{\G\x22([^\x22]*)\x22}gc) {
    $attr->{value} .= $1;
    $attr->{value} =~ tr/A-Z/a-z/;
  } elsif ($_[0] =~ m{\G\x27([^\x27]*)\x27}gc) {
    $attr->{value} .= $1;
    $attr->{value} =~ tr/A-Z/a-z/;
  } elsif ($_[0] =~ m{\G([^\x09\x0A\x0C\x0D\x20>]+)}gc) {
    $attr->{value} .= $1;
    $attr->{value} =~ tr/A-Z/a-z/;
  }
  return undef if $_[0] =~ m{\G\z}gc;
  return $attr;
} # _get_attr

## <https://github.com/whatwg/html/pull/1752/files> as of Oct 2016
sub _prescan_xml ($) {
  if ($_[0] =~ m{^\x3C\x3F\x78\x6D}) { # <?xm
    if ($_[0] =~ m{^
      \x3C\x3F\x78\x6D\x6C             # <?xml
      (?>[^\x3E]*?                     #    more restrictive than the spec
      \x65\x6E\x63\x6F\x64\x69\x6E\x67 # encoding
      )
      [\x00-\x20]* \x3D                # =
      [\x00-\x20]*                     #    not in the spec
      (?:                              #    more restrictive than the spec
        \x22                           # "
        ([^\x22\x3E]*)
        \x22
      |
        \x27                           # '
        ([^\x27\x3E]*)
        \x27
      )
      [^\x3E]*                         #    more restrictive than the spec
      \x3E                             # >
    }x) {
      return fixup_html_meta_encoding_name encoding_label_to_name ($1 || $2);
    } else {
      return undef;
    }
  } elsif ($_[0] =~ m{^\x3C\x00\x3F\x00\x78\x00}) {
    return 'utf-16le';
  } elsif ($_[0] =~ m{^\x00\x3C\x00\x3F\x00\x78}) {
    return 'utf-16be';
  } else {
    return undef;
  }
} # _prescan_xml

## prescan a byte stream to determine its encoding
## <https://www.whatwg.org/specs/web-apps/current-work/#prescan-a-byte-stream-to-determine-its-encoding>.
sub _prescan_byte_stream ($) {
  my $xml_result = _prescan_xml $_[0];
  return $xml_result if defined $xml_result;

  # 1.
  (pos $_[0]) = 0;

  # 2.
  LOOP: {
    $_[0] =~ /\G<!--+>/gc;
    $_[0] =~ /\G<!--.*?-->/gcs;
    if ($_[0] =~ /\G<[Mm][Ee][Tt][Aa](?=[\x09\x0A\x0C\x0D\x20\x2F])/gc) {
      # 1.
      #

      # 2.-5.
      my $attr_list = {};
      my $got_pragma = 0;
      my $need_pragma = undef;
      my $charset;

      # 6.
      ATTRS: {
        my $attr = _get_attr ($_[0]) or last ATTRS;

        # 7.
        redo ATTRS if $attr_list->{$attr->{name}};
        
        # 8.
        $attr_list->{$attr->{name}} = $attr;

        # 9.
        if ($attr->{name} eq 'http-equiv') {
          $got_pragma = 1 if $attr->{value} eq 'content-type';
        } elsif ($attr->{name} eq 'content') {
          ## algorithm for extracting a character encoding from a
          ## |meta| element
          ## <https://www.whatwg.org/specs/web-apps/current-work/#algorithm-for-extracting-a-character-encoding-from-a-meta-element>.
          if (not defined $charset and
              $attr->{value} =~ /[Cc][Hh][Aa][Rr][Ss][Ee][Tt]
                                 [\x09\x0A\x0C\x0D\x20]*=
                                 [\x09\x0A\x0C\x0D\x20]*(?>"([^"]*)"|'([^']*)'|
                                 ([^"'\x09\x0A\x0C\x0D\x20]
                                  [^\x09\x0A\x0C\x0D\x20\x3B]*))/x) {
            $charset = encoding_label_to_name
                (defined $1 ? $1 : defined $2 ? $2 : $3);
            $need_pragma = 1;
          }
        } elsif ($attr->{name} eq 'charset') {
          $charset = encoding_label_to_name $attr->{value};
          $need_pragma = 0;
        }

        # 10.
        return undef if pos $_[0] >= length $_[0];
        redo ATTRS;
      } # ATTRS

      # 11. Processing, 12.
      if (not defined $need_pragma or
          ($need_pragma and not $got_pragma)) {
        #
      } elsif (defined $charset) {
        # 13.-14.
        $charset = fixup_html_meta_encoding_name $charset;

        # 15.-16.
        return $charset if defined $charset;
      }
    } elsif ($_[0] =~ m{\G</?[A-Za-z][^\x09\x0A\x0C\x0D\x20>]*}gc) {
      {
        _get_attr ($_[0]) and redo;
      }
    } elsif ($_[0] =~ m{\G<[!/?][^>]*}gc) {
      #
    }

    # 3. Next byte
    $_[0] =~ /\G[^<]+/gc || $_[0] =~ /\G</gc;
    return undef if pos $_[0] >= length $_[0];
    redo LOOP;
  } # LOOP
} # _prescan_byte_stream

## override  - override encoding label (valid or invalid) or undef
## transport - transport encoding label (valid or invalid) or undef
## reference - reference's encoding label (valid or invalid) or undef
## embed     - embedding context's encoding or undef
## locale    - user's locale's language tag in lowercase or undef
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

    ## Prescan xml
    if ($self->{context} eq 'html' or
        $self->{context} eq 'responsehtml' or
        $self->{context} eq 'xml') {
      my $name = _prescan_xml $_[1];
      if (defined $name) {
        $self->{encoding} = $name;
        if ($self->{context} eq 'responsehtml') {
          $self->{confident} = 1;
        } else {
          delete $self->{confident};
        }
        $self->{source} = 'xml';
        return;
      }
    }

    ## Prescan html
    if ($self->{context} eq 'html' or
        $self->{context} eq 'responsehtml') {
      my $name = _prescan_byte_stream $_[1];
      if (defined $name) {
        $self->{encoding} = $name;
        if ($self->{context} eq 'responsehtml') {
          $self->{confident} = 1;
        } else {
          delete $self->{confident};
        }
        $self->{source} = 'html';
        return;
      }
    }

    if ($self->{context} eq 'css') {
      ## <https://drafts.csswg.org/css-syntax/#determine-the-fallback-encoding>
      if ($_[1] =~ /\A\x40\x63\x68\x61\x72\x73\x65\x74\x20\x22([\x00-\x21\x23-\x7F]*)\x22\x3B/) {
        my $name = fixup_html_meta_encoding_name encoding_label_to_name $1;
        if (defined $name) {
          $self->{encoding} = $name;
          delete $self->{confident}; # in fact, irrelevant
          $self->{source} = 'css';
          return;
        }
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

    if ($self->{context} eq 'html' or $self->{context} eq 'text') {
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
      } else {
        $self->{encoding} = 'windows-1252';
        delete $self->{confident};
        $self->{source} = 'locale';
        return;
      }
    } # context = html | text
  }

  ## The encoding
  $self->{encoding} = 'utf-8';
  if ($self->{context} eq 'responsehtml') {
    $self->{confident} = 1;
  } else {
    delete $self->{confident};
  }
  $self->{source} = 'default';
  return;
} # detect

1;

=head1 LICENSE

Copyright 2007-2017 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
