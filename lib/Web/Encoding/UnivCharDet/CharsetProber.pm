package Web::Encoding::UnivCharDet::CharsetProber;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::Encoding::UnivCharDet::Defs;
use Web::Encoding::UnivCharDet::Defs3;
use Web::Encoding::UnivCharDet::CodingStateMachine;

sub get_state ($) {
  return $_[0]->{state};
} # get_state

sub filter_with_english_letters ($$) {
  my $is_in_tag = 0;
  my $new = '';
  my $prev = 0;

  my $len = length $_[1];
  for my $i (0..($len - 1)) {
    my $c = ord substr $_[1], $i, 1;
    if ($c == 0x3E) { # >
      $is_in_tag = 0;
    } elsif ($c == 0x3C) { # <
      $is_in_tag = 1;
    }

    if (not $c & 0x80 and
        ($c < 0x41 or 
         ($c > 0x5A and $c < 0x61) or
         $c > 0x7A)) {
      if ($i > $prev and not $is_in_tag) {
        while ($prev < $i) { $new .= substr $_[1], $prev, 1; $prev++ }
        $prev++;
        $new .= ' ';
      } else {
        $prev = $i + 1;
      }
    }
  } # $i

  unless ($is_in_tag) {
    while ($prev < $len) { $new .= substr $_[1], $prev, 1; $prev++ }
  }

  return $new;
} # filter_with_english_letters

sub handle_eof ($) { }

sub dump_status ($) {
  my $self = $_[0];
  printf "%s\n", ref $self;
} # dump_status

sub dump_status_for_json ($) {
  my $self = $_[0];
  return {type => ref $self};
} # dump_status_for_json

package Web::Encoding::UnivCharDet::CharsetProber::Latin1;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub UDF () { 0 }
sub OTH () { 1 }
sub ASC () { 2 }
sub ASS () { 3 }
sub ACV () { 4 }
sub ACO () { 5 }
sub ASV () { 6 }
sub ASO () { 7 }
sub CLASS_NUM () { 8 }
sub FREQ_CAT_NUM () { 4 }

my $Latin1_CharToClass = [
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,
  OTH, ASC, ASC, ASC, ASC, ASC, ASC, ASC,
  ASC, ASC, ASC, ASC, ASC, ASC, ASC, ASC,
  ASC, ASC, ASC, ASC, ASC, ASC, ASC, ASC,
  ASC, ASC, ASC, OTH, OTH, OTH, OTH, OTH,
  OTH, ASS, ASS, ASS, ASS, ASS, ASS, ASS,
  ASS, ASS, ASS, ASS, ASS, ASS, ASS, ASS,
  ASS, ASS, ASS, ASS, ASS, ASS, ASS, ASS,
  ASS, ASS, ASS, OTH, OTH, OTH, OTH, OTH,
  OTH, UDF, OTH, ASO, OTH, OTH, OTH, OTH,
  OTH, OTH, ACO, OTH, ACO, UDF, ACO, UDF,
  UDF, OTH, OTH, OTH, OTH, OTH, OTH, OTH,
  OTH, OTH, ASO, OTH, ASO, UDF, ASO, ACO,
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,
  OTH, OTH, OTH, OTH, OTH, OTH, OTH, OTH,
  ACV, ACV, ACV, ACV, ACV, ACV, ACO, ACO,
  ACV, ACV, ACV, ACV, ACV, ACV, ACV, ACV,
  ACO, ACO, ACV, ACV, ACV, ACV, ACV, OTH,
  ACV, ACV, ACV, ACV, ACV, ACO, ACO, ACO,
  ASV, ASV, ASV, ASV, ASV, ASV, ASO, ASO,
  ASV, ASV, ASV, ASV, ASV, ASV, ASV, ASV,
  ASO, ASO, ASV, ASV, ASV, ASV, ASV, OTH,
  ASV, ASV, ASV, ASV, ASV, ASO, ASO, ASO,
];

my $Latin1ClassModel = [
  0,  0,  0,  0,  0,  0,  0,  0,
  0,  3,  3,  3,  3,  3,  3,  3,
  0,  3,  3,  3,  3,  3,  3,  3, 
  0,  3,  3,  3,  1,  1,  3,  3,
  0,  3,  3,  3,  1,  2,  1,  2,
  0,  3,  3,  3,  3,  3,  3,  3, 
  0,  3,  1,  3,  1,  1,  1,  3, 
  0,  3,  1,  3,  1,  1,  3,  3,
];

sub new ($) {
  my $self = bless {}, $_[0];
  $self->reset;
  return $self;
} # new

sub reset ($) {
  my $self = $_[0];
  $self->{state} = 'detecting';
  $self->{last_char_class} = OTH;
  $self->{freq_counter}->[$_] = 0 for 0..(FREQ_CAT_NUM - 1);
} # reset

sub get_charset_name ($) { 'windows-1252' }

sub handle_data ($$) {
  my $self = $_[0];
  my $new_buf1 = $self->filter_with_english_letters ($_[1]);

  for my $i (0..((length $new_buf1) - 1)) {
    my $c = ord substr $new_buf1, $i, 1;
    my $char_class = $Latin1_CharToClass->[$c];
    my $freq = $Latin1ClassModel->[$self->{last_char_class}*CLASS_NUM + $char_class];
    if ($freq == 0) {
      $self->{state} = 'not me';
      last;
    }
    $self->{freq_counter}->[$freq]++;
    $self->{last_char_class} = $char_class;
  } # $i

  return $self->{state};
} # handle_data

sub get_confidence ($) {
  my $self = $_[0];
  if ($self->{state} eq 'not me') {
    return 0.01;
  }

  my $total = 0;
  for my $i (0..(FREQ_CAT_NUM - 1)) {
    $total += $self->{freq_counter}->[$i];
  }

  my $confidence;
  unless ($total) {
    $confidence = 0.0;
  } else {
    $confidence = $self->{freq_counter}->[3] * 1.0 / $total;
    $confidence -= $self->{freq_counter}->[1] * 20.0 / $total;
  }
  $confidence = 0.0 if $confidence < 0.0;
  $confidence *= 0.50;

  return $confidence;
} # get_confidence

sub dump_status ($) {
  my $self = $_[0];
  printf "  Latin1Prober: %1.3f [%s]\n",
      $self->get_confidence, $self->get_charset_name;
} # dump_status

sub dump_status_for_json ($) {
  my $self = $_[0];
  return {type => ref $self,
          charset => $self->get_charset_name,
          confidence => $self->get_confidence};
} # dump_status_for_json

package Web::Encoding::UnivCharDet::CharsetProber::SBCSGroup;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub new ($;%) {
  my $self = bless {}, shift;
  my %args = @_;
  $self->reset (%args);
  return $self;
} # new

sub reset ($;%) {
  my ($self, %args) = @_;
  $self->{probers} = $args{resolve_latin1_refs} ? [
    Web::Encoding::UnivCharDet::CharsetProber::Latin1->new, # [0]
    undef, # [1]
    undef, # [2]
    map { Web::Encoding::UnivCharDet::CharsetProber::SBCS->new ($_, resolve_latin1_refs => 1) }
    $Web::Encoding::UnivCharDet::Defs::Georgian_AcademyGeorgianModel,
    $Web::Encoding::UnivCharDet::Defs::Georgian_PsGeorgianModel,
    $Web::Encoding::UnivCharDet::Defs::TsciiModel,
    $Web::Encoding::UnivCharDet::Defs::TabModel,
    $Web::Encoding::UnivCharDet::Defs::TamModel,
  ] : [
    Web::Encoding::UnivCharDet::CharsetProber::Latin1->new, # [0]
    map { Web::Encoding::UnivCharDet::CharsetProber::SBCS->new ($_) }
    $Web::Encoding::UnivCharDet::Defs::Windows_1250CentralModel, # [1]
    $Web::Encoding::UnivCharDet::Defs::MacintoshWesternModel, # [2]
    
    $Web::Encoding::UnivCharDet::Defs::Win1251Model,
    $Web::Encoding::UnivCharDet::Defs::Koi8rModel,
    $Web::Encoding::UnivCharDet::Defs::Windows_1253GreekModel,
    $Web::Encoding::UnivCharDet::Defs::Iso_8859_7GreekModel,
    #$Web::Encoding::UnivCharDet::Defs::Iso_8859_7Model,
    #$Web::Encoding::UnivCharDet::Defs::Win1253Model,
    $Web::Encoding::UnivCharDet::Defs::Win1251BulgarianModel,
    $Web::Encoding::UnivCharDet::Defs::TIS620ThaiModel,
    $Web::Encoding::UnivCharDet::Defs::Windows_1256ArabicModel,
    $Web::Encoding::UnivCharDet::Defs::Georgian_AcademyGeorgianModel,
    $Web::Encoding::UnivCharDet::Defs::Georgian_PsGeorgianModel,
    $Web::Encoding::UnivCharDet::Defs::Armscii_8ArmenianModel,
    $Web::Encoding::UnivCharDet::Defs::TsciiModel,
    $Web::Encoding::UnivCharDet::Defs::TabModel,
    $Web::Encoding::UnivCharDet::Defs::TamModel,
    
    $Web::Encoding::UnivCharDet::Defs::Ibm866Model,
    $Web::Encoding::UnivCharDet::Defs::Ibm855Model,
    $Web::Encoding::UnivCharDet::Defs::Cp737GreekModel,
    $Web::Encoding::UnivCharDet::Defs::Ibm862HebrewModel,
    
    $Web::Encoding::UnivCharDet::Defs::MacCyrillicModel,
    
    $Web::Encoding::UnivCharDet::Defs::Iso_8859_5Model,
    $Web::Encoding::UnivCharDet::Defs::Iso_8859_5BulgarianModel,
    $Web::Encoding::UnivCharDet::Defs::Iso_8859_6ArabicModel,
  ];
  if ($args{resolve_latin1_refs}) {
    $self->{resolve_latin1_refs} = 1;
  } else {
    push @{$self->{probers}},
        Web::Encoding::UnivCharDet::CharsetProber::Hebrew->new;
  }
  $self->{inactive_probers} = [];
  
  $self->{active_num} = @{$self->{probers}};
  $self->{best_guess} = -1;
  $self->{state} = 'detecting';
  delete $self->{latin};
} # reset

sub get_charset_name ($) {
  my $self = $_[0];
  if ($self->{best_guess} == -1) {
    $self->get_confidence;
  }
  if ($self->{state} eq 'not me' and $self->{latin}) {
    return 'windows-1252';
  } elsif ($self->{best_guess} == -1) {
    return undef;
  }
  return $self->{probers}->[$self->{best_guess}]->get_charset_name;
} # get_charset_name

sub handle_data ($$) {
  my $self = $_[0];

  for my $i (0..$#{$self->{probers}}) {
    local $_ = $self->{probers}->[$i];
    next unless defined $_;
    my $st = $_->handle_data ($_[1]);
    if ($st eq 'found it') {
      $self->{best_guess} = $i;
      return $self->{state} = 'found it';
    } elsif ($st eq 'not me') {
      push @{$self->{inactive_probers}}, delete $self->{probers}->[$i];
      $self->{active_num}--;
      if ($self->{active_num} <= 0) {
        return $self->{state} = 'not me';
      }
    }
  } # $i

  if (not $self->{latin} and
        ((defined $self->{probers}->[0] and
          $self->{probers}->[0]->get_confidence > 0.3) or
         (defined $self->{probers}->[1] and
          $self->{probers}->[1]->get_confidence > 0.3) or
         (defined $self->{probers}->[2] and
          $self->{probers}->[2]->get_confidence > 0.2))) {
    $self->{latin} = 1;
    push @{$self->{inactive_probers}}, delete $self->{probers}->[0]
        if defined $self->{probers}->[0]; # Latin1

      my $old_prober_count = @{$self->{probers}};
      my @new_prober = $self->{resolve_latin1_refs} ? (
        map { Web::Encoding::UnivCharDet::CharsetProber::SBCS->new ($_, resolve_latin1_refs => 1) }
        $Web::Encoding::UnivCharDet::Defs::Windows_1252WesternModel,
        $Web::Encoding::UnivCharDet::Defs::Windows_1252ScandinavianModel,
        #$Web::Encoding::UnivCharDet::Defs::Iso_8859_4BalticModel,
        $Web::Encoding::UnivCharDet::Defs::Iso_8859_3EsperantoModel,
      ) : (
        map { Web::Encoding::UnivCharDet::CharsetProber::SBCS->new ($_) }
        $Web::Encoding::UnivCharDet::Defs::Windows_1252WesternModel,
        $Web::Encoding::UnivCharDet::Defs::Windows_1252ScandinavianModel,
        $Web::Encoding::UnivCharDet::Defs::Iso_8859_2CentralModel,
        $Web::Encoding::UnivCharDet::Defs::Windows_1257BalticModel,
        $Web::Encoding::UnivCharDet::Defs::Windows_1254TurkishModel,
        $Web::Encoding::UnivCharDet::Defs::Windows_1252IcelandicFaroeseModel,
        
        $Web::Encoding::UnivCharDet::Defs::Ibm437WesternModel,
        $Web::Encoding::UnivCharDet::Defs::Ibm850WesternModel,
        $Web::Encoding::UnivCharDet::Defs::Ibm850ScandinavianModel,
        $Web::Encoding::UnivCharDet::Defs::Ibm852CentralModel,
        $Web::Encoding::UnivCharDet::Defs::Ibm775BalticModel,
        $Web::Encoding::UnivCharDet::Defs::Ibm857TurkishModel,
        $Web::Encoding::UnivCharDet::Defs::Ibm865DanishModel,
        
        $Web::Encoding::UnivCharDet::Defs::MacintoshScandinavianModel,
        $Web::Encoding::UnivCharDet::Defs::X_Mac_CeCentralModel,

        $Web::Encoding::UnivCharDet::Defs::Iso_8859_13BalticModel,
        $Web::Encoding::UnivCharDet::Defs::Iso_8859_3EsperantoModel,
        $Web::Encoding::UnivCharDet::Defs::Iso_8859_4BalticModel,

        $Web::Encoding::UnivCharDet::Defs::Iso_8859_15EstonianModel,
        $Web::Encoding::UnivCharDet::Defs::Iso_8859_15FrenchModel,
        $Web::Encoding::UnivCharDet::Defs::Iso_8859_10BalticModel,
        #$Web::Encoding::UnivCharDet::Defs::Iso_8859_16CentralModel,
        $Web::Encoding::UnivCharDet::Defs::Iso_8859_16RomanianModel,
        #$Web::Encoding::UnivCharDet::Defs::Windows_1258VietnameseModel,
      );
      my $p = delete $self->{probers}->[2]; # or undef
      splice @{$self->{probers}}, 0, 1, @new_prober;
      push @{$self->{probers}}, $p;
      $self->{active_num} += @new_prober;

    for my $i (0..$#new_prober) {
      local $_ = $self->{probers}->[$i];
      next unless defined $_;
      my $st = $_->handle_data ($_[1]);
      if ($st eq 'found it') {
        $self->{best_guess} = $i;
        return $self->{state} = 'found it';
      } elsif ($st eq 'not me') {
        push @{$self->{inactive_probers}}, delete $self->{probers}->[$i];
        $self->{active_num}--;
        if ($self->{active_num} <= 0) {
          return $self->{state} = 'not me';
        }
      }
    } # $i
  }
  
  return $self->{state};
} # handle_data

