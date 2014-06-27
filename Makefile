all: lib/Web/Encoding/_Defs.pm

clean: clean-json-ps
	rm local/encodings.json

updatenightly: update-submodules dataautoupdate-commit

update-submodules: local/bin/pmbp.pl
	curl https://gist.githubusercontent.com/wakaba/34a71d3137a52abb562d/raw/gistfile1.txt | sh
	git add t_deps/modules
	perl local/bin/pmbp.pl --update
	git add config

dataautoupdate-commit: clean all
	git add lib

## ------ Setup ------

WGET = wget
GIT = git
PERL = ./perl

deps: git-submodules pmbp-install json-ps

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

json-ps: local/perl-latest/pm/lib/perl5/JSON/PS.pm
clean-json-ps:
	rm -fr local/perl-latest/pm/lib/perl5/JSON/PS.pm
local/perl-latest/pm/lib/perl5/JSON/PS.pm:
	mkdir -p local/perl-latest/pm/lib/perl5/JSON
	$(WGET) -O $@ https://raw.githubusercontent.com/wakaba/perl-json-ps/master/lib/JSON/PS.pm

## ------ Build ------

local/encodings.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.github.com/manakai/data-web-defs/master/data/encodings.json
lib/Web/Encoding/_Defs.pm: local/encodings.json Makefile json-ps
	$(PERL) -MJSON::PS -MData::Dumper -e ' #\
	  local $$/ = undef; #\
	  $$data = json_bytes2perl (scalar <>); #\
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
