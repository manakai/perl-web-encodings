package Web::Encoding::UnivCharDet::CharsetProber;
use strict;
use warnings;
our $VERSION = '1.0';
use Web::Encoding::UnivCharDet::Defs;
use Web::Encoding::UnivCharDet::CodingStateMachine;
use Web::Encoding::UnivCharDet::CharDistribAnalysis;
use Web::Encoding::UnivCharDet::ContextAnalysis;

sub get_state ($) {
  return $_[0]->{state};
} # get_state

sub filter_without_english_letters ($$) {
  my $meet_msb = 0;
  my $prev = 0;
  my $new = '';
  my $len = length $_[1];
  for my $i (0..($len - 1)) {
    my $c = ord substr $_[1], $i, 1;
    if ($c & 0x80) {
      $meet_msb = 1;
    } elsif ($c < 0x41 or
             ($c > 0x5A and $c < 0x61) or
             $c > 0x7A) {
      if ($meet_msb and $i > $prev) {
        while ($prev < $i) { $new .= substr $_[1], $prev, 1; $prev++ }
        $prev++;
        $new .= ' ';
        $meet_msb = 0;
      } else {
        $prev = $i + 1;
      }
    }
  }
  if ($meet_msb and $len > $prev) {
    while ($prev < $len) { $new .= substr $_[1], $prev, 1; $prev++ }
  }

  return $new;
} # filter_without_english_letters

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
    while ($prev < $len) { $new .= substr $_[1]. $prev, 1; $prev++ }
  }

  return $new;
} # filter_with_english_letters

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
    my $char_class = $Latin1_CharToClass->[ord substr $new_buf1, $i, 1];
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
  printf " Latin1Prober: %1.3f [%s]\n",
      $self->get_confidence, $self->get_charset_name;
} # dump_status

package Web::Encoding::UnivCharDet::CharsetProber::SBCSGroup;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub new ($) {
  my $self = bless {}, $_[0];
  $self->{probers} = [
    map { Web::Encoding::UnivCharDet::CharsetProber::SBCS->new ($_) }
        Web::Encoding::UnivCharDet::Defs::Win1251Model,
        Web::Encoding::UnivCharDet::Defs::Koi8rModel,
        Web::Encoding::UnivCharDet::Defs::Latin5Model,
        Web::Encoding::UnivCharDet::Defs::MacCyrillicModel,
        Web::Encoding::UnivCharDet::Defs::Ibm866Model,
        Web::Encoding::UnivCharDet::Defs::Ibm855Model,
        Web::Encoding::UnivCharDet::Defs::Latin7Model,
        Web::Encoding::UnivCharDet::Defs::Win1253Model,
        Web::Encoding::UnivCharDet::Defs::Latin5BulgarianModel,
        Web::Encoding::UnivCharDet::Defs::Win1251BulgarianModel,
        Web::Encoding::UnivCharDet::Defs::TIS620ThaiModel,
  ];
  my $hebprober = Web::Encoding::UnivCharDet::CharsetProber::Hebrew->new;
  push @{$self->{probers}},
      $hebprober,
      Web::Encoding::UnivCharDet::CharsetProber::SBCS->new
          (Web::Encoding::UnivCharDet::Defs::Win1255Model, 0, $hebprober), # logical
      Web::Encoding::UnivCharDet::CharsetProber::SBCS->new
          (Web::Encoding::UnivCharDet::Defs::Win1255Model, 1, $hebprober); # visual
  $hebprober->set_model_probers
      ($self->{probers}->[-2], $self->{probers}->[-1]);
  $self->reset;
  return $self;
} # new

sub reset ($) {
  my $self = $_[0];
  $self->{active_num} = 0;
  for (@{$self->{probers}}) {
    $_->reset;
    $self->{active_num}++;
  }
  $self->{best_guess} = -1;
  $self->{state} = 'detecting';
} # reset

sub get_charset_name ($) {
  my $self = $_[0];
  if ($self->{best_guess} == -1) {
    $self->get_confidence;
    if ($self->{best_guess} == -1) {
      $self->{best_guess} = 0;
    }
  }
  return $self->{probers}->[$self->{best_guess}]->get_charset_name;
} # get_charset_name

