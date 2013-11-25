all: lib/Web/Encoding/_Defs.pm

## ------ Setup ------

WGET = wget
GIT = git
PERL = ./perl

deps: git-submodules pmbp-install

git-submodules:
	$(GIT) submodule update --init

local/bin/pmbp.pl:
	mkdir -p local/bin
	$(WGET) -O $@ https://raw.github.com/wakaba/perl-setupenv/master/bin/pmbp.pl
pmbp-upgrade: local/bin/pmbp.pl
	perl local/bin/pmbp.pl --update-pmbp-pl
pmbp-update: pmbp-upgrade git-submodules
	perl local/bin/pmbp.pl --update
pmbp-install: pmbp-upgrade
	perl local/bin/pmbp.pl --install

## ------ Build ------

local/encodings.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.github.com/manakai/data-web-defs/master/data/encodings.json
lib/Web/Encoding/_Defs.pm: local/encodings.json pmbp-install Makefile
	perl local/bin/pmbp.pl --install-module JSON
	$(PERL) -MJSON -MData::Dumper -e ' #\
	  local $$/ = undef; #\
	  $$data = JSON->new->decode (scalar <>); #\
	  $$Data::Dumper::Sortkeys = 1; #\
	  $$Data::Dumper::Useqq = 1; #\
	  $$pm = Dumper $$data; #\
	  $$pm =~ s/VAR1/Web::Encoding::_Defs/; #\
	  print "$$pm\n"; #\
	' < local/encodings.json > $@
	perl -c $@

## ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps

test-main:
	$(PROVE) t/*.t
