package Web::Encoding::Sniffer;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::Encoding;

## context
##   any          - any content (not implemented by browsers)
##   html         - HTML (navigate)
##   responsehtml - HTML (responseXML)
##   xml          - XML (navigate, responseXML, responseText)
##   css          - CSS external style sheet
##   text         - text (navigate)
##   responsetext - non-XML text (responseText)
##   classicscript - JavaScript (<script src> with type "classic")
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

sub font_encoding ($) {
  return $_[0]->{font_encoding};
} # font_encoding

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
      my $name = encoding_label_to_name ($1 || $2);
      if (defined $name) {
        $name = 'utf-8' if is_utf16_encoding_key $name;
      }
      return $name;
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
  delete $self->{font_encoding};

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
        $self->{context} eq 'xml' or
        $self->{context} eq 'any') {
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
        $self->{context} eq 'responsehtml' or
        $self->{context} eq 'any') {
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

    if ($self->{context} eq 'css' or
        $self->{context} eq 'any') {
      ## <https://drafts.csswg.org/css-syntax/#determine-the-fallback-encoding>
      if ($_[1] =~ /\A\x40\x63\x68\x61\x72\x73\x65\x74\x20\x22([\x00-\x21\x23-\x7F]*)\x22\x3B/) {
        my $name = encoding_label_to_name $1;
        if (defined $name) {
          $name = 'utf-8' if is_utf16_encoding_key $name;
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

    if ($self->{context} eq 'html' or
        $self->{context} eq 'text' or
        $self->{context} eq 'any') {
      ## Implementation-dependent detections
      {
        my $font_def;
        if ($self->{context} eq 'html' or $self->{context} eq 'any') {
          $font_def = $self->_detect_font ($_[1]); # or undef
        }
      
        ## UNIVCHARDET
        require Web::Encoding::UnivCharDet;
        my $det = Web::Encoding::UnivCharDet->new;
        # XXX locale-dependent configuration
        my $got = $det->detect_byte_string ($_[1]);
        my $name = encoding_label_to_name $got;
        if (defined $font_def) {
          if (not defined $name or not $name eq 'utf-8') {
            $self->{encoding} = 'windows-1252';
            delete $self->{confident};
            $self->{source} = 'font';
            $self->{font_encoding} = $font_def->{charset};
            return;
          }
        }
        if (defined $name and not $got eq 'ascii') {
          $self->{encoding} = $name;
          delete $self->{confident};
          $self->{source} = 'univchardet';
          return;
        }
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

# XXX
my $FontDefs = {
  "limon s1" => {charset => 'x-abc'},
  aniezhai => {charset => "x-aniezhai"},
  "adarshalipiexp" => {charset => "x-adarshalipiexp"},
  "adhawin-tamil" => {charset => "x-adhawin"},
  "adhawin-tamil regular" => {charset => "x-adhawin"},
  adhawintamil => {charset => "x-adhawin"},
  amudham2000 => {charset => "x-amudham2000"},
  "arial am" => {charset => "armscii-8"},
  "arial latarm" => {charset => "armscii-8"},
  au => {charset => "x-au"},
  bhaskar => {charset => "bhaskar"},
  chanakya => {charset => "x-chanakya"},
  eenadu => {charset => "x-eenadu"},
  epatrika => {charset => "x-epatrika"},
  rswwwnet => {charset => "georgian-academy"},
  trg1 => {charset => "georgian-academy"},
  "bpg classic dina" => {charset => "georgian-academy"},
  gopika => {charset => "x-gopika"},
  htchanakya => {charset => "htchanakya"},
  inaimathi => {charset => "x-inaimathi"},
  "inaimathi-1.8" => {charset => "x-inaimathi"},
  jagran => {charset => "jagran"},
  "ml-ttkarthika" => {charset => "x-karthika"},
  lokweb => {charset => "x-lokweb"},
  "lt-tm-barani" => {charset => "x-tam-lttmbarani"},
  "mac c swiss" => {charset => "x-mac-c-swiss"},
  "knw-ttnandi" => {charset => "x-nandi"},
  "utopic" => {charset => "x-utopic"},
  "unq_ttabid" => {charset => "x-pascii"},
  pothana => {charset => "x-pothana"},
  "sanskrit new" => {charset => "x-sanskrit-new"},
  "or-ttsarala" => {charset => "x-sarala"},
  "shree-mal-0502" => {charset => "x-shree-mal-0502"},
  "shree-tel-0900" => {charset => "x-shree-tel-0900"},
  shree802 => {charset => "x-shree802"},
  "subak-1" => {charset => "x-subak"},
  "dv-ttsurekh" => {charset => "x-surekh"},
  suritlr => {charset => "x-suritlr"},
  suritlk => {charset => "x-suritlk"},
  webtamil => {charset => "x-tam-webtamil"},
  "telugu lipi" => {charset => "x-telugu-lipi"},
  thoolika => {charset => "x-thoolika"},
  tikkana => {charset => "x-tikkana"},
  tboomis => {charset => "x-tam-tboomis"},
  tboomih => {charset => "x-tam-tboomis"},
  tboomi => {charset => "x-tam-tboomis"},
  tmnews => {charset => "x-tam-tmnews"},
  telugufont => {charset => "x-telugufont"},
  "tab-anna" => {charset => "tab"},
  "tab_inaimathi" => {charset => "tab"},
  "tab-lfs-kamban" => {charset => "tab"},
  'tam-kalaignar' => {charset => "tam"},
  "tsc_janani" => {charset => "tscii"},
  "thunaivantsc" => {charset => "tscii"},
  "tscsaiindira" => {charset => "tscii"},
  "tscsaisai" => {charset => "tscii"},
  "tscarial" => {charset => "tscii"},
  "tsccomic" => {charset => "tscii"},
  "tscmylai" => {charset => "tscii"},
  "tsctimes" => {charset => "tscii"},
  "tscverdana" => {charset => "tscii"},
  "tsc_avarangal" => {charset => "tscii"},
  "tsc_avarangalfxd" => {charset => "tscii"},
  "tsc_kannadaasan" => {charset => "tscii"},
  "tsc_paranar" => {charset => "tscii"},
  "tsc_thunaivan" => {charset => "tscii"},
  "tsc-sri" => {charset => "tscii"},
  tscu_inaimathi => {charset => "tscii"},
  inaimathitsc => {charset => "tscii"},
  tneritsc => {charset => "tscii"},
  "perathanaitsc" => {charset => "tscii"},
  "aparanartsc" => {charset => "tscii"},
  "comictsc" => {charset => "tscii"},
  "maduramtsc" => {charset => "tscii"},
  "mylaifixtsc" => {charset => "tscii"},
  "mylaitsc" => {charset => "tscii"},
  "nanthinitsc" => {charset => "tscii"},
  "sri-tsc" => {charset => "tscii"},
  "timestsc" => {charset => "tscii"},
  "tneritsc" => {charset => "tscii"},
  "tamil_avarangal31tsc" => {charset => "tscii"},
  shivaji01 => {charset => "x-shivaji01"},
  vakil_01 => {charset => "x-vakil_01"},
  ".vntime" => {charset => "x-viet-tcvn"},
  "vntime" => {charset => "x-viet-tcvn"},
  "vni-aptima" => {charset => "x-viet-vni"},
  "vni-helve" => {charset => "x-viet-vni"},
  "vni-times" => {charset => "x-viet-vni"},
  "vni-internet mail" => {charset => "x-viet-vni"},
  "vni couri" => {charset => "x-viet-vni"},
  "vps times" => {charset => "x-viet-vps"},
  vikatan => {charset => "x-vikatan"},
  webdunia => {charset => "x-webdunia"},
  xdvng => {charset => 'x-xdvng'},
};

sub _detect_font ($$) {
  my $self = shift;
  $self->{fonts} = {};

  # 1.
  (pos $_[0]) = 0;

  my $count = 0;
  # 2.
  LOOP: {
    $_[0] =~ /\G<!--+>/gc;
    $_[0] =~ /\G<!--.*?-->/gcs;
    if ($_[0] =~ /\G<[Ff][Oo][Nn][Tt](?=[\x09\x0A\x0C\x0D\x20\x2F])/gc) {
      # 1.
      #

      # 2.-5.
      my $attr_list = {};

      # 6.
      ATTRS: {
        my $attr = _get_attr ($_[0]) or last ATTRS;

        # 7.
        redo ATTRS if $attr_list->{$attr->{name}};
        
        # 8.
        $attr_list->{$attr->{name}} = $attr;

        # 9.
        if ($attr->{name} eq 'face') {
          my $attr_value = $attr->{value};
          $attr_value =~ s/\A[\x09\x0A\x0C\x0D\x20]+//;
          $attr_value =~ s/[\x09\x0A\x0C\x0D\x20]+\z//;
          $attr_value =~ tr/A-Z/a-z/;
          $self->{fonts}->{$_}++ for split /[\x09\x0A\x0C\x0D\x20]*,[\x09\x0A\x0C\x0D\x20]*/, $attr_value;
          last LOOP if $count++ > 10;
        }

        # 10.
        last LOOP if pos $_[0] >= length $_[0];
        redo ATTRS;
      } # ATTRS
    } elsif ($_[0] =~ m{\G</?[A-Za-z][^\x09\x0A\x0C\x0D\x20>]*}gc) {
      {
        _get_attr ($_[0]) and redo;
      }
    } elsif ($_[0] =~ m{\G<[!/?][^>]*}gc) {
      #
    }

    # 3. Next byte
    $_[0] =~ /\G[^<]+/gc || $_[0] =~ /\G</gc;
    last LOOP if pos $_[0] >= length $_[0];
    redo LOOP;
  } # LOOP

  for my $font_name (sort { $self->{fonts}->{$b} <=> $self->{fonts}->{$a} } keys %{$self->{fonts}}) {
    my $f = $FontDefs->{$font_name};
    if (defined $f) {
      return $f;
    }
  }

  return undef;
} # _detect_font

1;

=head1 LICENSE

Copyright 2007-2025 Wakaba <wakaba@suikawiki.org>.

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