sub handle_data ($$) {
  my $self = $_[0];

  my $new_buf = $self->filter_without_english_letters ($_[1]);
  if (length $new_buf) {
    for my $i (0..$#{$self->{probers}}) {
      local $_ = $self->{probers}->[$i];
      next unless $_;
      my $st = $_->handle_data ($new_buf);
      if ($st eq 'found it') {
        $self->{best_guess} = $i;
        $self->{state} = 'found it';
      } elsif ($st eq 'not me') {
        $self->{probers}->[$i] = undef;
        $self->{active_num}--;
        if ($self->{active_num} <= 0) {
          $self->{state} = 'not me';
        }
      }
    }
  }
  return $self->{state};
} # handle_data

sub get_confidence ($) {
  my $self = $_[0];

  if ($self->{state} eq 'found it') {
    return 0.99;
  } elsif ($self->{state} eq 'not me') {
    return 0.01;
  } else {
    my $best_conf = 0.0;
    for my $i (0..$#{$self->{probers}}) {
      local $_ = $self->{probers}->[$i];
      next unless $_;
      my $cf = $_->get_confidence;
      if ($best_conf < $cf) {
        $best_conf = $cf;
        $self->{best_guess} = $i;
      }
    }
    return $best_conf;
  }
} # get_confidence

sub dump_status ($) {
  my $self = $_[0];
  my $cf = $self->get_confidence;
  print " SBCS Group Prober --------begin status \n";
  for my $i (0..$#{$self->{probers}}) {
    local $_ = $self->{probers}->[$i];
    unless ($_) {
      printf "  inactive: [%s] (i.e. confidence is too low).\n", $_; # ->get_charset_name
    } else {
      $_->dump_status;
    }
  }
  printf " SBCS Group found best match [%s] confidence %f.\n",
      $self->{probers}->[$self->{best_guess}]->get_charset_name, $cf;
} # dump_status

package Web::Encoding::UnivCharDet::CharsetProber::SBCS;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub SAMPLE_SIZE () { 64 }
sub SB_ENOUGH_REL_THRESHOLD () { 1024 }
sub POSITIVE_SHORTCUT_THRESHOLD () { 0.95 }
sub NEGATIVE_SHORTCUT_THRESHOLD () { 0.05 }
sub SYMBOL_CAT_ORDER () { 250 }
sub NUMBER_OF_SEQ_CAT () { 4 }
sub POSITIVE_CAT () { NUMBER_OF_SEQ_CAT - 1 }
sub NEGATIVE_CAT () { 0 }

sub new ($$;$$) {
  my $self = bless {}, $_[0];
  $self->{model} = $_[1];
  $self->{reversed} = $_[2];
  $self->{name_prober} = $_[3];
  $self->reset;
  return $self;
} # new

sub reset ($) {
  my $self = $_[0];
  $self->{state} = 'detecting';
  $self->{last_order} = 255;
  $self->{seq_counters}->[$_] = 0 for 0..(NUMBER_OF_SEQ_CAT - 1);
  $self->{total_seqs} = 0;
  $self->{total_char} = 0;
  $self->{freq_char} = 0;
} # reset

sub handle_data ($$) {
  my $self = $_[0];

  for my $i (0..((length $_[1]) - 1)) {
    my $order = $self->{model}->{char_to_order_map}->[ord substr $_[1], $i, 1] || 0;
    if ($order < SYMBOL_CAT_ORDER) {
      $self->{total_char}++;
    }
    if ($order < SAMPLE_SIZE) {
      $self->{freq_char}++;
      if ($self->{last_order} < SAMPLE_SIZE) {
        $self->{total_seqs}++;
        unless ($self->{reversed}) {
          ++$self->{seq_counters}->[
            $self->{model}->{precedence_matrix}->[$self->{last_order} * SAMPLE_SIZE + $order]
          ];
        } else {
          ++$self->{seq_counters}->[
            $self->{model}->{precedence_matrix}->[$order * SAMPLE_SIZE + $self->{last_order}]
          ];
        }
      }
    }
    $self->{last_order} = $order;
  } # $i

  if ($self->{state} eq 'detecting') {
    if ($self->{total_seqs} > SB_ENOUGH_REL_THRESHOLD) {
      my $cf = $self->get_confidence;
      if ($cf > POSITIVE_SHORTCUT_THRESHOLD) {
        $self->{state} = 'found it';
      } elsif ($cf < NEGATIVE_SHORTCUT_THRESHOLD) {
        $self->{state} = 'not me';
      }
    }
  }

  return $self->{state};
} # handle_data