sub handle_eof ($) {
  my $self = $_[0];
  for (@{$self->{probers}}) {
    $_->handle_eof if defined $_;
  }
} # handle_eof

sub get_confidence ($) {
  my $self = $_[0];

  if ($self->{state} eq 'found it') {
    return 0.99;
  } elsif ($self->{state} eq 'not me') {
    return 0.01;
  } else {
    my $best_conf = 0.0;
    my $best_i = [];
    for my $i (0..$#{$self->{probers}}) {
      local $_ = $self->{probers}->[$i];
      next unless $_;
      my $cf = $_->get_confidence;
      if ($best_conf < $cf) {
        $best_conf = $cf;
        $self->{best_guess} = $i;
        $best_i = [$i];
      } elsif ($best_conf == $cf) {
        push @$best_i, $i;
      }
    }
    if (@$best_i > 1) {
      my $cc = {};
      my $cn = {};
      for my $i (@$best_i) {
        my $charset = $self->{probers}->[$i]->get_charset_name;
        if (defined $charset) {
          $cc->{$charset}++;
          $cn->{$charset} //= $i;
        }
      }
      ## When multiple encodings has equal confidence values, use the
      ## first encoding in the list.  This can happen when the input
      ## only has limited numbers of non-ASCII characters and the
      ## encodings have similar structures, e.g. windows-1257 vs
      ## iso-8859-13 vs ibm775.
      my $charset = [sort { $cc->{$b} <=> $cc->{$a} ||
                            $cn->{$a} <=> $cn->{$b} ||
                            $a cmp $b } keys %$cc]->[0];
      if (defined $charset) {
        $self->{best_guess} = $cn->{$charset};
        if ($best_conf < 0.21 and $self->{latin} and $charset eq 'windows-1252') {
          $best_conf = 0.21;
        } elsif ($best_conf <= 0.01) {
          $self->{best_guess} = -1;
        }
      }
    }
    return $best_conf;
  }
} # get_confidence

sub dump_status ($) {
  my $self = $_[0];
  my $cf = $self->get_confidence;
  printf " SBCS: %s [%s] %s\n",
      $cf,
      $self->get_charset_name // '',
      ($self->{resolve_latin1_refs} ? 'htmlrefs' : '');
  for my $i (0..$#{$self->{probers}}) {
    local $_ = $self->{probers}->[$i];
    $_->dump_status if defined $_;
  }
  for (@{$self->{inactive_probers}}) {
    print "  [in]";
    $_->dump_status;
  }
} # dump_status

sub dump_status_for_json ($) {
  my $self = $_[0];
  my $r = {
    type => ref $self,
    charset => $self->get_charset_name, # or undef
    confidence => $self->get_confidence,
    probers => [map { $_->dump_status_for_json } grep { defined $_ } @{$self->{probers}}],
    inactive_probers => [map { $_->dump_status_for_json } grep { defined $_ } @{$self->{inactive_probers}}],
    htmlrefs => !!$self->{resolve_latin1_refs},
  };
  if ($self->{best_guess} >= 0) {
    $r->{best_guess} = $self->{probers}->[$self->{best_guess}]->get_charset_name;
  }
  return $r;
} # dump_status_for_json

package Web::Encoding::UnivCharDet::CharsetProber::SBCS;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub SAMPLE_SIZE () { 64 }
sub SB_ENOUGH_REL_THRESHOLD () { 1024 }
sub POSITIVE_SHORTCUT_THRESHOLD () { 0.95 }
sub NEGATIVE_SHORTCUT_THRESHOLD () { 0.05 }
sub POSITIVE_CAT () { 3 }
sub PROBABLE_CAT () { 2 }
sub NEUTRAL_CAT () { 1 }
sub NEGATIVE_CAT () { 0 }
sub SYM_CAT () { 4 }
sub CPY_CAT () { 5 }
sub CPY2_CAT () { 6 }
sub DRAWING1_CAT () { 7 }
sub DRAWING2_CAT () { 8 }
sub NEG_CAT () { 9 }

sub ILL () { 255 }
sub CTR () { 254 }
sub SYM () { 253 }
sub RET () { 252 }
sub NUM () { 251 }
sub CPY () { 250 }
sub TMK () { 249 }
sub ORD () { 248 }
sub DLM () { 247 }
sub SYMBOL_CAT_ORDER () { 246 }

sub new ($$;%) {
  my $self = bless {}, shift;
  $self->{model} = shift // die "No model";
  $self->{model}->{class_table} //= $Web::Encoding::UnivCharDet::Defs::defaultCharClassTable;
  $self->reset (@_);
  return $self;
} # new

sub reset ($;%) {
  my ($self, %args) = @_;
  $self->{state} = 'detecting';
  $self->{last_order} = 255;
  $self->{seq_counters} = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
  $self->{total_seqs} = 0;
  $self->{total_char} = 0;
  $self->{ctrl_char} = 0;
  $self->{out_char} = 0;
  $self->{freq_char} = 0;
  $self->{enough_threshold} = SB_ENOUGH_REL_THRESHOLD;
  $self->{symbol_state} = 0;
  $self->{class_state} = 0;
  $self->{word_state} = $args{tokenized} ? 4 : 0;
  $self->{reversed} = $args{reversed};
  #$self->{resolve_latin1_refs} = $args{resolve_latin1_refs};
} # reset

sub handle_data ($$) {
  my $self = $_[0];
  my $ss = $self->{model}->{freq_char_count} // SAMPLE_SIZE;

  my $i = 0;
  my $word_start_i = 0;
  my $max_i = (length $_[1]) - 1;
  while ($i <= $max_i) {
    my $cc = ord substr $_[1], $i, 1;
    my $char_class_all = ord substr $self->{model}->{class_table}, $cc, 1;
    my $char_class = $char_class_all & $Web::Encoding::UnivCharDet::Defs::CharClassMask;

    my @cc;
    ## Input non-ASCII bytes and sorounding ASCII alphabet letters to
    ## the model.
    # $self->{word_state}
    #   0  Initial
    #   1  non-ASCII
    #   2  ASCII word
    #   3  trailing ASCII word
    #   4  tokenized data
    if ($self->{word_state} == 1) {
      if ($cc >= 0x80) {
        push @cc, $cc;
      } else {
        if ($char_class_all & (Web::Encoding::UnivCharDet::Defs::CCB_CAPITAL | Web::Encoding::UnivCharDet::Defs::CCB_SMALL)) {
          $self->{word_state} = 3;
          push @cc, $cc;
        } else {
          #push @cc, $cc;
          push @cc, 0x20;
          $self->{word_state} = 0;
        }
      }
    } elsif ($self->{word_state} == 3) {
      if ($cc >= 0x80) {
        $self->{word_state} = 1;
        push @cc, $cc;
      } else {
        if ($char_class_all & (Web::Encoding::UnivCharDet::Defs::CCB_CAPITAL | Web::Encoding::UnivCharDet::Defs::CCB_SMALL)) {
          push @cc, $cc;
        } else {
          #push @cc, $cc;
          push @cc, 0x20;
          $self->{word_state} = 0;
        }
      }
    } elsif ($self->{word_state} == 2) {
      if ($cc >= 0x80) {
        $self->{word_state} = 1;
        push @cc, 0x20;
        $word_start_i = $i - 10 if $word_start_i + 10 < $i;
        for ($word_start_i .. ($i - 1)) {
          push @cc, ord substr $_[1], $_, 1;
        }
        push @cc, $cc;
      } else {
        if ($char_class_all & (Web::Encoding::UnivCharDet::Defs::CCB_CAPITAL | Web::Encoding::UnivCharDet::Defs::CCB_SMALL)) {
          #
        } else {
          $self->{word_state} = 0;
        }
      }
    } elsif ($self->{word_state} == 4) {
      push @cc, $cc;
    } else { # 0 initial
      if ($cc >= 0x80) {
        $self->{word_state} = 1;
        push @cc, $cc;
      } else {
        if ($char_class_all & (Web::Encoding::UnivCharDet::Defs::CCB_CAPITAL | Web::Encoding::UnivCharDet::Defs::CCB_SMALL)) {
          $self->{word_state} = 2;
          #$word_start_i = $i - 1;
          #$word_start_i = 0 if $i < 1;
          $word_start_i = $i;
        }
      }
    }
    if ($self->{word_state} == 2) {
      ## Serve last 10 ASCII letters to the model such that it is
      ## taken into account in case the next chunk starts with
      ## non-ASCII bytes.
      $word_start_i = $max_i - 10 if $word_start_i + 10 < $max_i;
      #for ($word_start_i .. ($i - 1)) {
        # XXX
      #}
    }

    for my $cc (@cc) {
      my $order = (ord substr $self->{model}->{char_to_order_map}, $cc, 1) || 0;

    $self->{total_char}++;
    if ($order == ILL) {
      $self->{state} = 'not me';
      last;
    } elsif ($order == CTR) {
      $self->{ctrl_char}++;
    } elsif ($order < $ss) {
      $self->{freq_char}++;
      if ($self->{last_order} < $ss) {
        $self->{total_seqs}++;
        unless ($self->{reversed}) {
          ++$self->{seq_counters}->[
            ord substr $self->{model}->{precedence_matrix},
                    ($self->{last_order} * $ss + $order), 1
          ];
        } else {
          ++$self->{seq_counters}->[
            ord substr $self->{model}->{precedence_matrix},
                    ($order * $ss + $self->{last_order}), 1
          ];
        }
      } elsif ($self->{last_order} < SYMBOL_CAT_ORDER) {
        $self->{seq_counters}->[NEGATIVE_CAT]++;
        $self->{total_seqs}++;
      }
    } elsif ($order < SYMBOL_CAT_ORDER) {
      $self->{out_char}++;
      if ($self->{last_order} < SYMBOL_CAT_ORDER) {
        $self->{seq_counters}->[NEGATIVE_CAT]++;
        $self->{total_seqs}++;
      }
    } elsif ($order == SYM) {
      $self->{seq_counters}->[SYM_CAT]++;
    }
    $self->{last_order} = $order;
    $self->{symbol_state} = 0;
    } # $cc

    if ($self->{class_state} == 12) {
      if ($char_class == Web::Encoding::UnivCharDet::Defs::CC_DRAWING) {
        $self->{seq_counters}->[DRAWING2_CAT]++;
        $self->{class_state} = 13;
      } else {
        $self->{seq_counters}->[DRAWING1_CAT]++;
      }
    }
    if ($char_class == Web::Encoding::UnivCharDet::Defs::CC_DELIMITER or
        $char_class == Web::Encoding::UnivCharDet::Defs::CC_DOT) {
      if (($self->{class_state} == 3 or
           $self->{class_state} == 17) and $cc <= 0x7F) {
        $self->{seq_counters}->[CPY_CAT]++;
      } elsif ($self->{class_state} == 10) {
        $self->{seq_counters}->[CPY_CAT]++;
      } elsif ((($self->{class_state} == 4 or
                 $self->{class_state} == 21) and $cc <= 0x7F) or
               $self->{class_state} == 3 or
               $self->{class_state} == 7) {
        $self->{seq_counters}->[CPY2_CAT]++;
      }
      if ($char_class == Web::Encoding::UnivCharDet::Defs::CC_DOT) {
        $self->{class_state} = 18;
      } elsif ($cc <= 0x7F) {
        $self->{class_state} = 2;
      } else {
        $self->{class_state} = 6;
      }
    } elsif (($self->{class_state} == 2 or $self->{class_state} == 0) and
             $char_class == Web::Encoding::UnivCharDet::Defs::CC_COPYRIGHT) {
      $self->{class_state} = 3;
      ## Delimiter followed by copyright followed by delimiter is
      ## counted as a strong implication for the encoding.  Many Web
      ## pages have a 0xA9 byte, i.e. a copyright sign in ANSI code
      ## pages, enclosed by spaces or tags.
      ##
      ## Though 0xA9 is a valid Shift_JIS character, it's a halfwidth
      ## small Katakana, which should have been preceded by a
      ## halfwidth Katakana.
      ##
      ## Sometimes the copyright sign is followed by a year or a
      ## copyright holder's name.  In many multibyte encodings the
      ## 0xA9 byte can be the first byte of a multibyte character.
      ##
      ## In many Macintosh encodings, 0xA9 is copyright sign.
      ##
      ## In many OEM code pages, 0xA8 is copyright sign.  It's also a
      ## halfwidth small Katakana in Shift_JIS and can be the first
      ## byte of a multibyte character.
      ##
      ## 0xA0 can be the second byte of a multibyte character such
      ## that recognizing 0x20 0xA9 0xA0 or 0xA0 0xA9 0xA0 as a strong
      ## implication is a bit dangerous.
    } elsif ($self->{class_state} == 6 and
             $char_class == Web::Encoding::UnivCharDet::Defs::CC_COPYRIGHT) {
      $self->{class_state} = 7;
    } elsif ($self->{class_state} == 9 and
             $char_class_all & Web::Encoding::UnivCharDet::Defs::CCB_AFTER_APOS2) {
      $self->{seq_counters}->[CPY2_CAT]++;
      $self->{class_state} = 5; # if CAPITAL | SMALL and is ASCII
    } elsif ($self->{class_state} == 9 and
             $char_class_all & Web::Encoding::UnivCharDet::Defs::CCB_AFTER_APOS1) {
      $self->{class_state} = 10;
    } elsif ($cc <= 0x7F and
             $char_class == Web::Encoding::UnivCharDet::Defs::CC_DIGIT) {
      if ($self->{class_state} == 11) {
        $self->{seq_counters}->[CPY2_CAT]++;
      } elsif ($self->{class_state} == 3 and
               ($cc == 0x31 or $cc == 0x32)) { # copyright 199x or 200x
        $self->{seq_counters}->[CPY_CAT]++;
      } elsif ($self->{class_state} == 17) { # No
        $self->{seq_counters}->[CPY_CAT]++;
      }
      $self->{class_state} = 5;
    } elsif ($cc <= 0x7F and
             ($char_class_all & (Web::Encoding::UnivCharDet::Defs::CCB_CAPITAL | Web::Encoding::UnivCharDet::Defs::CCB_SMALL))) {
      if ($self->{class_state} == 15) {
        unless ($cc == 0x43 or $cc == 0x46) { # C F
          $self->{seq_counters}->[NEG_CAT]++;
          ## When a ANSI code page text is misinterpreted as OEM code
          ## page, there might be a degree sign within a single latin
          ## word.
        }
      } elsif ($self->{class_state} == 23) {
        ## delimiter left-quote alpha alpha
        $self->{seq_counters}->[CPY_CAT]++;
      }
      if ($char_class == Web::Encoding::UnivCharDet::Defs::CC_B_ORDINAL) {
        $self->{class_state} = 16
      } elsif ($char_class == Web::Encoding::UnivCharDet::Defs::CC_ROMAN) {
        if ($self->{class_state} == 20 ||
            $self->{class_state} == 19 ||
            $self->{class_state} == 2 ||
            $self->{class_state} == 0) {
          $self->{class_state} = 20;
        } else {
          $self->{class_state} = 19;
        }
      } elsif ($self->{class_state} == 22) {
        $self->{class_state} = 23;
      } else {
        $self->{class_state} = 5;
      }
    } elsif ($char_class_all & (Web::Encoding::UnivCharDet::Defs::CCB_CAPITAL | Web::Encoding::UnivCharDet::Defs::CCB_SMALL)) {
      if ($char_class_all & Web::Encoding::UnivCharDet::Defs::CCB_CAPITAL and
          $char_class_all & Web::Encoding::UnivCharDet::Defs::CCB_SMALL and
          $cc == 0xDF) {
        $self->{class_state} = 14; # windows-1252 : 0xDF ss 
      } else {
        $self->{class_state} = 8;
      }
    } elsif ($char_class == Web::Encoding::UnivCharDet::Defs::CC_TM and
             ($self->{class_state} == 5 or $self->{class_state} == 22 or
              $self->{class_state} == 23 or $self->{class_state} == 8 or
              $self->{class_state} == 2 or $self->{class_state} == 16 or
              $self->{class_state} == 19 or $self->{class_state} == 20)) {
      $self->{class_state} = 4;
      ## ASCII alphanumeric followed by a trademark or a registered
      ## trademark followed by delimiter is counted as an implication
      ## for the encoding.
      ##
      ## 0xAE registered trademark in many ANSI code pages
      ## 0xA9 registered trademark in many OEM code pages
      ## 0xA8 registered trademark in many Macintosh encodings
      ## 0x99 trademark in many ANSI code pages
      ## 0xAA trademark in many Macintosh encodings
      ##
      ## 0xA8 .. 0xAE are halfwidth Katakana in Shift_JIS and will not
      ## follow a alphanumeric in normal texts.
      ##
      ## 0x99 and 0xA8 .. 0xAE can be one of the bytes of a multibyte
      ## character.  However, if it is preceded by an ASCII
      ## alphanumerical byte and followed by an ASCII delimiter byte,
      ## it cannot be a port of a well-formed multibyte character.
    } elsif ($char_class == Web::Encoding::UnivCharDet::Defs::CC_RAPOS) {
      if ($self->{class_state} == 14) {
        # 0xDF 0x92 in windows-1252
        $self->{seq_counters}->[CPY2_CAT]++;
      }
      
      $self->{class_state} = 9;
      ## 0x92 right single quotation mark in many ANSI code pages
      ##
      ## It is used as apostorophe of e.g. |don't|, |we're|, |I've|,
      ## and |I'm|.  If it is followed by one of commonly seen
      ## patterns, it is counted as am implication for the encoding.
      ##
      ## 0x92 is the first byte of a multibyte character in many MBCS
      ## encodings.
    } elsif ($char_class == Web::Encoding::UnivCharDet::Defs::CC_LQUOTE) {
      if ($self->{class_state} == 14) {
        # 0xDF 0x93 in windows-1252
        $self->{seq_counters}->[CPY2_CAT]++;
      }
      if ($self->{class_state} == 2 or $self->{class_state} == 0) {
        $self->{class_state} = 22;
      } else {
        $self->{class_state} = 1;
      }
    } elsif ($char_class == Web::Encoding::UnivCharDet::Defs::CC_CURRENCY) {
      $self->{class_state} = 11;
      ## 0x80 euro sign in many ANSI code pages and gb18030
      ## 0xA? currency signs in some ANSI code pages
      ##
      ## 0x80 is NOT the first byte of any multibyte character in most
      ## popular MBCS encodings.  It can be the second byte of many
      ## MBCS encodings.
      ##
      ## 0xA? are halfwidth Katakana and are the first and the second
      ## byte of many MBCS encodigns.
    } elsif ($char_class == Web::Encoding::UnivCharDet::Defs::CC_ORDINAL) {
      if ($self->{class_state} == 16 or
          $self->{class_state} == 18 or
          $self->{class_state} == 20 or
          $self->{class_state} == 5 or
          $self->{class_state} == 22 or
          $self->{class_state} == 23 or
          $self->{class_state} == 0 or
          $self->{class_state} == 2) {
        $self->{class_state} = 17;
      } elsif ($self->{class_state} == 19) {
        $self->{class_state} = 21;
      } else {
        $self->{class_state} = 15;
      }
    } elsif ($char_class == Web::Encoding::UnivCharDet::Defs::CC_DRAWING) {
      $self->{class_state} = 12 unless $self->{class_state} == 13;
    } else {
      $self->{class_state} = 1;
      ## 0: initial
      ## 1: normal
      ## 2: after ASCII delimiter
      ## 3: after copyright
      ## 4: after ASCII followed by trademark
      ## 5: after ASCII alphanumeric
      ## 6: after non-ASCII delimiter
      ## 7: after non-ASCII delimiter followed by copyright
      ## 8: after non-ASCII alphabet
      ## 9: after right single quotation
      ## 10: after right single quotation and after-apos1
      ## 11: after currency symbol
      ## 12: after first box-drawing
      ## 13: after second box-drawing
      ## 14: after ss
      ## 15: after ordinal
      ## 16: after N
      ## 17: after N followed by ordinal
      ## 18: after dot
      ## 19: after roman
      ## 20: after roman or delimiter followed by roman
      ## 21: after 20 followed by ordinal
      ## 22: after delimiter followed by left quotation
      ## 23: after 22 followed by ASCII alpha
    }

    $i++;
  } # $i

  ## Seems less useful
  if ($self->{state} eq 'detecting') {
    if ($self->{total_seqs} > $self->{enough_threshold}) {
      my $cf = $self->get_confidence;
      if ($cf > POSITIVE_SHORTCUT_THRESHOLD) {
        $self->{state} = 'found it';
      } elsif ($cf < NEGATIVE_SHORTCUT_THRESHOLD) {
        $self->{state} = 'not me';
      }
      $self->{enough_threshold} += SB_ENOUGH_REL_THRESHOLD/2;
    }
  }

  return $self->{state};
} # handle_data

