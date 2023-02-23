#!/usr/bin/make -f
SHELL := /bin/bash

# Meta package
package := bash_utils
package_version := 1.0.0
package_distname := $(package)-$(package_version)

# Directories
## Anchors
srcdir = .
abs_srcdir = $(realpath .)
VPATH = tmp
## Build
buildir = $(srcdir)/build
abs_buildir = $(abs_srcdir)/build
built = $(buildir)
## Distribute
distdir = $(srcdir)/dist
distribution = $(distdir)/$(package_distname)
## Install
DESTDIR ?=
prefix = $(HOME)
exec_prefix = $(prefix)
bindir = $(prefix)/bin

# Utilities
INSTALL := /usr/bin/install

# version controlled tree
vctree := $(shell git ls-files --exclude-standard --cached)
executables := $(basename $(notdir $(filter %.sh, $(vctree))))
vctree_state := $(shell git status -z | wc -w | while read n; do \
	if [ $$n -eq 0 ]; then \
		echo clean; \
	else \
		echo dirty; \
	fi; \
	done)

all: build

.PHONY: build
build: $(addprefix $(buildir)/, $(executables))

$(buildir)/%: %.sh | $(abs_buildir)
	cat $< > $@
	chmod +x $@

$(abs_buildir):
	mkdir -p $(buildir)

clean:
	-rm -rdf $(buildir)

dist: dist.gz

.PHONY: distrules clean_working_tree
ifndef FORCE
dist.gz: distrules $(distribution).tar.gz
dist.zip: distrules $(distribution).zip
else
dist.gz: $(distribution).tar.gz
dist.zip: $(distribution).zip
endif

distrules: clean_working_tree

clean_working_tree:
ifeq ($(vctree_state), dirty)
	$(error Uncommited changes in working tree! Aborting dist target)
endif

$(distribution).tar.gz: $(distribution)
	cd $(distdir) \
	&& tar --create --dereference --file=- $(package_distname) \
	| gzip --to-stdout --best - > $(package_distname).tar.gz

$(distribution).zip: $(distribution)
	cd $(distdir) \
	&& zip -r - $(package_distname) > $(package_distname).zip

$(distribution): _FORCE
	-mkdir -p $(distribution) &>/dev/null
	for file in $(vctree); do \
	fdir=$${file%/*}; \
	[ -d $${fdir} ] && mkdir -p $(distribution)/$${fdir}; \
	ln --force --physical \
	$${file} $(distribution)/$${fdir}; \
	done

distclean: clean
	rm -rf $(distdir)/* .env config.log

install: build
	-$(INSTALL) -d $(DESTDIR)$(bindir)
	$(INSTALL) $(addprefix $(buildir)/, $(executables)) $(DESTDIR)$(bindir)


uninstall:
	-cd $(DESTDIR)$(bindir) && rm -f $(executables)
	rmdir $(DESTDIR)$(bindir)

.PHONY: _FORCE
_FORCE:
.DEFAULT_GOAL := all
.PHONY: all clean dist distclean install uninstall test
# not implemented
.PHONY: check distcheck release deploy publish