sub get_confidence ($) {
  my $self = $_[0];
  if (0 and 'negative approach') {
    if ($self->{total_seqs} > 0) {
      if ($self->{total_seqs} > $self->{seq_counters}->[NEGATIVE_CAT] * 10) {
        return (($self->{total_seqs} - $self->{seq_counters}->[NEGATIVE_CAT] * 10) / $self->{total_seqs} * $self->{freq_char} / $self->{total_char});
      }
    }
    return 0.01;
  } else {
    if ($self->{total_seqs} > 0) {
      my $r = 1.0 * $self->{seq_counters}->[POSITIVE_CAT] / $self->{total_seqs} / $self->{model}->{typical_positive_ratio};
      $r = $r * $self->{freq_char} / $self->{total_char};
      $r = 0.99 if $r >= 1.00;
      return $r;
    }
    return 0.01;
  }
} # get_confidence

sub get_charset_name ($) {
  my $self = $_[0];
  unless ($self->{name_prober}) {
    return $self->{model}->{charset_name};
  }
  return $self->{name_prober}->get_charset_name;
} # get_charset_name

sub keep_english_letters ($) {
  return $_[0]->{model}->{keep_english_letters};
} # keep_english_letters

sub dump_status ($) {
  my $self = $_[0];
  printf "  SBCS: %1.3f [%s]\n",
      $self->get_confidence, $self->get_charset_name;
} # dump_status

package Web::Encoding::UnivCharDet::CharsetProber::Hebrew;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub FINAL_KAF () { "\xea" }
sub NORMAL_KAF () { "\xeb" }
sub FINAL_MEM () { "\xed" }
sub NORMAL_MEM () { "\xee" }
sub FINAL_NUN () { "\xef" }
sub NORMAL_NUN () { "\xf0" }
sub FINAL_PE () { "\xf3" }
sub NORMAL_PE () { "\xf4" }
sub FINAL_TSADI () { "\xf5" }
sub NORMAL_TSADI () { "\xf6" }

sub MIN_FINAL_CHAR_DISTANCE () { 5 }
sub MIN_MODEL_DISTANCE () { 0.01 }

sub VISUAL_HEBREW_NAME () { "iso-8859-8" }
sub LOGICAL_HEBREW_NAME () { "windows-1255" }

sub is_final ($$) {
  return (($_[1] eq FINAL_KAF) ||
          ($_[1] eq FINAL_MEM) ||
          ($_[1] eq FINAL_NUN) ||
          ($_[1] eq FINAL_PE) ||
          ($_[1] eq FINAL_TSADI));
} # is_final

sub is_non_final ($$) {
  return (($_[1] eq NORMAL_KAF) ||
          ($_[1] eq NORMAL_MEM) ||
          ($_[1] eq NORMAL_NUN) ||
          ($_[1] eq NORMAL_PE));
} # is_non_final

sub new ($) {
  my $self = bless {}, $_[0];
  $self->reset;
  return $self;
} # new

sub reset ($) {
  my $self = $_[0];
  $self->{final_char_logical_score} = 0;
  $self->{final_char_visual_score} = 0;
  $self->{prev} = ' ';
  $self->{before_prev} = ' ';
} # reset

sub set_model_probers ($$$) {
  my $self = $_[0];
  $self->{logical_prob} = $_[1];
  $self->{visual_prob} = $_[2];
} # set_model_probers

