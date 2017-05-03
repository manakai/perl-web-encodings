use strict;
use warnings;
use Path::Tiny;
use lib glob path (__FILE__)->parent->parent->child ('modules/*/lib');
use lib glob path (__FILE__)->parent->parent->child ('t_deps/modules/*/lib');
use lib glob path (__FILE__)->parent->parent->child ('local/modules/*/lib');
use JSON::PS;
use Web::DOM::Document;

my $Data = {};

sub _n ($) {
  my $s = shift;
  $s =~ s/\s+/ /g;
  $s =~ s/^ //;
  $s =~ s/ $//;
  return $s;
} # _n

sub parse_file ($) {
  my $error_type;
  my $last_lang;
  my $key_by_lang;
  my $in_test;
  my $default_module;
  for (split /\x0D?\x0A/, path ($_[0])->slurp_utf8) {
    if (/^\s*\#/) {
      #
    } elsif (/^\*\s*(.+)$/) {
      my $name = _n $1;
      die "Duplicate error type |$name|" if defined $Data->{errors}->{$name};
      $Data->{errors}->{$name} ||= {};
      $error_type = $name;
      $last_lang = undef;
      $key_by_lang = {};
      $in_test = undef;
      $Data->{errors}->{$error_type}->{'modules'}->{$default_module} = 1
          if defined $default_module;
    } elsif (defined $error_type and /^\@(\w+)$/) {
      my $lang = $1;
      if (defined $Data->{errors}->{$error_type}->{message}->{$lang}) {
        if (defined $Data->{errors}->{$error_type}->{desc}->{$lang}) {
          die "There are three texts for language |$lang|";
        } else {
          $key_by_lang->{$lang} = 'desc';
        }
      } else {
        $key_by_lang->{$lang} = 'message';
      }
      $last_lang = $lang;
    } elsif (defined $last_lang) {
      ($Data->{errors}->{$error_type}->{$key_by_lang->{$last_lang}}->{$last_lang} //= '') .= "\x0A" . $_;
    } elsif ($in_test) {
      if (/^!(\w+)=(.*)$/) {
        $Data->{errors}->{$error_type}->{parser_tests}->[-1]->{$1} = $2;
      } elsif (/^!(\w+)$/) {
        $Data->{errors}->{$error_type}->{parser_tests}->[-1]->{$1} = 1;
      } else {
        $Data->{errors}->{$error_type}->{parser_tests}->[-1]->{input} .= "\x0A" . $_;
      }
    } elsif (defined $error_type and /^(layer)=(microsyntax|content-model|feature|charencoding)$/) {
      $Data->{errors}->{$error_type}->{$1} = $2;
    } elsif (defined $error_type and /^(default_level)=(m|s|w|u)$/) {
      $Data->{errors}->{$error_type}->{$1} = $2;
    } elsif (defined $error_type and /^(attr)$/) {
      $Data->{errors}->{$error_type}->{targets}->{$1} = 1;
    } elsif (/^(module)=(\S+)$/) {
      if (defined $error_type) {
        $Data->{errors}->{$error_type}->{$1.'s'}->{$2} = 1;
      } else {
        if (defined $default_module) {
          die "Redundant module |$2|";
        }
        $default_module = $2;
      }
    } elsif (/\S/) {
      die "Broken line |$_|";
    }
  }
} # parse_file

parse_file $_ for @ARGV;

my $doc = new Web::DOM::Document;
$doc->manakai_is_html (1);
my $el = $doc->create_element ('div');
for my $error_type (keys %{$Data->{errors}}) {
  for my $key (qw(message desc)) {
    for my $lang (keys %{$Data->{errors}->{$error_type}->{$key}}) {
      my $text = $Data->{errors}->{$error_type}->{$key}->{$lang};
      $text =~ s/^\s+//;
      $text =~ s/\s+$//;
      $el->inner_html ($text);
      $Data->{errors}->{$error_type}->{$key}->{$lang} = $el->inner_html;
    }
  }

  $Data->{errors}->{$error_type}->{default_level} //= 'm';
} # $error_type

for my $error_type (keys %{$Data->{errors}}) {
  warn "|$error_type| has no layer"
      if not defined $Data->{errors}->{$error_type}->{layer};
  warn "|$error_type| has no module"
      unless keys %{$Data->{errors}->{$error_type}->{modules} or {}};
} # $error_type

print perl2json_bytes_for_record $Data;

## License: Public Domain.
