all: build

clean: clean-json-ps
	rm -fr local/*.json local/*.txt lib/Web/Encoding/unicore/*.pl

updatenightly: update-submodules dataautoupdate-commit

update-submodules: local/bin/pmbp.pl
	curl https://gist.githubusercontent.com/wakaba/34a71d3137a52abb562d/raw/gistfile1.txt | sh
	git add t_deps/modules t_deps/tests
	perl local/bin/pmbp.pl --update
	git add config

dataautoupdate-commit: clean build
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

build: lib/Web/Encoding/_Defs.pm \
    lib/Web/Encoding/unicore/CombiningClass.pl \
    lib/Web/Encoding/unicore/Decomposition.pl \
    lib/Web/Encoding/unicore/CompositionExclusions.pl \
    lib/Web/Encoding/_Single.pm \
    lib/Web/Encoding/_GB.pm \
    lib/Web/Encoding/_Big5.pm \
    lib/Web/Encoding/_JIS.pm \
    lib/Web/Encoding/_EUCKR.pm \
    intermediate/encoding-errors.json

local/encodings.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.github.com/manakai/data-web-defs/master/data/encodings.json
local/encoding-indexes.json:
	mkdir -p local
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-web-defs/master/data/encoding-indexes.json

lib/Web/Encoding/_Defs.pm: local/encodings.json Makefile json-ps
	$(PERL) -MJSON::PS -MData::Dumper -e ' #\
	  local $$/ = undef; #\
	  $$data = json_bytes2perl (scalar <>); #\
	  $$data->{encodings}->{"x-user-defined"}->{single_byte} = 1; #\
	  $$Data::Dumper::Sortkeys = 1; #\
	  $$Data::Dumper::Useqq = 1; #\
	  $$pm = Dumper $$data; #\
	  $$pm =~ s/VAR1/Web::Encoding::_Defs/; #\
	  print "$$pm\n"; #\
	' < local/encodings.json > $@
	perl -c $@
lib/Web/Encoding/_Single.pm: bin/mksingle.pl local/encoding-indexes.json json-ps
	$(PERL) $< > $@
lib/Web/Encoding/_GB.pm: bin/mkgb.pl local/encoding-indexes.json json-ps
	$(PERL) $< > $@
lib/Web/Encoding/_Big5.pm: bin/mkbig5.pl local/encoding-indexes.json json-ps
	$(PERL) $< > $@
lib/Web/Encoding/_JIS.pm: bin/mkjis.pl local/encoding-indexes.json json-ps
	$(PERL) $< > $@
lib/Web/Encoding/_EUCKR.pm: bin/mkeuckr.pl local/encoding-indexes.json json-ps
	$(PERL) $< > $@

lib/Web/Encoding/unicore/CombiningClass.pl:
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-chars/master/data/perl/unicore-CombiningClass.pl
lib/Web/Encoding/unicore/Decomposition.pl:
	$(WGET) -O $@ https://raw.githubusercontent.com/manakai/data-chars/master/data/perl/unicore-Decomposition.pl
local/CompositionExclusions.txt:
	mkdir -p local
	$(WGET) -O $@ "https://chars.suikawiki.org/set/textlist?item=%24unicode%3ACompositionExclusions"
lib/Web/Encoding/unicore/CompositionExclusions.pl: \
    local/CompositionExclusions.txt
	echo '[qw(' > $@
	cat local/CompositionExclusions.txt >> $@
	echo ')]' >> $@
	perl -c $@

intermediate/encoding-errors.json: bin/generate-errors.pl \
    src/encoding-errors.txt json-ps local-for-errors
	$(PERL) $< src/encoding-errors.txt > $@

local-for-errors: local/bin/pmbp.pl
	git clone https://github.com/manakai/perl-web-dom local/modules/web-dom || (cd local/modules/web-dom && git pull)
	git clone https://github.com/manakai/perl-web-markup local/modules/web-markup || (cd local/modules/web-markup && git pull)

## ------ Tests ------

PROVE = ./prove

test: test-deps test-main

test-deps: deps local/encoding-indexes.json

test-main:
	$(PROVE) t/*.t t/normalize/*.t

## License: Public Domain.