sub handle_data ($$) {
  my $self = $_[0];
  if ($self->get_state eq 'not me') {
    return 'not me';
  }

  for my $i (0..((length $_[1]) - 1)) {
    my $c = substr $_[1], $i, 1;
    if ($c eq ' ') {
      if ($self->{before_prev} ne ' ') {
        if ($self->is_final ($self->{prev})) {
          $self->{final_char_logical_score}++;
        } elsif ($self->is_non_final ($self->{prev})) {
          $self->{final_char_visual_score}++;
        }
      }
    } else {
      if ($self->{before_prev} eq ' ' and
          $self->is_final ($self->{prev}) and
          ($c ne ' ')) {
        $self->{final_char_visual_score}++;
      }
    }
    $self->{before_prev} = $self->{prev};
    $self->{prev} = $c;
  } # $i

  return 'detecting';
} # handle_data

sub get_charset_name ($) {
  my $self = $_[0];
  my $finalsub = $self->{final_char_logical_score} - $self->{final_char_visual_score};
  if ($finalsub >= MIN_FINAL_CHAR_DISTANCE) {
    return LOGICAL_HEBREW_NAME;
  } elsif ($finalsub <= - MIN_FINAL_CHAR_DISTANCE) {
    return VISUAL_HEBREW_NAME;
  }

  my $modelsub = $self->{logical_prob}->get_confidence - $self->{visual_prob}->get_confidence;
  if ($modelsub > MIN_MODEL_DISTANCE) {
    return LOGICAL_HEBREW_NAME;
  } elsif ($modelsub < - MIN_MODEL_DISTANCE) {
    return VISUAL_HEBREW_NAME;
  }

  if ($finalsub < 0) {
    return VISUAL_HEBREW_NAME;
  }

  return LOGICAL_HEBREW_NAME;
} # get_charset_name

sub get_state ($) {
  my $self = $_[0];
  if ($self->{logical_prob}->get_state eq 'not me' and
      $self->{visual_prob}->get_state eq 'not me') {
    return 'not me';
  }
  return 'detecting';
} # get_state

sub get_confidence ($) { 0.0 }

sub dump_status ($) {
  my $self = $_[0];
  printf "  HEB: %d - %d [Logical-Visual score]\n",
      $self->{final_char_logical_score},
      $self->{final_char_visual_score};
} # dump_status

package Web::Encoding::UnivCharDet::CharsetProber::MBCSGroup;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub new ($$) {
  my $self = bless {}, $_[0];
  my $filter = $_[1];
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
  ];
  $self->reset;
  return $self;
} # new

sub reset ($) {
  my $self = $_[0];
  $self->{active_num} = 0;
  for (@{$self->{probers}}) {
    next unless $_;
    $_->reset;
    $self->{active_num}++;
  }
  $self->{best_guess} = -1;
  $self->{state} = 'detecting';
  $self->{keep_next} = 0;
} # reset

sub get_charset_name ($) {
  my $self = $_[0];
  if ($self->{best_guess} == -1) {
    $self->get_confidence;
    if ($self->{best_guess} == -1) {
      $self->{best_guess} = 0;
    }
  }
  return $self->{probers}->[$self->{best_guess}]->get_charset_name;
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
        for my $i (0..$#{$self->{probers}}) {
          local $_ = $self->{probers}->[$i];
          next unless $_;
          my $st = $_->handle_data (substr $_[1], $start);
          if ($st eq 'found it') {
            $self->{best_guess} = $i;
            return $self->{state} = 'found it';
          }
        }
      }
    }
  } # $pos

  if ($keep_next) {
    for my $i (0..$#{$self->{probers}}) {
      local $_ = $self->{probers}->[$i];
      next unless $_;
      my $st = $_->handle_data (substr $_[1], $start);
      if ($st eq 'found it') {
        $self->{best_guess} = $i;
        return $self->{state} = 'found it';
      }
    }
  }
  $self->{keep_next} = $keep_next;
  return $self->{state};
} # handle_data