sub handle_eof ($) {
  my $self = $_[0];
  if ($self->{state} eq 'detecting') {
    if ($self->{class_state} == 3 or $self->{class_state} == 10) {
      $self->{seq_counters}->[CPY_CAT]++;
    } elsif ($self->{class_state} == 4 or $self->{class_state} == 7) {
      $self->{seq_counters}->[CPY2_CAT]++;
    } elsif ($self->{class_state} == 12) {
      $self->{seq_counters}->[DRAWING1_CAT]++;
    }
  }
} # handle_eof

sub get_confidence ($) {
  my $self = $_[0];

  my $r = 0.01;
    if ($self->{total_seqs} > 0) {
      my $positive_seqs = $self->{seq_counters}->[POSITIVE_CAT];
      my $probable_seqs = $self->{seq_counters}->[PROBABLE_CAT];
      my $neutral_seqs = $self->{seq_counters}->[NEUTRAL_CAT];
      my $negative_seqs = $self->{seq_counters}->[NEGATIVE_CAT];

      $r = ($positive_seqs + $probable_seqs/4)
          / (($self->{total_seqs} - $neutral_seqs) || 1)
          / $self->{model}->{typical_positive_ratio};
      $r = $r * ($self->{total_char} - $self->{out_char} - $self->{ctrl_char}) / $self->{total_char};
      $r = $r * $self->{freq_char} / $self->{total_char};
      $r = 0.99 if $r >= 1.00;
    }

  {
    my $n = $self->{seq_counters}->[CPY_CAT] + 0.3 * $self->{seq_counters}->[CPY2_CAT];
    if ($n and $self->{seq_counters}->[NEGATIVE_CAT] < 10) {
      my $A = 1.0;
      my $k = 2.0;
      my $boost = (1 - $r) * $A * (1 - exp(-$k * $n));

      $r += $boost;
      $r = 0.99 if $r > 0.99;
    }
  }
  {
    my $n = $self->{seq_counters}->[DRAWING1_CAT];
    $n = 0 if $self->{seq_counters}->[DRAWING2_CAT];
    $n += $self->{seq_counters}->[NEG_CAT];
    if ($n) {
      my $penalty = $r * (1 - exp(-0.7 * $n));
      $r -= $penalty;
      $r = 0.01 if $r < 0.01;
    }
  }
      
  $r *= 0.01 if $self->{model}->{debug_only};
  return $r;
} # get_confidence

sub get_charset_name ($) {
  my $self = $_[0];
  return $self->{model}->{charset_name};
} # get_charset_name

sub keep_english_letters ($) {
  return $_[0]->{model}->{keep_english_letter};
} # keep_english_letters

sub dump_status ($) {
  my $self = $_[0];
  my $positive_seqs = $self->{seq_counters}->[POSITIVE_CAT];
  my $probable_seqs = $self->{seq_counters}->[PROBABLE_CAT];
  my $neutral_seqs = $self->{seq_counters}->[NEUTRAL_CAT];
  my $negative_seqs = $self->{seq_counters}->[NEGATIVE_CAT];
  printf "  %.4f [%s] (%s, %d %d %d %d s=%d c=%d,%d x=%d,%d -%d / %s)\n",
      $self->get_confidence * ($self->{model}->{debug_only} ? 100 : 1),
      $self->{model}->{debug_name} // $self->get_charset_name,
      $self->{state},
      $positive_seqs, $probable_seqs, $neutral_seqs, $negative_seqs,
      $self->{seq_counters}->[SYM_CAT],
      $self->{seq_counters}->[CPY_CAT],
      $self->{seq_counters}->[CPY2_CAT],
      $self->{seq_counters}->[DRAWING1_CAT],
      $self->{seq_counters}->[DRAWING2_CAT],
      $self->{seq_counters}->[NEG_CAT],
      $self->{total_char};
} # dump_status

sub dump_status_for_json ($) {
  my $self = $_[0];
  return {
    type => $self->{model}->{debug_name} // $self->get_charset_name,
    charset => $self->get_charset_name,
    #htmlrefs => !! resolve_latin1_refs
    state => $self->{state},
    confidence => $self->get_confidence * ($self->{model}->{debug_only} ? 100 : 1),
    seq_counters => $self->{seq_counters},
    total_char => $self->{total_char},
  };
} # dump_status_for_json

package Web::Encoding::UnivCharDet::CharsetProber::Hebrew;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub MIN_FINAL_CHAR_DISTANCE () { 5 }
sub MIN_MODEL_DISTANCE () { 0.01 }

sub VISUAL_HEBREW_NAME () { "iso-8859-8" }
sub LOGICAL_HEBREW_NAME () { "windows-1255" }

my $IS_FINAL = {
  0xEA, 1, # FINAL_KAF
  0xED, 1, # FINAL_MEM
  0xEF, 1, # FINAL_NUN
  0xF3, 1, # FINAL_PE
  0xF5, 1, # FINAL_TSADI
};

my $IS_NON_FINAL = {
  0xEB, 1, # NORMAL_KAF
  0xEE, 1, # NORMAL_MEM
  0xF0, 1, # NORMAL_NUN
  0xF4, 1, # NORMAL_PE
  ## Not sure why this is excluded...
  #0xF6, 1, # NORMAL_TSADI
};

sub new ($;%) {
  my $self = bless {}, $_[0];
  $self->{probers} = [
    Web::Encoding::UnivCharDet::CharsetProber::SBCS->new # logical
        ($Web::Encoding::UnivCharDet::Defs::Win1255Model),
    Web::Encoding::UnivCharDet::CharsetProber::SBCS->new # visual
        ($Web::Encoding::UnivCharDet::Defs::Win1255Model),
  ];
  $self->reset;
  return $self;
} # new

sub reset ($;%) {
  my $self = $_[0];
  $self->{final_char_logical_score} = 0;
  $self->{final_char_visual_score} = 0;
  $self->{prev} = 0;
  $self->{before_prev} = 0;
  $self->{state} = 'detecting';
  $self->{confidence} = 0.01;
  $self->{probers}->[0]->reset; # logical
  $self->{probers}->[1]->reset (reverse => 1); # visual
} # reset

sub handle_data ($$) {
  my $self = $_[0];
  if ($self->{state} eq 'not me') {
    return $self->{state};
  }

  delete $self->{confidence};
  my $bad = 0;
  for (@{$self->{probers}}) {
    my $state = $_->handle_data ($_[1]);
    $bad++ if $state eq 'not me';
  }
  if ($bad == @{$self->{probers}}) {
    return $self->{state} = 'not me';
  }

  for my $i (0..((length $_[1]) - 1)) {
    my $cc = ord substr $_[1], $i, 1;
    if (0xD0 <= $cc and $cc <= 0xFA) { # hebrew letter
      if ($self->{before_prev} == 0 and $IS_FINAL->{$self->{prev}}) {
        ## \b, final, letter
        $self->{final_char_visual_score}++;
      }
    } else { # not a hebrew letter
      $cc = 0;
      if ($self->{before_prev} != 0) {
        if ($IS_FINAL->{$self->{prev}}) {
          ## letter, final, \b
          $self->{final_char_logical_score}++;
        } elsif ($IS_NON_FINAL->{$self->{prev}}) {
          ## letter, non-final, \b
          $self->{final_char_visual_score}++;
        }
      }
    }
    $self->{before_prev} = $self->{prev};
    $self->{prev} = $cc;
  } # $i

  return $self->{state};
} # handle_data

