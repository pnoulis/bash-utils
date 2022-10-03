SHELL = /bin/bash
prefix ?= $(HOME)
bindir := $(prefix)/bin
srcdir := $(realpath .)

# If at any point in time bash-utils source tree grows
# subdirectories should be appended to VPATH
# VPATH := src

scripts := $(shell find $(srcdir) -mindepth 1 -name '*.sh' -printf "%f ")
scripts := $(addprefix $(bindir)/, $(scripts))

.DEFAULT_GOAL: install

.PHONY: install
install: $(scripts)
	@echo "Installation directory: $(bindir)"; \
	if [[ ":$$PATH:" != *":$(bindir):"* ]]; then \
	echo "ADD TO PATH: $(bindir)"; \
	fi

$(bindir)/%.sh: %.sh | $(bindir)
	@echo "Installing $(@F)"
	@cat $^ > $@; chmod +x $@

$(bindir):
	@mkdir -p $(bindir)