sub get_confidence ($) {
  my $self = $_[0];
  my $best_conf = 0.0;
  if ($self->{state} eq 'found it') {
    return 0.99;
  } elsif ($self->{state} eq 'not me') {
    return 0.01;
  } else {
    for my $i (0..$#{$self->{probers}}) {
      local $_ = $self->{probers}->[$i];
      next unless $_;
      my $cf = $_->get_confidence;
      if ($best_conf < $cf) {
        $best_conf = $cf;
        $self->{best_guess} = $i;
      }
    }
  }
  return $best_conf;
} # get_confidence

my @ProberName = qw(UTF8 SJIS EUCJP GB18030 EUCKR Big5 EUCTW);
sub dump_status ($) {
  my $self = $_[0];
  $self->get_confidence;
  for my $i (0..$#{$self->{probers}}) {
    local $_ = $self->{probers}->[$i];
    unless ($_) {
      printf "  MBCS inactive: [%s] (confidence is too low).\n", $ProberName[$i];
    } else {
      my $cf = $_->get_confidence;
      printf "  MBCS %1.3f: [%s]\n", $cf, $ProberName[$i];
    }
  }
} # dump_status

package Web::Encoding::UnivCharDet::CharsetProber::UTF8;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub new ($) {
  my $self = bless {}, $_[0];
  $self->{coding_sm} = Web::Encoding::UnivCharDet::CodingStateMachine->new
      (Web::Encoding::UnivCharDet::Defs::UTF8SMModel);
  $self->reset;
  return $self;
} # new

sub reset {
  my $self = $_[0];
  $self->{coding_sm}->reset;
  $self->{num_of_mb_char} = 0;
  $self->{state} = 'detecting';
} # reset

sub get_charset_name ($) { 'utf-8' }

sub handle_data ($$) {
  my $self = $_[0];
  for my $i (0..((length $_[1]) - 1)) {
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
    if ($self->get_confidence > Web::Encoding::UnivCharDet::Defs::SHORTCUT_THRESHOLD) {
      $self->{state} = 'found it';
    }
  }
  return $self->{state};
} # handle_data

sub ONE_CHAR_PROB { 0.50 }

sub get_confidence ($) {
  my $self = $_[0];
  my $unlike = 0.99;
  if ($self->{num_of_mb_char} < 6) {
    $unlike *= ONE_CHAR_PROB for 1..$self->{num_of_mb_char};
    return 1.0 - $unlike;
  } else {
    return 0.99;
  }
} # get_confidence

package Web::Encoding::UnivCharDet::CharsetProber::MBCSWithDistributionAnalyser;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub new ($$) {
  my $self = bless {}, $_[0];
  $self->{is_preferred_lang} = $_[1];
  $self->{coding_sm} = Web::Encoding::UnivCharDet::CodingStateMachine->new ($self->_smmodel);
  $self->reset;
  return $self;
} # new

sub reset ($) {
  my $self = $_[0];
  $self->{coding_sm}->reset;
  $self->{state} = 'detecting';
  $self->{last_char} = "\x00\x00";
  $self->{distribution_analyser} = $self->_distrib_analyser->new;
  $self->{distribution_analyser}->reset ($self->{is_preferred_lang});
} # reset

sub handle_data ($$) {
  my $self = $_[0];
  for my $i (0..((length $_[1]) - 1)) {
    my $coding_state = $self->{coding_sm}->next_state (substr $_[1], $i, 1);
    if ($coding_state == Web::Encoding::UnivCharDet::Defs::eItsMe) {
      $self->{state} = 'found it';
      last;
    } elsif ($coding_state == Web::Encoding::UnivCharDet::Defs::eStart) {
      my $char_len = $self->{coding_sm}->get_current_char_len;
      if ($i == 0) {
        substr ($self->{last_char}, 1, 0) = substr $_[1], 0, 1;
        $self->{distribution_analyser}->handle_one_char ($self->{last_char}, 0, $char_len);
      } else {
        $self->{distribution_analyser}->handle_one_char ($_[1], $i-1, $char_len);
      }
    }
  }

  substr ($self->{last_char}, 0, 1) = substr $_[1], -1;

  if ($self->{state} eq 'detecting') {
    if ($self->{distribution_analyser}->got_enough_data and
        $self->get_confidence > Web::Encoding::UnivCharDet::Defs::SHORTCUT_THRESHOLD) {
      $self->{state} = 'found it';
    }
  }
  return $self->{state};
} # handle_data