sub get_state ($) { $_[0]->{state} }

sub get_charset_name ($) {
  my $self = $_[0];

  if ($self->{final_char_logical_score} and not $self->{final_char_visual_score}) {
    $self->{confidence} = $self->{probers}->[0]->get_confidence;
    return LOGICAL_HEBREW_NAME;
  } elsif ($self->{final_char_visual_score} and not $self->{final_char_logical_score}) {
    $self->{confidence} = $self->{probers}->[1]->get_confidence;
    return VISUAL_HEBREW_NAME;
  }
  
  my $finalsub = $self->{final_char_logical_score} - $self->{final_char_visual_score};
  if ($finalsub >= MIN_FINAL_CHAR_DISTANCE) {
    $self->{confidence} = $self->{probers}->[0]->get_confidence;
    return LOGICAL_HEBREW_NAME;
  } elsif ($finalsub <= - MIN_FINAL_CHAR_DISTANCE) {
    $self->{confidence} = $self->{probers}->[1]->get_confidence;
    return VISUAL_HEBREW_NAME;
  }

  my $modelsub = $self->{probers}->[0]->get_confidence # logical
               - $self->{probers}->[1]->get_confidence; # visual
  if ($modelsub > MIN_MODEL_DISTANCE) {
    $self->{confidence} = $self->{probers}->[0]->get_confidence;
    return LOGICAL_HEBREW_NAME;
  } elsif ($modelsub < - MIN_MODEL_DISTANCE) {
    $self->{confidence} = $self->{probers}->[1]->get_confidence;
    return VISUAL_HEBREW_NAME;
  }

  if ($finalsub < 0) {
    $self->{confidence} = $self->{probers}->[1]->get_confidence;
    return VISUAL_HEBREW_NAME;
  }

  $self->{confidence} = $self->{probers}->[0]->get_confidence;
  return LOGICAL_HEBREW_NAME;
} # get_charset_name

sub get_confidence ($) {
  my $self = $_[0];
  $self->get_charset_name unless defined $self->{confidence};
  return $self->{confidence};
} # get_confidence

sub dump_status ($) {
  my $self = $_[0];
  printf "  HEB: %.3f [%s] (%s, L=%d V=%d)\n",
      $self->get_confidence,
      $self->get_charset_name,
      $self->{state},
      $self->{final_char_logical_score},
      $self->{final_char_visual_score};
  for (@{$self->{probers}}) {
    print "  ";
    $_->dump_status;
  }
} # dump_status

sub dump_status_for_json ($) {
  my $self = $_[0];
  return {
    type => ref $self,
    charset => $self->get_charset_name,
    #htmlrefs => !! resolve_latin1_refs
    confidence => $self->get_confidence,
    state => $self->{state},
    probers => [map { $_->dump_status_for_json } @{$self->{probers}}],
    logical => $self->{final_char_logical_score},
    visual => $self->{final_char_visual_score},
  };
} # dump_status_for_json

package Web::Encoding::UnivCharDet::CharsetProber::MBCSGroup;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub new ($$;%) {
  my $self = bless {}, shift;
  my $filter = shift;
  my %args = @_;

  if ($args{resolve_latin1_refs}) {
    $self->{probers} = [
      undef,
      undef,
      undef,
      $filter & Web::Encoding::UnivCharDet::Defs::FILTER_CHINESE_SIMPLIFIED
        ? Web::Encoding::UnivCharDet::CharsetProber::GB18030->new
              ($filter == Web::Encoding::UnivCharDet::Defs::FILTER_CHINESE_SIMPLIFIED)
        : undef,
      $filter & Web::Encoding::UnivCharDet::Defs::FILTER_KOREAN
        ? Web::Encoding::UnivCharDet::CharsetProber::EUCKR->new
              ($filter == Web::Encoding::UnivCharDet::Defs::FILTER_KOREAN)
        : undef,
      $filter & Web::Encoding::UnivCharDet::Defs::FILTER_CHINESE_TRADITIONAL
        ? Web::Encoding::UnivCharDet::CharsetProber::Big5->new
              ($filter == Web::Encoding::UnivCharDet::Defs::FILTER_CHINESE_TRADITIONAL)
        : undef,
      undef,
      undef,
    ];
  } else {
    $self->{probers} = [
      Web::Encoding::UnivCharDet::CharsetProber::UTF8->new,
      $filter & Web::Encoding::UnivCharDet::Defs::FILTER_JAPANESE
        ? Web::Encoding::UnivCharDet::CharsetProber::SJIS->new
              ($filter == Web::Encoding::UnivCharDet::Defs::FILTER_JAPANESE)
        : undef,
      $filter & Web::Encoding::UnivCharDet::Defs::FILTER_JAPANESE
        ? Web::Encoding::UnivCharDet::CharsetProber::EUCJP->new
              ($filter == Web::Encoding::UnivCharDet::Defs::FILTER_JAPANESE)
        : undef,
      $filter & Web::Encoding::UnivCharDet::Defs::FILTER_CHINESE_SIMPLIFIED
        ? Web::Encoding::UnivCharDet::CharsetProber::GB18030->new
              ($filter == Web::Encoding::UnivCharDet::Defs::FILTER_CHINESE_SIMPLIFIED)
        : undef,
      $filter & Web::Encoding::UnivCharDet::Defs::FILTER_KOREAN
        ? Web::Encoding::UnivCharDet::CharsetProber::EUCKR->new
              ($filter == Web::Encoding::UnivCharDet::Defs::FILTER_KOREAN)
        : undef,
      $filter & Web::Encoding::UnivCharDet::Defs::FILTER_CHINESE_TRADITIONAL
        ? Web::Encoding::UnivCharDet::CharsetProber::Big5->new
              ($filter == Web::Encoding::UnivCharDet::Defs::FILTER_CHINESE_TRADITIONAL)
        : undef,
      $filter & Web::Encoding::UnivCharDet::Defs::FILTER_CHINESE_TRADITIONAL
        ? Web::Encoding::UnivCharDet::CharsetProber::EUCTW->new
              ($filter == Web::Encoding::UnivCharDet::Defs::FILTER_CHINESE_TRADITIONAL)
        : undef,
      $filter & Web::Encoding::UnivCharDet::Defs::FILTER_KOREAN
        ? Web::Encoding::UnivCharDet::CharsetProber::Johab->new
              ($filter == Web::Encoding::UnivCharDet::Defs::FILTER_KOREAN)
        : undef,
    ];
  }

  $self->reset (%args);
  return $self;
} # new

sub reset ($;%) {
  my ($self, %args) = @_;
  $self->{active_num} = 0;
  for (@{$self->{probers}}) {
    next unless $_;
    $_->reset;
    $self->{active_num}++;
  }
  $self->{best_guess} = -1;
  $self->{state} = 'detecting';
  $self->{keep_next} = 0;
  delete $self->{has_high};
  $self->{resolve_latin1_refs} = $args{resolve_latin1_refs};
} # reset

sub get_charset_name ($) {
  my $self = $_[0];
  if ($self->{best_guess} == -1) {
    $self->get_confidence;
    if ($self->{best_guess} == -1) {
      $self->{best_guess} = 0;
    }
  }
  my $prober = $self->{probers}->[$self->{best_guess}];
  return $prober->get_charset_name if defined $prober;
  return undef;
} # get_charset_name

sub handle_data ($$) {
  my $self = $_[0];

  my $start = 0;
  my $keep_next = $self->{keep_next};

  for my $pos (0..((length $_[1]) - 1)) {
    if (0x80 & ord substr $_[1], $pos, 1) {
      unless ($keep_next) {
        $start = $pos;
      }
      $keep_next = 2;
    } elsif ($keep_next) {
      if (--$keep_next == 0) {
        $self->{has_high} = 1;
        for my $i (0..$#{$self->{probers}}) {
          local $_ = $self->{probers}->[$i];
          next unless $_;
          my $st = $_->handle_data ($_[1], $start, $pos + 1,
                                    $start || !$self->{keep_next});
          if ($st eq 'found it') {
            $self->{best_guess} = $i;
            return $self->{state} = 'found it';
          }
        }
      }
    }
  } # $pos

  if ($keep_next) {
    $self->{has_high} = 1;
    for my $i (0..$#{$self->{probers}}) {
      local $_ = $self->{probers}->[$i];
      next unless $_;
      my $st = $_->handle_data ($_[1], $start, undef,
                                $start || !$self->{keep_next});
      if ($st eq 'found it') {
        $self->{best_guess} = $i;
        return $self->{state} = 'found it';
      }
    }
  }
  $self->{keep_next} = $keep_next;
  return $self->{state};
} # handle_data

sub handle_eof ($) {
  my $self = $_[0];
  if ($self->{state} eq 'detecting') {
    for (@{$self->{probers}}) {
      $_->handle_eof if defined $_;
    }
  }
} # handle_eof

sub get_confidence ($) {
  my $self = $_[0];
  if (not $self->{has_high}) {
    return 0.01;
  } elsif ($self->{state} eq 'found it') {
    return 0.99;
  } elsif ($self->{state} eq 'not me') {
    return 0.01;
  } else {
    my $best_conf = 0.0;
    my $second_conf = 0.0;
    my $second_i = -1;
    for my $i (0..$#{$self->{probers}}) {
      local $_ = $self->{probers}->[$i];
      next unless $_;
      my $cf = $_->get_confidence;
      if ($second_conf < $cf) {
        if ($_->got_min_data) {
          $best_conf = $second_conf = $cf;
          $self->{best_guess} = $second_i = $i;
        } else {
          $second_conf = $cf;
          $second_i = $i;
        }
      } elsif ($best_conf < $cf) { # < $second_cf
        if ($_->got_min_data) {
          $best_conf = $cf;
          $self->{best_guess} = $i;
        }
      }
    } # $i
    if ($best_conf == 0.0 and $second_conf) {
      $self->{best_guess} = $second_i;
      $best_conf = $second_conf * 0.6;
    } 
    return $best_conf;
  }
} # get_confidence

my @ProberName = qw(UTF8 SJIS EUCJP GB18030 EUCKR Big5 EUCTW Johab);
sub dump_status ($) {
  my $self = $_[0];
  $self->get_confidence;
  printf " MBCS [%s] %s [%s] (%s)\n",
      $self->get_charset_name // '',
      $self->{resolve_latin1_refs} ? 'htmlrefs' : '',
      $self->get_confidence,
      $self->{state};
  for my $i (0..$#{$self->{probers}}) {
    local $_ = $self->{probers}->[$i];
    unless (defined $_) {
      printf "  MBCS inactive: [%s] (confidence is too low).\n", $ProberName[$i];
    } else {
      print "  ";
      $_->dump_status;
    }
  }
} # dump_status

sub dump_status_for_json ($) {
  my $self = $_[0];
  return {
    type => $self->get_charset_name,
    charset => $self->get_charset_name,
    state => $self->{state},
    htmlrefs => !!$self->{resolve_latin1_refs},
    confidence => $self->get_confidence,
    probers => [map { $_->dump_status_for_json } grep { defined $_ } @{$self->{probers}}],
  };
} # dump_status_for_json

package Web::Encoding::UnivCharDet::CharsetProber::UTF8;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub new ($;%) {
  my $self = bless {}, $_[0];
  $self->{coding_sm} = Web::Encoding::UnivCharDet::CodingStateMachine->new
      (Web::Encoding::UnivCharDet::Defs::UTF8SMModel);
  $self->reset;
  return $self;
} # new

sub reset ($;%) {
  my $self = $_[0];
  $self->{coding_sm}->reset;
  $self->{num_of_mb_char} = 0;
  $self->{state} = 'detecting';
} # reset

sub get_charset_name ($) { 'utf-8' }

sub handle_data ($$$;$) {
  my $self = $_[0];
  my $start_pos = $_[2] || 0;
  my $limit_pos = defined $_[3] ? $_[3] : length $_[1];
  for my $i ($start_pos..($limit_pos - 1)) {
    my $coding_state = $self->{coding_sm}->next_state (substr $_[1], $i, 1);
    if ($coding_state == Web::Encoding::UnivCharDet::Defs::eItsMe) {
      $self->{state} = 'found it';
      last;
    } elsif ($coding_state == Web::Encoding::UnivCharDet::Defs::eStart) {
      if ($self->{coding_sm}->get_current_char_len >= 2) {
        $self->{num_of_mb_char}++;
      }
    }
  }
  if ($self->{state} eq 'detecting') {
    if ($self->{coding_sm}->{error_count}) {
      $self->{state} = 'not me';
    } elsif ($self->get_confidence > Web::Encoding::UnivCharDet::Defs::SHORTCUT_THRESHOLD) {
      $self->{state} = 'found it';
    }
  }
  return $self->{state};
} # handle_data

sub ONE_CHAR_PROB () { 0.50 }

sub get_confidence ($) {
  my $self = $_[0];
  if ($self->{state} eq 'not me') {
    return 0.1;
  } elsif ($self->{num_of_mb_char} < 6) {
    my $unlike = 0.99;
    $unlike *= ONE_CHAR_PROB for 1..$self->{num_of_mb_char};
    return 1.0 - $unlike;
  } else {
    return 0.99;
  }
} # get_confidence

sub got_min_data ($) { $_[0]->{num_of_mb_char} > 6 }

sub dump_status ($) {
  my $self = $_[0];
  printf "%s [%s] (%s, e=%s, %s)\n",
      $self->get_confidence,
      $self->get_charset_name,
      $self->{state},
      $self->{coding_sm}->{error_count},
      $self->got_min_data ? 'min' : '_';
} # dump_status

sub dump_status_for_json ($) {
  my $self = $_[0];
  return {
    type => $self->get_charset_name,
    charset => $self->get_charset_name,
    # htmlrefs => !! resolve_latin1_refs
    confidence => $self->get_confidence,
    error_count => $self->{coding_sm}->{error_count},
    got_min_data => $self->got_min_data,
  };
} # dump_status_for_json

package Web::Encoding::UnivCharDet::CharsetProber::MBCS;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub new ($$;%) {
  my $self = bless {}, $_[0];
  $self->{is_preferred_lang} = $_[1];
  $self->{coding_sm} = Web::Encoding::UnivCharDet::CodingStateMachine->new
      ($self->_smmodel);
  $self->reset;
  $self->_init;
  return $self;
} # new

sub NUM_OF_CATEGORY () { 8 }
sub MINIMUM_DATA_THRESHOLD () { 4 }
sub ENOUGH_REL_THRESHOLD () { 100 }
sub MAX_REL_THRESHOLD () { 1000 }

#sub MINIMUM_DATA_THRESHOLD () { 4 }
sub ENOUGH_DATA_THRESHOLD () { 1024 }

sub reset ($;%) {
  my $self = $_[0];
  $self->{coding_sm}->reset;
  $self->{state} = 'detecting';
  $self->{last_char} = "\x00\x00";

  $self->{current_word_length} = 0;
  $self->{avg_word_length} = 0;
  $self->{latin1_state} = 1;
  $self->{latin1_count} = 0;
  $self->{context_state} = 0;
  $self->{kana_count} = 0;
  $self->{non_kana_count} = 0;
  $self->{cs1_count} = 0;
  $self->{boost_count} = 0;
  
  $self->{data_threshold} = $self->{is_preferred_lang} ? 0 : MINIMUM_DATA_THRESHOLD;
  
  ## CharDistribAnalysis
  $self->{total_chars} = 0;
  $self->{freq_chars} = 0;

  ## ContextAnalysis
  $self->{total_rel} = 0;
  $self->{rel_sample}->[$_] = 0 for 0..(NUM_OF_CATEGORY - 1);
  $self->{need_to_skip_char_num} = 0;
  $self->{last_char_order} = -1;
  $self->{context_done} = 0;
  $self->{signature_count} = 0;
} # reset

sub handle_data ($$$;$$) {
  my $self = $_[0];
  my $start_pos = $_[2] || 0;
  my $limit_pos = defined $_[3] ? $_[3] : length $_[1];
  $self->{context_state} = 1 if $_[4];
      # 0: Not a start of 8-bit chunk
      # 1: Start of 8-bit chunk
      # 2: After delimiter
  
  for my $i ($start_pos..($limit_pos - 1)) {
    my $c = substr $_[1], $i, 1;
    my $coding_state = $self->{coding_sm}->next_state ($c);
    if ($coding_state == Web::Encoding::UnivCharDet::Defs::eItsMe) {
      $self->{state} = 'found it';
      last;
    } elsif ($coding_state == Web::Encoding::UnivCharDet::Defs::eStart) {
      my $char_len = $self->{coding_sm}->get_current_char_len;
      ## $char_len is 2 for GB 18030 four-byte characters
      if ($i == $start_pos) {
        substr ($self->{last_char}, 1, 0) = $c;
        $self->_handle_one_char ($self->{last_char}, 2-$char_len, $char_len);
      } else {
        $self->_handle_one_char ($_[1], $i+1-$char_len, $char_len);
      }
    }
  }

  ## XXX broken for GB 18030 four-byte characters
  substr ($self->{last_char}, 0, 1) = substr $_[1], $limit_pos - 1, 1;

  if ($self->{state} eq 'detecting') {
    if ($self->{coding_sm}->{error_count}) {
      if ($self->{coding_sm}->{error_count} > 10) {
        $self->{state} = 'not me';
      }
    } elsif ($self->distrib_got_enough_data and
             $self->get_confidence > Web::Encoding::UnivCharDet::Defs::SHORTCUT_THRESHOLD) {
      $self->{state} = 'found it';
    } else {
      if ($self->{boost_count} > 10) {
        $self->{state} = 'found it';
      }
    }
  }
  return $self->{state};
} # handle_data

sub handle_eof ($) {
  my $self = $_[0];
  $self->{coding_sm}->handle_eof if $self->{state} eq 'detecting';
} # handle_eof

sub get_confidence ($) {
  my $self = $_[0];
  if ($self->{state} eq 'not me') {
    return 0.01;
  }
  my $conf = $self->distrib_get_confidence;
  $conf *= exp(-0.3 * $self->{coding_sm}->{error_count});
  if ($conf < 0.5 and not $self->{coding_sm}->{error_count}) {
    $conf = 0.5;
  }

  if ($self->{boost_count}) {
    my $k = 1.2;
    my $boost_factor = 1 - exp(-$k * $self->{boost_count});
    $conf += (1 - $conf) * $boost_factor;
    $conf = 1 if $conf > 1;  
  }

  return $conf;
} # get_confidence

sub got_min_data ($) {
  return (
    not ($_[0]->{freq_chars} <= $_[0]->{data_threshold}) or
    $_[0]->{signature_count} or
    $_[0]->{boost_count}
  );
} # got_min_data

sub _handle_one_char ($$$$) {
  my $self = $_[0];
  # $self, $str, $offset, $len

  my $order = $_[3] == 2 ? $self->distrib_get_order ($_[1], $_[2]) : -1;
  if ($order >= 0) {
    $self->{total_chars}++;
    if ($order < @{$self->{char_to_freq_order}}) {
      if (512 > $self->{char_to_freq_order}->[$order]) {
        $self->{freq_chars}++;
      }
    }
    $self->{context_state} = 0;
  } elsif ($order == -2 and $self->{context_state} == 1) {
    $self->{context_state} = 2;
  } elsif ($self->{context_state} == 2 and "\x20" eq substr $_[1], $_[2], 1) {
    $self->{boost_count}++;
    $self->{context_state} = 0;
  } else {
    $self->{context_state} = 0;
  }
} # _handle_one_char

## CharDistribAnalysis

sub SURE_YES () { 0.99 }
sub SURE_NO () { 0.01 }

sub distrib_get_order ($$$) { -1 }

sub distrib_get_confidence ($) {
  my $self = $_[0];
  if ($self->{total_chars} <= 0 #or
      #$self->{freq_chars} <= $self->{data_threshold}
  ) {
    return SURE_NO;
  } elsif ($self->{total_chars} != $self->{freq_chars}) {
    my $r = $self->{freq_chars} / (($self->{total_chars} - $self->{freq_chars}) * $self->{typical_distribution_ratio});
    if ($r < 0.98) {
      return $r;
    } else {
      my $x = $r - 0.98;
      my $adjusted = 0.98 + (1 - exp(-5 * $x)) * (0.99 - 0.98);
      $adjusted = 0.99 if $adjusted > 0.99;
      return $adjusted;
    }
  } else {
    return SURE_YES;
  }
} # distrib_get_confidence

sub distrib_got_enough_data ($) {
  return $_[0]->{total_chars} > ENOUGH_DATA_THRESHOLD;
} # distrib_got_enough_data

## ContextAnalysis

sub DONT_KNOW () { -1 }

sub context_get_confidence ($) {
  my $self = $_[0];
  if ($self->{total_rel} > $self->{data_threshold}) {
    return (($self->{total_rel} - $self->{rel_sample}->[0]) / $self->{total_rel});
  } elsif ($self->{kana_count} / ($self->{kana_count} + $self->{non_kana_count} + 1e-7) > 0.8) {
    ## Short string of Kana letters
    return 0.5;
  } else {
    return DONT_KNOW;
  }
} # context_get_confidence

sub context_got_enough_data ($) {
  return $_[0]->{total_rel} > ENOUGH_REL_THRESHOLD;
} # context_got_enough_data

##

sub dump_status ($) {
  my $self = $_[0];
  printf "%.4f [%s] (%s, e=%s, %s, l=%d, +%d, %s)\n",
      $self->get_confidence,
      $self->get_charset_name,
      $self->{state},
      $self->{coding_sm}->{error_count},
      $self->_distrib_dump_status,
      $self->{avg_word_length},
      $self->{boost_count},
      $self->got_min_data ? 'min' : '_';
} # dump_status

sub dump_status_for_json ($) {
  my $self = $_[0];
  return {
    type => (ref $self),
    charset => $self->get_charset_name,
    confidence => $self->get_confidence,
    error_count => $self->{coding_sm}->{error_count},
    distribution_analyser => $self->distrib_dump_status_for_json,
    avg_word_length => $self->{avg_word_length},
    boost_count => $self->{boost_count},
    got_min_data => $self->got_min_data,
  };
} # dump_status_for_json

sub _distrib_dump_status ($) {
  my $self = $_[0];
  return sprintf "%d / %d (%s)",
      $self->{freq_chars},
      $self->{total_chars},
      $self->distrib_got_enough_data ? 'enough' : '';
} # _distrib_dump_status

sub distrib_dump_status_for_json ($) {
  my $self = $_[0];
  return {
    freq_chars => $self->{freq_chars},
    total_chars => $self->{total_chars},
    got_enought_data => !! $self->distrib_got_enough_data,
  };
} # distrib_dump_status_for_json


package Web::Encoding::UnivCharDet::CharsetProber::GB18030;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber::MBCS);
our $VERSION = '1.0';

sub _smmodel ($) { Web::Encoding::UnivCharDet::Defs::GB18030SMModel }
sub get_charset_name ($) { 'gb18030' }

sub _init ($) {
  $_[0]->{char_to_freq_order} = Web::Encoding::UnivCharDet::Defs::GB2312CharToFreqOrder;
  $_[0]->{typical_distribution_ratio} = Web::Encoding::UnivCharDet::Defs::GB2312_TYPICAL_DISTRIBUTION_RATIO;
} # _init

sub _handle_one_char ($$$$) {
  my $self = $_[0];
  # $self, $str, $offset, $len

  my $order = $_[3] == 2 ? $self->distrib_get_order ($_[1], $_[2]) : -1;
  if ($order >= 0) {
    $self->{total_chars}++;
    if ($order < @{$self->{char_to_freq_order}}) {
      if (512 > $self->{char_to_freq_order}->[$order]) {
        $self->{freq_chars}++;
      }
    }
  }

  ## 4-byte character
  if ($_[3] == 2 and substr ($_[1], $_[2]+1, 1) =~ /[\x30-\x39]/) {
    $self->{boost_count}++;
  }
} # _handle_one_char

sub distrib_get_order ($$$) {
  if ((ord substr $_[1], $_[2], 1) >= 0xB0) {
    return 94 * ((ord substr $_[1], $_[2], 1) - 0xB0) + (ord substr $_[1], $_[2] + 1, 1) - 0xA1;
  } else {
    return -1;
  }
} # distrib_get_order

package Web::Encoding::UnivCharDet::CharsetProber::Big5;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber::MBCS);
our $VERSION = '1.0';

sub _smmodel ($) { Web::Encoding::UnivCharDet::Defs::Big5SMModel }
sub get_charset_name ($) { 'big5' }

sub _init ($) {
  $_[0]->{char_to_freq_order} = Web::Encoding::UnivCharDet::Defs::Big5CharToFreqOrder;
  $_[0]->{typical_distribution_ratio} = Web::Encoding::UnivCharDet::Defs::BIG5_TYPICAL_DISTRIBUTION_RATIO;
} # _init

sub distrib_get_order ($$$) {
  my $c1 = ord substr $_[1], $_[2], 1;
  my $c2 = ord substr $_[1], $_[2] + 1, 1;
  if ($c1 >= 0xA4) {
    if ($c2 >= 0xA1) {
      return 157 * ($c1 - 0xA4) + ($c2 - 0xA1) + 63;
    } else {
      return 157 * ($c1 - 0xA4) + ($c2 - 0x40);
    }
  } else {
    if ($c1 == 0xA1 and $c2 == 0x56) {
      return -2; # separator

      ## Big5 0xA156 is a dash and is sometimes used to separate
      ## components of file names.  0xA1 is a reversed exclamation
      ## mark in windows-1252 and can be used at the start of sentence
      ## in some language but is expected to be followed by a capital
      ## letter.  0xA1 is a halfwidth full stop in Shift_JIS is
      ## unlikely used at the start.  0xA156 is unused in gb18030.
      ## 0xA156 is a hangul syllable but is unlikely used as a
      ## singleton.  We use an ASCII, 0xA1, 0x56, 0x20 sequence as an
      ## implication of Big5.
    } else {
      return -1;
    }
  }
} # distrib_get_order

package Web::Encoding::UnivCharDet::CharsetProber::EUCTW;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber::MBCS);
our $VERSION = '1.0';

sub _smmodel ($) { Web::Encoding::UnivCharDet::Defs::EUCTWSMModel }
sub get_charset_name ($) { 'x-euc-tw' }

sub _init ($) {
  $_[0]->{char_to_freq_order} = Web::Encoding::UnivCharDet::Defs::EUCTWCharToFreqOrder;
  $_[0]->{typical_distribution_ratio} = Web::Encoding::UnivCharDet::Defs::EUCTW_TYPICAL_DISTRIBUTION_RATIO;
} # _init

sub distrib_get_order ($$$) {
  if ((ord substr $_[1], $_[2], 1) >= 0xC4) {
    return 94 * ((ord substr $_[1], $_[2], 1) - 0xC4) + (ord substr $_[1], $_[2] + 1, 1) - 0xA1;
  } else {
    return -1;
  }
} # distrib_get_order

package Web::Encoding::UnivCharDet::CharsetProber::EUCKR;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber::MBCS);
our $VERSION = '1.0';

sub _smmodel ($) { Web::Encoding::UnivCharDet::Defs::EUCKRSMModel }
sub get_charset_name ($) { 'euc-kr' }

sub _init ($) {
  $_[0]->{char_to_freq_order} = Web::Encoding::UnivCharDet::Defs::EUCKRCharToFreqOrder;
  $_[0]->{typical_distribution_ratio} = Web::Encoding::UnivCharDet::Defs::EUCKR_TYPICAL_DISTRIBUTION_RATIO;
} # _init

sub distrib_get_order ($$$) {
  my $c1 = ord substr $_[1], $_[2], 1;
  if ($c1 >= 0xB0) {
    my $c2 = ord substr $_[1], $_[2] + 1, 1;
    if ($c2 >= 0xA1) {
      $_[0]->{cs1_count}++;
      return 94 * ($c1 - 0xB0) + ($c2 - 0xA1);
    } else {
      return -1;
    }
  } else {
    return -1;
  }
} # distrib_get_order

sub get_confidence ($) {
  my $self = $_[0];
  if ($self->{state} eq 'not me') {
    return 0.01;
  }
  
  my $conf = $self->distrib_get_confidence;
  $conf *= exp(-0.3 * $self->{coding_sm}->{error_count});
  if ($conf < 0.5 and not $self->{coding_sm}->{error_count}) {
    $conf = 0.5;
  }

  ## No KS X 1001 hangul syllables
  unless ($self->{cs1_count}) {
    $conf *= 0.7;
  }

  return $conf;
} # get_confidence

package Web::Encoding::UnivCharDet::CharsetProber::Johab;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber::MBCS);
our $VERSION = '1.0';