sub get_confidence ($) {
  return $_[0]->{distribution_analyser}->get_confidence;
} # get_confidence

package Web::Encoding::UnivCharDet::CharsetProber::GB18030;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber::MBCSWithDistributionAnalyser);
our $VERSION = '1.0';

sub _smmodel ($) { Web::Encoding::UnivCharDet::Defs::GB18030SMModel }
sub _distrib_analyser ($) { 'Web::Encoding::UnivCharDet::CharDistribAnalysis::GB2312' }
sub get_charset_name ($) { 'gb18030' }

package Web::Encoding::UnivCharDet::CharsetProber::Big5;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber::MBCSWithDistributionAnalyser);
our $VERSION = '1.0';

sub _smmodel ($) { Web::Encoding::UnivCharDet::Defs::Big5SMModel }
sub _distrib_analyser ($) { 'Web::Encoding::UnivCharDet::CharDistribAnalysis::Big5' }
sub get_charset_name ($) { 'big5' }

package Web::Encoding::UnivCharDet::CharsetProber::EUCTW;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber::MBCSWithDistributionAnalyser);
our $VERSION = '1.0';

sub _smmodel ($) { Web::Encoding::UnivCharDet::Defs::EUCTWSMModel }
sub _distrib_analyser ($) { 'Web::Encoding::UnivCharDet::CharDistribAnalysis::EUCTW' }
sub get_charset_name ($) { 'x-euc-tw' }

package Web::Encoding::UnivCharDet::CharsetProber::EUCKR;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber::MBCSWithDistributionAnalyser);
our $VERSION = '1.0';

sub _smmodel ($) { Web::Encoding::UnivCharDet::Defs::EUCKRSMModel }
sub _distrib_analyser ($) { 'Web::Encoding::UnivCharDet::CharDistribAnalysis::EUCKR' }
sub get_charset_name ($) { 'euc-kr' }

package Web::Encoding::UnivCharDet::CharsetProber::EUCJP;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub new ($$) {
  my $self = bless {}, $_[0];
  $self->{is_preferred_lang} = $_[1];
  $self->{coding_sm} = Web::Encoding::UnivCharDet::CodingStateMachine->new
      (Web::Encoding::UnivCharDet::Defs::EUCJPSMModel);
  $self->reset;
  return $self;
} # new

sub reset ($) {
  my $self = $_[0];
  $self->{coding_sm}->reset;
  $self->{state} = 'detecting';
  $self->{last_char} = "\x00\x00";
  $self->{context_analyser} = Web::Encoding::UnivCharDet::ContextAnalysis::EUCJP->new;
  $self->{distribution_analyser} = Web::Encoding::UnivCharDet::CharDistribAnalysis::EUCJP->new;
  $self->{context_analyser}->reset ($self->{is_preferred_lang});
  $self->{distribution_analyser}->reset ($self->{is_preferred_lang});
} # reset

sub get_charset_name ($) { 'euc-jp' }

sub handle_data ($$) {
  my $self = $_[0];
  for my $i (0..((length $_[1]) - 1)) {
    my $coding_state = $self->{coding_sm}->next_state (substr $_[1], $i, 1);
    if ($coding_state == Web::Encoding::UnivCharDet::Defs::eItsMe) {
      $self->{state} = 'found it';
      last;
    } elsif ($coding_state == Web::Encoding::UnivCharDet::Defs::eStart) {
      my $char_len = $self->{coding_sm}->get_current_char_len;
      if ($i == 0) {
        (substr $self->{last_char}, 1, 1) = substr $_[1], 0, 1;
        $self->{context_analyser}->handle_one_char
            ($self->{last_char}, 0, $char_len);
        $self->{distribution_analyser}->handle_one_char
            ($self->{last_char}, 0, $char_len);
      } else {
        $self->{context_analyser}->handle_one_char
            ($_[1], $i-1, $char_len);
        $self->{distribution_analyser}->handle_one_char
            ($_[1], $i-1, $char_len);
      }
    }
  }

  substr ($self->{last_char}, 0, 1) = substr $_[1], -1, 1;

  if ($self->{state} eq 'detecting') {
    if ($self->{context_analyser}->got_enough_data and
        $self->get_confidence > Web::Encoding::UnivCharDet::Defs::SHORTCUT_THRESHOLD) {
      $self->{state} = 'found it';
    }
  }
  
  return $self->{state};
} # handle_data