sub _smmodel ($) { Web::Encoding::UnivCharDet::Defs::JohabSMModel }
sub get_charset_name ($) { 'x-johab' }

sub _init ($) {
  $_[0]->{char_to_freq_order} = Web::Encoding::UnivCharDet::Defs::EUCKRCharToFreqOrder;
  $_[0]->{typical_distribution_ratio} = Web::Encoding::UnivCharDet::Defs::EUCKR_TYPICAL_DISTRIBUTION_RATIO;
} # _init

sub handle_data ($$$;$) {
  my $self = $_[0];
  my $start_pos = $_[2] || 0;
  my $limit_pos = defined $_[3] ? $_[3] : length $_[1];
  for my $i ($start_pos..($limit_pos - 1)) {
    my $c = ord substr $_[1], $i, 1;
    my $coding_state = $self->{coding_sm}->next_state (substr $_[1], $i, 1);
    # eItsMe is used for other purpose.
    if ($coding_state == Web::Encoding::UnivCharDet::Defs::eStart) {
      my $char_len = $self->{coding_sm}->get_current_char_len;
      my $is_sep = 0;
      if ($i == $start_pos) {
        substr ($self->{last_char}, 1, 1) = substr $_[1], $start_pos, 1;
        $self->_handle_one_char ($self->{last_char}, 2-$char_len, $char_len);
        $is_sep = 1 unless $self->{last_char} =~ /[\x84-\xD3].$/;
      } else {
        $self->_handle_one_char ($_[1], $i+1-$char_len, $char_len);
        $is_sep = 1 unless substr ($_[1], $i+1-$char_len, 1) =~ /^[\x84-\xD3]/;
      }
      if ($is_sep) {
        if ($self->{current_word_length}) {
          $self->{avg_word_length} = 0.9 * $self->{avg_word_length} + 0.1 * $self->{current_word_length};
          $self->{current_word_length} = 0;
        }
      } else {
        $self->{current_word_length}++;
      }
    }
  }

  substr ($self->{last_char}, 0, 1) = substr $_[1], $limit_pos - 1, 1;

  if ($self->{state} eq 'detecting') {
    if ($self->{coding_sm}->{error_count}) {
      if ($self->{coding_sm}->{error_count} > 10) {
        $self->{state} = 'not me';
      }
    } elsif ($self->distrib_got_enough_data and
             $self->get_confidence > Web::Encoding::UnivCharDet::Defs::SHORTCUT_THRESHOLD) {
      $self->{state} = 'found it';
    }
  }
  
  return $self->{state};
} # handle_data

sub get_confidence ($) {
  my $self = $_[0];
  if ($self->{state} eq 'not me') {
    return 0.01;
  }
  my $conf = $self->distrib_get_confidence;
  if ($conf < 0.5 and not $self->{coding_sm}->{error_count}) {
    $conf = 0.5;
  }

  {
    my $avg = $self->{avg_word_length};
    my $mu  = 3.0;
    my $sigma = 1.0;
    my $diff = $avg - $mu;
    my $score = exp( - ($diff * $diff) / (2 * $sigma * $sigma) );

    my $factor = 0.7 + 0.3 * $score;
    $conf *= $factor;
    $conf = 0.1 if $conf < 0.1;
  }
  
  return $conf;
} # get_confidence

sub distrib_get_order ($$$) {
  my $c = ord substr $_[1], $_[2], 1;
  if (0x88 <= $c and $c <= 0xD3) {
    return Web::Encoding::UnivCharDet::Defs::johab_to_euckr $c, ord substr $_[1], $_[2] + 1, 1;
  } else {
    return -1;
  }
} # distrib_get_order


package Web::Encoding::UnivCharDet::CharsetProber::EUCJP;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber::MBCS);
our $VERSION = '1.0';

sub _smmodel ($) { Web::Encoding::UnivCharDet::Defs::EUCJPSMModel }
sub get_charset_name ($) { 'euc-jp' }

sub _init ($) {
  $_[0]->{char_to_freq_order} = Web::Encoding::UnivCharDet::Defs::JISCharToFreqOrder;
  $_[0]->{typical_distribution_ratio} = Web::Encoding::UnivCharDet::Defs::JIS_TYPICAL_DISTRIBUTION_RATIO;
} # _init

sub handle_data ($$$;$) {
  my $self = $_[0];
  my $start_pos = $_[2] || 0;
  my $limit_pos = defined $_[3] ? $_[3] : length $_[1];
  for my $i ($start_pos..($limit_pos - 1)) {
    my $coding_state = $self->{coding_sm}->next_state (substr $_[1], $i, 1);
    if ($coding_state == Web::Encoding::UnivCharDet::Defs::eItsMe) {
      $self->{state} = 'found it';
      last;
    } elsif ($coding_state == Web::Encoding::UnivCharDet::Defs::eStart) {
      my $char_len = $self->{coding_sm}->get_current_char_len;
      if ($i == $start_pos) {
        substr ($self->{last_char}, 1, 1) = substr $_[1], $start_pos, 1;
        $self->_handle_one_char ($self->{last_char}, 2-$char_len, $char_len);
      } else {
        $self->_handle_one_char ($_[1], $i+1-$char_len, $char_len);
      }
    }
  }

  ## XXX Broken for 3-byte characters
  substr ($self->{last_char}, 0, 1) = substr $_[1], $limit_pos - 1, 1;

  if ($self->{state} eq 'detecting') {
    if ($self->{coding_sm}->{error_count}) {
      if ($self->{coding_sm}->{error_count} > 10) {
        $self->{state} = 'not me';
      }
    } elsif ($self->context_got_enough_data and
             $self->get_confidence > Web::Encoding::UnivCharDet::Defs::SHORTCUT_THRESHOLD) {
      $self->{state} = 'found it';
    }
  }
  
  return $self->{state};
} # handle_data

sub _handle_one_char ($$$$) {
  my $self = $_[0];
  # $self, $str, $offset, $len

  my $order = $_[3] == 2 ? $self->distrib_get_order ($_[1], $_[2]) : -1;
  if ($order >= 0) {
    $self->{total_chars}++;
    if ($order < @{$self->{char_to_freq_order}}) {
      if (512 > $self->{char_to_freq_order}->[$order]) {
        $self->{freq_chars}++;
      }
    }
  }

  if ($self->{total_rel} > Web::Encoding::UnivCharDet::CharsetProber::MBCS::MAX_REL_THRESHOLD) {
    $self->{context_done} = 1;
  }
  unless ($self->{context_done}) {
    my $order = -1;
    if ($_[3] == 2) {
      $order = $self->context_get_order2 ($_[1], $_[2]);
    } elsif ($_[3] == 3) { # EUC-JP CS3
      my $f = ord substr $_[1], $_[2]+1, 1;
      if ($self->{context_state} == 0 and
          ($f == 0xA2 or $f == 0xA6 or $f == 0xA7 or $f == 0xA9 or
           $f == 0xAA or $f == 0xAB)) {
        $self->{context_state} = 3;
        ## If a 3-byte sequence of 0x8E GR GR, where GR GR is an
        ## alphabetical character of JIS X 0212, is sorounded by ASCII
        ## characters, it is likely an EUC-JP file that contains
        ## European texts.
      } else {
        $self->{context_state} = 2;
      }
    } else {
      if ($self->{context_state} == 3) {
        $self->{boost_count}++;
      }
      $self->{context_state} = 0;
      ## 0 : Initial; After single byte character
      ## 1 : After EUC-JP two-character signature first half
      ## 2 : After other EUC-JP double or triple byte character
      ## 3 : After 0 then triple byte alphabet character
    }
  
    if ($order != -1 and $self->{last_char_order} != -1) {
      $self->{total_rel}++;
      $self->{rel_sample}->[Web::Encoding::UnivCharDet::Defs::jp2CharContext->[$self->{last_char_order}]->[$order]]++;
    }
    $self->{last_char_order} = $order;
  }
} # _handle_one_char

sub distrib_get_order ($$$) {
  if ((ord substr $_[1], $_[2], 1) >= 0xA0) {
    return 94 * ((ord substr $_[1], $_[2], 1) - 0xA1) + (ord substr $_[1], $_[2] + 1, 1) - 0xA1;
  } else {
    return -1;
  }
} # distrib_get_order

sub context_get_order2 ($$$) {
  my $self = $_[0];
  my $f = ord substr $_[1], $_[2], 1;
  my $s = ord substr $_[1], $_[2] + 1, 1;
  
  if ($f == 0xA4 and ($s >= 0xA1 and $s <= 0xF3)) {
    $self->{context_state} = 2;
    $self->{kana_count}++;
    return $s - 0xA1;
  }

  if ($f == 0xA5 and ($s >= 0xA1 and $s <= 0xF3)) {
    $self->{kana_count}++;
  } else {
    $self->{non_kana_count}++;
  }

  ## EUC-JP signatures advocated by the most popular portal site and
  ## the most famous HTML reference site in early-Heisei days (1990s)
  ## of Japan:
  ##   <https://web.archive.org/web/20030202085121/http://docs.yahoo.co.jp/docs/help/mojibake/sonota.html>
  ##   <https://www.tohoho-web.com/wwwxx005.htm#spell-character>
  ##   <https://wiki.suikawiki.org/n/%E6%96%87%E5%AD%97%E3%82%B3%E3%83%BC%E3%83%89%E8%87%AA%E5%8B%95%E5%88%A4%E5%88%A5#section-%E6%96%87%E5%AD%97%E3%82%B3%E3%83%BC%E3%83%89%E3%81%AE%E6%B1%BA%E5%AE%9A%E2%80%A8%E3%83%90%E3%82%A4%E3%83%88%E5%88%97%E7%AD%89%E3%81%8B%E3%82%89%E3%81%AE%E6%8E%A8%E5%AE%9A%E2%80%A8%E5%88%A4%E5%AE%9A%E5%99%A8%E3%82%92%E6%84%8F%E8%AD%98%E3%81%97%E3%81%9F%E8%91%97%E8%80%85%E3%81%AB%E3%82%88%E3%82%8B%E8%A8%98%E8%BF%B0>.
  if (($f == 0xFD and $s == 0xFE) or # 0xFDFE : an unassigned code point
      ($f == 0xF3 and $s == 0xFE) or
      #($f == 0xB9 and $s == 0xA7) or # EUC "孝", SJIS "ｹｧ" (ｹｧ could be part of slang or something, so not a good signature)
      ($f == 0xEB and $s == 0xFD) or
      ($f == 0xC4 and $s == 0xF0) or
      ($f == 0xF3 and $s == 0xFD)) {
    $self->{signature_count}++;
    $self->{context_state} = 2;
  } elsif ($f == 0xC8 and $s == 0xFE) {
    $self->{context_state} = 1;
  } elsif ($self->{context_state} == 1 and $f == 0xC6 and $s == 0xFD) {
    $self->{signature_count}++;
    $self->{context_state} = 2;
  } else {
    $self->{context_state} = 2;
  }
  
  return -1;
} # context_get_order2

sub get_confidence ($) {
  my $self = $_[0];
  if ($self->{state} eq 'not me') {
    return 0.01;
  }
  my $contxt_cf = $self->context_get_confidence;
  my $distrib_cf = $self->distrib_get_confidence;
  my $conf = $contxt_cf > $distrib_cf ? $contxt_cf : $distrib_cf;
  $conf = $distrib_cf * 0.6 if $contxt_cf == -1;

  if ($conf < 0.5 and not $self->{coding_sm}->{error_count}) {
    $conf = 0.5;
  }

  if ($self->{signature_count}) {
    my $k = 1.6;
    my $boost_factor = 1 - exp(-$k * $self->{signature_count});
    $conf += (1 - $conf) * $boost_factor;
    $conf = 1 if $conf > 1;  
  }

  if ($self->{boost_count}) { ## EUC CS3
    my $k = 1.2;
    my $boost_factor = 1 - exp(-$k * $self->{boost_count});
    $conf += (1 - $conf) * $boost_factor;
    $conf = 1 if $conf > 1;  
  }
  
  return $conf;
} # get_confidence

sub dump_status ($) {
  my $self = $_[0];
  printf "%s [%s] (%s, e=%s, d: %s %s, x: %s, sig=%d, +%d, %s)\n",
      $self->get_confidence,
      $self->get_charset_name,
      $self->{state},
      $self->{coding_sm}->{error_count},
      $self->distrib_get_confidence,
      $self->_distrib_dump_status,
      $self->context_get_confidence,
      $self->{signature_count},
      $self->{boost_count},
      $self->got_min_data ? 'min' : '_';
} # dump_status

sub dump_status_for_json ($) {
  my $self = $_[0];
  return {
    type => $self->get_charset_name,
    charset => $self->get_charset_name,
    confidence => $self->get_confidence,
    error_count => $self->{coding_sm}->{error_count},
    distribution_analyser => $self->distrib_dump_status_for_json,
    context_confidence => $self->context_get_confidence,
    signature_count => $self->{signature_count},
    boost_count => $self->{boostcount},
    got_min_data => !! $self->got_min_data,
  };
} # dump_status_for_json

package Web::Encoding::UnivCharDet::CharsetProber::SJIS;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber::MBCS);
our $VERSION = '1.0';

sub _smmodel ($) { Web::Encoding::UnivCharDet::Defs::SJISSMModel }
sub get_charset_name ($) { 'shift_jis' }

sub _init ($) {
  $_[0]->{char_to_freq_order} = Web::Encoding::UnivCharDet::Defs::JISCharToFreqOrder;
  $_[0]->{typical_distribution_ratio} = Web::Encoding::UnivCharDet::Defs::JIS_TYPICAL_DISTRIBUTION_RATIO;
} # _init

sub reset ($) {
  my $self = $_[0];
  $self->SUPER::reset;
  $self->{probers} = [];
  $self->{probers}->[0] = Web::Encoding::UnivCharDet::CharsetProber::SBCS->new
      ($Web::Encoding::UnivCharDet::Defs::Jisx0201KatakanaModel,
       tokenized => 1);
  delete $self->{hwword};
} # reset


my $Latin1Type = [
  0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 0, 0,
  0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  1, 0, 1, 0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0, 0, 0,
  3, 3, 3, 3, 3, 3, 3, 3, 3, 3, 0, 0, 1, 0, 1, 0,
  0, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1, 0, 1, 0, 0,
  0, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4,
  4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 4, 1, 0, 1, 0, 0,
  0, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
  8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
  0, 7, 0, 7, 7, 0, 6, 5, 5, 2, 5, 5, 5, 5, 5, 5,
  6, 6, 6, 6, 6, 6, 6, 9, 6, 6, 6, 6, 6, 6, 6, 6,
  6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6,
  6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 5, 5,
  8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8,
  8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 8, 0, 0, 0,
];