sub get_confidence ($) {
  my $self = $_[0];
  my $contxt_cf = $self->{context_analyser}->get_confidence;
  my $distrib_cf = $self->{distribution_analyser}->get_confidence;
  return $contxt_cf > $distrib_cf ? $contxt_cf : $distrib_cf;
} # get_confidence

package Web::Encoding::UnivCharDet::CharsetProber::SJIS;
push our @ISA, qw(Web::Encoding::UnivCharDet::CharsetProber);
our $VERSION = '1.0';

sub new ($$) {
  my $self = bless {}, $_[0];
  $self->{is_preferred_lang} = $_[1];
  $self->{coding_sm} = Web::Encoding::UnivCharDet::CodingStateMachine->new
      (Web::Encoding::UnivCharDet::Defs::SJISSMModel);
  $self->reset;
  return $self;
} # new

sub reset ($) {
  my $self = $_[0];
  $self->{coding_sm}->reset;
  $self->{state} = 'detecting';
  $self->{last_char} = "\x00\x00";
  $self->{context_analyser} = Web::Encoding::UnivCharDet::ContextAnalysis::SJIS->new;
  $self->{distribution_analyser} = Web::Encoding::UnivCharDet::CharDistribAnalysis::SJIS->new;
  $self->{context_analyser}->reset ($self->{is_preferred_lang});
  $self->{distribution_analyser}->reset ($self->{is_preferred_lang});
} # reset

sub get_charset_name ($) { 'shift_jis' }

sub handle_data ($$) {
  my $self = $_[0];
  for my $i (0..((length $_[1]) - 1)) {
    my $coding_state = $self->{coding_sm}->next_state (substr $_[1], $i, 1);
    if ($coding_state == Web::Encoding::UnivCharDet::Defs::eItsMe) {
      $self->{state} = 'found it';
      last;
    } elsif ($coding_state == Web::Encoding::UnivCharDet::Defs::eStart) {
      my $char_len = $self->{coding_sm}->get_current_char_len;
      if ($i == 0) {
        substr ($self->{last_char}, 1, 1) = substr $_[1], 0, 1;
        $self->{context_analyser}->handle_one_char
            ($self->{last_char}, 2-$char_len, $char_len);
        $self->{distribution_analyser}->handle_one_char
            ($self->{last_char}, 0, $char_len);
      } else {
        $self->{context_analyser}->handle_one_char
            ($_[1], $i+1-$char_len, $char_len);
        $self->{distribution_analyser}->handle_one_char
            ($_[1], $i-1, $char_len);
      }
    }
  }

  substr ($self->{last_char}, 0, 1) = substr $_[1], -1;
  
  if ($self->{state} eq 'detecting') {
    if ($self->{context_analyser}->got_enough_data and
        $self->get_confidence > Web::Encoding::UnivCharDet::Defs::SHORTCUT_THRESHOLD) {
      $self->{state} = 'found it';
    }
  }
  return $self->{state};
} # handle_data

sub get_confidence ($) {
  my $self = $_[0];
  my $contxt_cf = $self->{context_analyser}->get_confidence;
  my $distrib_cf = $self->{distribution_analyser}->get_confidence;
  return $contxt_cf > $distrib_cf ? $contxt_cf : $distrib_cf;
} # get_confidence

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
  return $_[0]->{detected_charset};
} # get_charset_name

sub get_confidence ($) {
  return 0.99;
} # get_confidence

1;

=head1 LICENSE

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at <http://mozilla.org/MPL/2.0/>.

=cut