sub handle_data ($$$;$) {
  my $self = $_[0];
  my $start_pos = $_[2] || 0;
  my $limit_pos = defined $_[3] ? $_[3] : length $_[1];
  for my $i ($start_pos..($limit_pos - 1)) {
    my $c = substr $_[1], $i, 1;
    my $cc = ord $c;
    my $coding_state = $self->{coding_sm}->next_state ($c);
    if ($coding_state == Web::Encoding::UnivCharDet::Defs::eItsMe) {
      $self->{state} = 'found it';
      last;
    } elsif ($coding_state == Web::Encoding::UnivCharDet::Defs::eStart) {
      my $char_len = $self->{coding_sm}->get_current_char_len;
      if ($i == $start_pos) {
        substr ($self->{last_char}, 1, 1) = substr $_[1], $start_pos, 1;
        $self->_handle_one_char ($self->{last_char}, 2-$char_len, $char_len);
      } else {
        $self->_handle_one_char ($_[1], $i+1-$char_len, $char_len);
      }
      undef $c if $char_len > 1;
    } else {
      undef $c;
    }

    ## Run the prober to test whether runs of halfwidth katakanas are
    ## meaningful Japanese text or not.
    if (defined $c and $cc > 0xA0) {
      if (defined $self->{hwword}) {
        $self->{hwword} .= $c;
      } else {
        $self->{hwword} = $c;
      }
      if (30 < length $self->{hwword}) {
        if ($self->{hwword} =~ /[^\x00-\x7F]/) {
          $self->{probers}->[0]->handle_data (delete $self->{hwword});
        } else {
          delete $self->{hwword};
        }
      }
    } else {
      if (defined $self->{hwword}) {
        if ($self->{hwword} =~ /[^\x00-\x7F]/) {
          $self->{hwword} .= ' ';
          $self->{probers}->[0]->handle_data (delete $self->{hwword});
        } else {
          delete $self->{hwword};
        }
      }
    }

    ## Detect lone halfwidth katakanas and leading or trailing
    ## halfwidth katakanas that can be interpreted as Latin1
    ## characters (e.g. 0xA9 copyright sign in Windows-1252).
    if ($self->{latin1_state} == 1 and $Latin1Type->[$cc] == 2) {
      $self->{latin1_state} = 2;
    } elsif ($self->{latin1_state} == 1 and $Latin1Type->[$cc] == 7) {
      $self->{latin1_count}++;
      $self->{latin1_state} = 0;
    } elsif (($self->{latin1_state} == 2 or
              $self->{latin1_state} == 4) and
             ($Latin1Type->[$cc] == 1 or
              $Latin1Type->[$cc] == 3 or
              $Latin1Type->[$cc] == 4)) {
      $self->{latin1_count}++;
      $self->{latin1_state} = 5;
    } elsif ($Latin1Type->[$cc] == 1) {
      if ($self->{latin1_state} == 8) {
        $self->{latin1_count}++;
      }
      $self->{latin1_state} = 1;
    } elsif ($Latin1Type->[$cc] == 6) {
      $self->{latin1_state} = 3;
    } elsif ($Latin1Type->[$cc] == 9) {
      if ($self->{latin1_state} == 1) {
        $self->{latin1_state} = 4;
      } else {
        $self->{latin1_state} = 3;
      }
    } elsif ($Latin1Type->[$cc] == 5 || $Latin1Type->[$cc] == 2) {
      ## Halfwidth small katakanas or voiced sound marks, not followed
      ## by halfwidth katakana or double-byte character
      unless (not defined $c or $self->{latin1_state} == 3) {
        $self->{latin1_count}++;
      }
      $self->{latin1_state} = 3;
    } elsif ($Latin1Type->[$cc] == 4 or $Latin1Type->[$cc] == 3) {
      if ($self->{latin1_state} == 7) {
        $self->{latin1_state} = 8;
      } elsif ($self->{latin1_state} == 8) {
        $self->{latin1_count}++;
        $self->{latin1_state} = 6;
      } else {
        $self->{latin1_state} = ($self->{latin1_state} == 4 or
                                 $self->{latin1_state} == 1) ? 6 : 5;
      }
    } elsif (($self->{latin1_state} == 6 or
              $self->{latin1_state} == 1) and $Latin1Type->[$cc] == 8) {
      $self->{latin1_state} = 7;
      # delimiter initial alphabet ascii
      # delimiter alphabet initial alphabet ascii
      # alphabet alphabet initial alphabet ascii
      # 7bit-only initial alphabet ascii
    } elsif ($Latin1Type->[$cc] == 8) {
      $self->{latin1_state} = 8;
    } else {
      $self->{latin1_state} = 8;
    }
    ## 0: Normal
    ## 1: After delimiter (and initial)
    ## 2: After copyright
    ## 3: After halfwidth katakana
    ## 4: After 1 followed by latin1 middle dot
    ## 5: After an ASCII alphanumeric
    ## 6: After two ASCII alphanumerics
    ## 7: After 6 followed by a leading byte
  } # $i

  substr ($self->{last_char}, 0, 1) = substr $_[1], $limit_pos - 1, 1;
  
  if ($self->{state} eq 'detecting') {
    if ($self->{coding_sm}->{error_count}) {
      if ($self->{coding_sm}->{error_count} > 10) {
        $self->{state} = 'not me';
      }
    } elsif ($self->context_got_enough_data and
             $self->get_confidence > Web::Encoding::UnivCharDet::Defs::SHORTCUT_THRESHOLD) {
      $self->{state} = 'found it';
    }
  }
  return $self->{state};
} # handle_data

sub handle_eof ($) {
  my $self = $_[0];
  return unless $self->{state} eq 'detecting';
  if (defined $self->{hwword}) {
    if ($self->{hwword} =~ /[^\x00-\x7F]/) {
      $self->{hwword} .= ' ';
      $self->{probers}->[0]->handle_data (delete $self->{hwword});
    }
  }
  $self->{coding_sm}->handle_eof;
} # handle_eof

sub _handle_one_char ($$$$) {
  my $self = $_[0];
  # $self, $str, $offset, $len

  my $order = $_[3] == 2 ? $self->distrib_get_order ($_[1], $_[2]) : -1;
  if ($order >= 0) {
    $self->{total_chars}++;
    if ($order < @{$self->{char_to_freq_order}}) {
      if (512 > $self->{char_to_freq_order}->[$order]) {
        $self->{freq_chars}++;
      }
    }
  }

  if ($self->{total_rel} > Web::Encoding::UnivCharDet::CharsetProber::MBCS::MAX_REL_THRESHOLD) {
    $self->{context_done} = 1;
  }
  unless ($self->{context_done}) {
    my $order = -1;
    if ($_[3] == 2) {
      $order = $self->context_get_order2 ($_[1], $_[2]);
    } else {
      $self->{context_state} = 0;
    }
  
    if ($order != -1 and $self->{last_char_order} != -1) {
      $self->{total_rel}++;
      $self->{rel_sample}->[Web::Encoding::UnivCharDet::Defs::jp2CharContext->[$self->{last_char_order}]->[$order]]++;
    }
    $self->{last_char_order} = $order;
  }
} # _handle_one_char

sub distrib_get_order ($$$) {
  my $order;
  if ((ord substr $_[1], $_[2], 1) >= 0x81 and
      (ord substr $_[1], $_[2], 1) <= 0x9F) {
    $order = 188 * ((ord substr $_[1], $_[2], 1) - 0x81);
  } elsif ((ord substr $_[1], $_[2], 1) >= 0xE0 and
           (ord substr $_[1], $_[2], 1) <= 0xEF) {
    $order = 188 * ((ord substr $_[1], $_[2], 1) - 0xE0 + 31);
  } else {
    return -1;
  }
  $order += (ord substr $_[1], $_[2] + 1, 1) - 0x40;
  $order-- if (ord substr $_[1], $_[2] + 1, 1) > 0x7F;
  return $order;
} # distrib_get_order

sub context_get_order2 ($$$) {
  if ((substr $_[1], $_[2], 1) eq "\202" and
      (ord substr $_[1], $_[2] + 1, 1) >= 0x9F and
      (ord substr $_[1], $_[2] + 1, 1) <= 0xF1) {
    return ((ord substr $_[1], $_[2] + 1, 1) - 0x9F);
  }

  return -1;
} # context_get_order2

sub get_confidence ($) {
  my $self = $_[0];
  if ($self->{state} eq 'not me') {
    return 0.01;
  }
  my $contxt_cf = $self->context_get_confidence;
  my $distrib_cf = $self->distrib_get_confidence;
  my $conf = $contxt_cf > $distrib_cf ? $contxt_cf : $distrib_cf;
  $conf = $distrib_cf * 0.6 if $contxt_cf == -1;
  if ($conf < 0.5 and not $self->{coding_sm}->{error_count}) {
    if ($self->{probers}->[0]->{total_char} > 5 and
        not $self->{probers}->[0]->{seq_counters}->[3]) { # POSITIVE_CAT
      #
    } else {
      $conf = 0.5 + 0.3 * $self->{probers}->[0]->get_confidence;
    }
  }
  if ($self->{latin1_count}) {
    my $k = 1.6;
    my $factor = 0.5 + 0.5 * exp(-$k * $self->{latin1_count});
    $conf *= $factor;
  }
  return $conf;
} # get_confidence

sub got_min_data ($) {
  return (
    not ($_[0]->{freq_chars} <= $_[0]->{data_threshold}) or
    $_[0]->{probers}->[0]->{seq_counters}->[3] >= 4 # POSITIVE_CAT
  );
} # got_min_data

sub dump_status ($) {
  my $self = $_[0];
  printf "%.3f [%s] (%s, e=%s, %s %s, l=%d, %s, %s)\n",
      $self->get_confidence,
      $self->get_charset_name,
      $self->{state},
      $self->{coding_sm}->{error_count},
      $self->distrib_get_confidence,
      $self->_distrib_dump_status,
      $self->{latin1_count},
      $self->context_get_confidence,
      $self->got_min_data ? 'min' : '_';
  for (@{$self->{probers}}) {
    print "  ";
    $_->dump_status;
  }
} # dump_status

sub dump_status_for_json ($) {
  my $self = $_[0];
  return {
    type => $self->get_charset_name,
    charset => $self->get_charset_name,
    confidence => $self->get_confidence,
    error_count => $self->{coding_sm}->{error_count},
    distribution_analyser => $self->distrib_dump_status_for_json,
    context_confidence => $self->context_get_confidence,
    latin1_count => $self->{latin1_count},
    got_min_data => !! $self->got_min_data,
    probers => [
      map { $_->dump_status_for_json } @{$self->{probers}},
    ],
  };
} # dump_status_for_json

package Web::Encoding::UnivCharDet::CharsetProber::ESC;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub new ($$) {
  my $self = bless {}, $_[0];
  $self->{coding_sm} = [
    $_[1] & Web::Encoding::UnivCharDet::Defs::FILTER_CHINESE_SIMPLIFIED
        ? Web::Encoding::UnivCharDet::CodingStateMachine->new
              (Web::Encoding::UnivCharDet::Defs::HZSMModel) : undef,
    $_[1] & Web::Encoding::UnivCharDet::Defs::FILTER_CHINESE_SIMPLIFIED
        ? Web::Encoding::UnivCharDet::CodingStateMachine->new
              (Web::Encoding::UnivCharDet::Defs::ISO2022CNSMModel) : undef,
    $_[1] & Web::Encoding::UnivCharDet::Defs::FILTER_JAPANESE
        ? Web::Encoding::UnivCharDet::CodingStateMachine->new
              (Web::Encoding::UnivCharDet::Defs::ISO2022JPSMModel) : undef,
    $_[1] & Web::Encoding::UnivCharDet::Defs::FILTER_KOREAN
        ? Web::Encoding::UnivCharDet::CodingStateMachine->new
              (Web::Encoding::UnivCharDet::Defs::ISO2022KRSMModel) : undef,
  ];
  $self->{active_sm} = @{$self->{coding_sm}};
  $self->reset;
  return $self;
} # new

sub reset ($) {
  my $self = $_[0];
  for (@{$self->{coding_sm}}) {
    $_->reset if $_;
  }
  $self->{state} = 'detecting';
  $self->{detected_charset} = undef;
} # reset

sub handle_data ($$) {
  my $self = $_[0];
  for my $i (0..((length $_[1]) - 1)) {
    last unless $self->{state} eq 'detecting';
    for (reverse @{$self->{coding_sm}}) {
      next unless $_;
      my $coding_state = $_->next_state (substr $_[1], $i, 1);
      if ($coding_state == Web::Encoding::UnivCharDet::Defs::eItsMe) {
        $self->{detected_charset} = $_->get_coding_state_machine;
        return $self->{state} = 'found it';
      }
    }
  }
  return $self->{state};
} # handle_data

sub get_charset_name ($) {
  return $_[0]->{detected_charset}; # or undef
} # get_charset_name

sub get_confidence ($) {
  return 0.99;
} # get_confidence

sub dump_status ($) {
  my $self = $_[0];
  printf "  ESC: %s [%s] (%s)\n",
      $self->get_confidence,
      $self->get_charset_name // '',
      $self->{state};
} # dump_status

sub dump_status_for_json ($) {
  my $self = $_[0];
  return {type => ref $self,
          charset => $self->get_charset_name,
          confidence => $self->get_confidence};
} # dump_status_for_json

package Web::Encoding::UnivCharDet::CharsetProber::Vietnamese;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub new ($;%) {
  my $self = bless {}, shift;
  my %args = @_;
  $self->{probers} = [  
    map { Web::Encoding::UnivCharDet::CharsetProber::SBCS->new ($_) }
    $Web::Encoding::UnivCharDet::Defs::VisciiVietnameseModel,
    $Web::Encoding::UnivCharDet::Defs::VniModel,
    $Web::Encoding::UnivCharDet::Defs::VpsVietnameseModel,
    $Web::Encoding::UnivCharDet::Defs::Tcvn3Model,
  ];
  $self->reset (%args);
  return $self;
} # new

sub reset ($;%) {
  my ($self, %args) = @_;
  $self->{state} = 'detecting';
  delete $self->{detected_charset};
  $self->{vstates} = [$Web::Encoding::UnivCharDet::Defs::VietStateInitial,
                      $Web::Encoding::UnivCharDet::Defs::VietStateInitial,
                      $Web::Encoding::UnivCharDet::Defs::VietStateInitial,
                      $Web::Encoding::UnivCharDet::Defs::VietStateInitial];
  $self->{before_ref} = [$Web::Encoding::UnivCharDet::Defs::VietStateInitial,
                         $Web::Encoding::UnivCharDet::Defs::VietStateInitial,
                         $Web::Encoding::UnivCharDet::Defs::VietStateInitial,
                         $Web::Encoding::UnivCharDet::Defs::VietStateInitial];
  $self->{nonascii} = [0, 0, 0, 0];
  $self->{any_nonascii} = [0, 0, 0, 0];
  $self->{words} = [[0,0,0,0,0], [0,0,0,0,0], [0,0,0,0,0], [0,0,0,0,0]];
  $self->{notme} = [0, 0, 0, 0];
  for (@{$self->{probers}}) {
    $_->reset (tokenized => 1);
  }
  $self->{current} = ['', '', '', ''];
  $self->{ref} = ['', '', '', ''];
  $self->{resolve_latin1_refs} = $args{resolve_latin1_refs};
} # reset

my $Tables = [
  [0, $Web::Encoding::UnivCharDet::Defs::VISCIIClassTable],
  [1, $Web::Encoding::UnivCharDet::Defs::VNIClassTable],
  [2, $Web::Encoding::UnivCharDet::Defs::VPSClassTable],
  [3, $Web::Encoding::UnivCharDet::Defs::VN3ClassTable],
];
sub handle_data ($$) {
  my $self = $_[0];
  return $self->{state} unless $self->{state} eq 'detecting';
  
  for my $i (0..((length $_[1]) - 1)) {
    my $cc0 = (ord substr $_[1], $i, 1);
    TBL: for (@$Tables) {
      my $charset = $_->[0];
      next if $self->{notme}->[$charset];

      my $cc = $cc0;
      my $os = $self->{vstates}->[$charset];
      THIS: {
        my $cls = ord substr $_->[1], $cc, 1;
        
        my $ns = ord substr $Web::Encoding::UnivCharDet::Defs::VietStateTable,
            ($os * $Web::Encoding::UnivCharDet::Defs::VietStateInputs + $cls);
        $self->{vstates}->[$charset] = $ns;

        if ((0x20 <= $cc and $cc <= 0x7E) or (0x09 <= $cc and $cc <= 0x0D)) {
          #
        } else {
          $self->{nonascii}->[$charset]++;
          $self->{any_nonascii}->[$charset]++;
        }

        if (Web::Encoding::UnivCharDet::Defs::IS_VIET_WORD_START ($os, $ns)) {
          $self->{nonascii}->[$charset] = 0;
          $self->{current}->[$charset] = pack 'C', $cc;
        } elsif (Web::Encoding::UnivCharDet::Defs::IS_VIET_VWORD ($ns)) {
          $self->{current}->[$charset] .= pack 'C', $cc;
        }
        if (Web::Encoding::UnivCharDet::Defs::IS_VIET_VWORD_END ($os, $ns)) {
          if ($self->{nonascii}->[$charset]) {
            $self->{words}->[$charset]->[1]++;
            $self->{words}->[$charset]->[4]++ if 1 == length $self->{current}->[$charset];
          } else {
            $self->{words}->[$charset]->[0]++;
          }
          $self->{probers}->[$charset]->handle_data ($self->{current}->[$charset]);
        }
        if (Web::Encoding::UnivCharDet::Defs::IS_VIET_FWORD_END ($os, $ns)) {
          if ($self->{nonascii}->[$charset]) {
            $self->{words}->[$charset]->[3]++;
          } else {
            $self->{words}->[$charset]->[2]++;
          }
          $self->{probers}->[$charset]->handle_data ($self->{current}->[$charset]);
        }
        if (Web::Encoding::UnivCharDet::Defs::IS_VIET_NOTME ($os, $ns)) {
          $self->{notme}->[$charset] = 1;
          next TBL;
        } else {
          $self->{any_nonascii}->[$charset]++;
        }

        if ($self->{resolve_latin1_refs}) {
          if (not Web::Encoding::UnivCharDet::Defs::IS_VIET_REF ($os) and
              Web::Encoding::UnivCharDet::Defs::IS_VIET_REF ($ns)) { # &
            $self->{before_ref}->[$charset] = $os;
            $self->{ref}->[$charset] = '';
          } elsif (Web::Encoding::UnivCharDet::Defs::IS_VIET_REF ($os)) {
            if (Web::Encoding::UnivCharDet::Defs::IS_VIET_REF ($ns)) {
              if (10 < length $self->{ref}->[$charset]) {
                $self->{ref}->[$charset] = '';
              } else {
                $self->{ref}->[$charset] .= pack 'C', $cc;
              }
            } else { # ;
              my $dd;
              if ($self->{ref}->[$charset] =~ /^#([0-9]+)$/) {
                $dd = $1 if 0x80 <= $1 and $1 <= 0xFF;
              } else {
                $dd = $Web::Encoding::UnivCharDet::Defs::Latin1Entities->{$self->{ref}->[$charset]}; # or undef
              }
              
              if (defined $dd) {
                $cc = 0+$dd;
                $os = $self->{before_ref}->[$charset];
                redo THIS;
              }
            }
          }
        } # resolve_latin1_refs
      } # THIS
    } # TBL
  }

  my $selected = [grep { $self->{notme}->[$_] == 0 and $self->{any_nonascii}->[$_] } 0..$#{$self->{notme}}];
  if (@$selected == 0) {
    $self->{state} = 'not me';
  } elsif (@$selected == 1) {
    if ($self->get_confidence > 0.8 and
        $self->{words}->[$selected->[0]]->[3] == 0) {
      $self->{state} = 'found it';
    }
  }
  
  return $self->{state};
} # handle_data

sub get_charset_name ($) {
  my $self = $_[0];
  $self->get_confidence if not defined $self->{detected_charset};
  
  return $self->{detected_charset}; # or undef
} # get_charset_name

sub get_confidence ($;$) {
  my $self = $_[0];
  if ($self->{state} eq 'not me' and not defined $_[1]) {
    $self->{detected_charset} = undef;
    return 0.01;
  }

  my @answer;
  for my $charset (defined $_[1] ? ($_[1]) : (0..3)) {
    next if $self->{notme}->[$charset];

    my ($A1, $A2, $A3, $A4) = @{$self->{words}->[$charset]};
    if ($A2 == 0 and $A4 == 0) { # ASCII only
      if ($A1 > 0 and not $self->{resolve_latin1_refs}) {
        if ($self->{any_nonascii}->[$charset]) {
          ## Words are ASCII-only but there are non-ASCII punctuations
          push @answer, [$charset, $A1>$A3*2 ? 0.5 : 0.15, $A4];
        }
      }
      next;
    }
    my $F = 0;
    my $T = $A1 + $A2 + $A3 + $A4;
    next if $T == 0;

    my $score;
    {
      if ($T < 10) {
        if ($A4) {
          $score = 0.10;
          last;
        } elsif ($A2 and $A1) {
          $score = 0.95;
        } elsif ($A2) {
          $score = 0.6;
        } elsif ($A1) {
          $score = 0.20;
        } else {
          $score = 0.10;
          last;
        }
        
        my $sc = $self->{probers}->[$charset]->{seq_counters};
        my $negative = $sc->[Web::Encoding::UnivCharDet::CharsetProber::SBCS::NEGATIVE_CAT];
        if ($negative) {
          $score *= 0.3;
        }
        
        last;
      }
      if ($A1 + $A2 > 10 and ($A1 == 0 or $A2 == 0)) {
        if ($A4 > 0) {
          $score = 0.1;
        } else {
          $score = 0.5;
        }
        last;
      }
      
      my $v_ratio    = ($A1 + $A2) / ($T + 1e-6);
      my $v_strength = ($A2 * 2 + $A1 * 0.5) / ($T + 1e-6);
      my $penalty    = 0.5 * ($A4 / ($T + 1e-6)) + 0.3 * ($F / ($T + 1e-6));
      my $raw = $v_ratio * (0.6 + 0.4 * $v_strength) - $penalty;
      #$raw += 0.15 if $A2 >= 1 && $v_ratio < 0.2;

      #my $conf = 1 - exp(-0.05 * ($A1 + $A2));
      #$raw *= $conf;

      #my $bad_ratio = ($A3 + $A4) / ($T + 1e-6);
      #my $foreign_penalty_base = 1 / (1 + exp(-12 * ($bad_ratio - 0.35)));
      #my $length_factor = 1 - exp(-0.3 * $T);  
      #my $a2_factor = 1 / (1 + exp(-2 * ($A2 - 1))); 
      #my $foreign_penalty = $foreign_penalty_base
      #                * $length_factor
      #                * (1 - 0.5 * $a2_factor);
      #$raw -= 0.6 * $foreign_penalty;

      $score = 1 / (1 + exp(-5 * ($raw - 0.1)));      
      $score = 0 if $score < 0;
      $score = 1 if $score > 1;

      if (($A1 + $A2) * 2 < $A3 + $A4) {
        $score *= 0.6;
      }

      if ($A2 > 0) {
        my $r_thr = 0.25;
        my $alpha = 1.0;
        my $N_min = 12;
        my $r_center = 0.30;
        my $scale = 0.08;
        my $k = 6;

        my $r1 = $self->{words}->[$charset]->[4] / $A2;
        my $x = ($r1 - $r_center) / $scale;
        my $penalty = 1/(1+exp(-(-$k * $x)));
        my $w = $A2 / $N_min;
        $w = 1 if $w > 1;
        my $m_final = 1 - $w*(1-$penalty);
        $score *= $m_final;
      }

      last;
    }

    push @answer, [$charset, $score, $A4];
  }
  @answer = sort { $b->[1] <=> $a->[1] } @answer;
  if (@answer > 1 and not $answer[0]->[0] == 1) { # != vni
    if ($answer[0]->[2] == 0) {
      @answer = grep { $_->[2] == 0 } @answer;
    }
    @answer = grep { ($answer[0]->[1] - $_->[1]) < 0.1 } @answer;
    if (@answer > 1) {
      for (@answer) {
        my $sc = $self->{probers}->[$_->[0]]->{seq_counters};
        $_->[3] = $sc->[Web::Encoding::UnivCharDet::CharsetProber::SBCS::POSITIVE_CAT] - $sc->[Web::Encoding::UnivCharDet::CharsetProber::SBCS::NEGATIVE_CAT]/($sc->[Web::Encoding::UnivCharDet::CharsetProber::SBCS::POSITIVE_CAT]+0.1)*4;
        #$_->[4] = $self->{probers}->[$_->[0]]->get_confidence;
      }
      @answer = sort { $b->[3] <=> $a->[3] } @answer;
    }
  }
  unless (defined $_[1]) {
    my $ans = @answer ? ['viscii', 'x-viet-vni', 'x-viet-vps', 'x-viet-tcvn']->[$answer[0]->[0]] : undef;
    $self->{detected_charset} = $ans; # or undef
  }
  
  my $c = $answer[0]->[1]; # or undef;
  return $c || 0.01;
} # get_confidence

sub dump_status ($) {
  my $self = $_[0];
  printf " Viet: %s [%s] %s (%s)\n",
      $self->get_confidence,
      $self->get_charset_name // '',
      $self->{resolve_latin1_refs} ? 'htmlrefs' : '',
      $self->{state};
  for my $charset (0..3) {
    printf "  %s [%s] (%d %d %d %d %d / %d)\n",
        $self->get_confidence ($charset),
        ['viscii', 'x-viet-vni', 'x-viet-vps', 'x-viet-tcvn']->[$charset],
        @{$self->{words}->[$charset]},
        $self->{vstates}->[$charset];
  }
  for (@{$self->{probers}}) {
    $_->dump_status;
  }
} # dump_status

sub dump_status_for_json ($) {
  my $self = $_[0];
  return {type => ref $self,
          charset => $self->get_charset_name // '',
          confidence => $self->get_confidence,
          htmlrefs => !!$self->{resolve_latin1_refs},
          probers => [
            {type => 'viscii', charset => 'viscii',
             confidence => $self->get_confidence (0)},
            {type => 'vni', charset => 'x-viet-vni',
             confidence => $self->get_confidence (1)},
            {type => 'vps', charset => 'x-viet-vps',
             confidence => $self->get_confidence (2)},
            {type => 'vn3', charset => 'x-viet-tcvn',
             confidence => $self->get_confidence (3)},
            map { $_->dump_status_for_json } @{$self->{probers}},
          ]};
} # dump_status_for_json

1;

=head1 LICENSE

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at <http://mozilla.org/MPL/2.0/>.

Note that some of L<Web::Encoding::UnivCharDet::CharsetProber::SBCS>
comes from <https://gitlab.freedesktop.org/uchardet/uchardet>'s
|src/nsSBCharSetProber.cpp|, which has the following terms:

/* ***** BEGIN LICENSE BLOCK *****
 * Version: MPL 1.1/GPL 2.0/LGPL 2.1
 *
 * The contents of this file are subject to the Mozilla Public License Version
 * 1.1 (the "License"); you may not use this file except in compliance with
 * the License. You may obtain a copy of the License at
 * http://www.mozilla.org/MPL/
 *
 * Software distributed under the License is distributed on an "AS IS" basis,
 * WITHOUT WARRANTY OF ANY KIND, either express or implied. See the License
 * for the specific language governing rights and limitations under the
 * License.
 *
 * The Original Code is Mozilla Universal charset detector code.
 *
 * The Initial Developer of the Original Code is
 * Netscape Communications Corporation.
 * Portions created by the Initial Developer are Copyright (C) 2001
 * the Initial Developer. All Rights Reserved.
 *
 * Contributor(s):
 *          Shy Shalom <shooshX@gmail.com>
 *
 * Alternatively, the contents of this file may be used under the terms of
 * either the GNU General Public License Version 2 or later (the "GPL"), or
 * the GNU Lesser General Public License Version 2.1 or later (the "LGPL"),
 * in which case the provisions of the GPL or the LGPL are applicable instead
 * of those above. If you wish to allow use of your version of this file only
 * under the terms of either the GPL or the LGPL, and not to allow others to
 * use your version of this file under the terms of the MPL, indicate your
 * decision by deleting the provisions above and replace them with the notice
 * and other provisions required by the GPL or the LGPL. If you do not delete
 * the provisions above, a recipient may use your version of this file under
 * the terms of any one of the MPL, the GPL or the LGPL.
 *
 * ***** END LICENSE BLOCK ***** */

=cut
