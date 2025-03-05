SHELL := bash

ROOT := $(shell pwd)

PYTHON := $(shell command -v python3)
PYTHON ?= $(shell command -v python)

export ROOT

CONFIG := mkdocs.yml

MKDOCS_MATERIAL_VERSION := 9.5.50
MKDOCS_MATERIAL_REPO := https://github.com/squidfunk/mkdocs-material

PYTHON_VENV := $(ROOT)/.venv
VENV := source $(PYTHON_VENV)/bin/activate

WATCHER := $(VENV) && watchmedo shell-command
WATCH := \
  util/mdys \
  config.ys \
  config/ \
  Makefile \

null :=
space := ${null} ${null}

T := /tmp/ys-website.tmp

WATCH := $(subst $(space),;,$(WATCH))

DEPS := \
  $(PYTHON_VENV) \
  $(CONFIG) \


default::

deps: line1 $(DEPS) line2

ifeq (live,$(website))
  YS_WWW_DOMAIN := getys.org
  YS_WWW_REMOTE := git@github.com:yaml/getys-org
  YS_WWW_BRANCH ?= gh-pages
else ifeq (stage,$(website))
  export YS_WWW_DEV := true
  YS_WWW_DOMAIN := stage.getys.org
  YS_WWW_REMOTE := git@github.com:yaml/stage-getys-org
  YS_WWW_BRANCH := site
endif

build:: $(DEPS)
	$(RM) -r site
	git worktree add -f site
	$(RM) -r site/*
	$(VENV) && mkdocs build
	echo $(YS_WWW_DOMAIN) > site/CNAME
	git -C site add -A

# serve: $(DEPS) watch

serve: $(DEPS)
	$(VENV) && mkdocs serve

deps-update: deps-update-notify deps

deps-update-notify:
	: *** Rebuilding dependencies ***

# XXX - See 'mkdocs gh-deploy' for a more standard way to do this
# Options remote_branch and remote_name are used for gh-deploy
ifeq (,$(YS_WWW_REMOTE))
publish:
	$(error Use 'make publish website=<live|stage>' to publish)
else
publish: build
	-git -C site commit -m "Publish $$(date)"
	git -C site push $(YS_WWW_REMOTE) HEAD:$(YS_WWW_BRANCH) --force
	@echo
	@echo "Published to https://$(YS_WWW_DOMAIN)"
	@echo
endif

watchmedo-help:
	$(WATCHER) --help | less

watch:
	: Starting watching: '$(WATCH)'
	@cd .. && \
	$(WATCHER) \
	  --command='\
	    bash -c "\
	      : CHANGED $$watch_src_path $$watch_event_type; \
	      [[ $$watch_event_type == modified ]] && \
	        $(MAKE) -C www deps-update; \
	  "' \
	  --patterns='$(WATCH)' \
	  --recursive \
	  --timeout=2 \
	  --wait \
	  --drop \
	  &

material:
	git \
	  -c advice.detachedHead=false \
	  clone \
	  --quiet \
	  --depth 1 \
	  --branch $(MKDOCS_MATERIAL_VERSION) \
	  $(MKDOCS_MATERIAL_REPO) $@
	printf '%s\n' material/* | \
	  grep -Ev '/(docs|material|mkdocs.yml)' | \
	  xargs $(RM) -r
	$(RM) -r $@/.git
	ln -s $@/material/templates mt

override: material
ifeq (,$(f))
	@echo 'f=<file> is not set'
	@exit 1
endif
	cp $</$</templates/$f theme/$f

pip-install: $(PYTHON_VENV)
ifeq (,$(m))
	@echo 'm=<module> is not set'
	@exit 1
endif
	$(VENV) && pip install $m
	$(VENV) && pip freeze > requirements.txt

clean::
	killall watchmedo || true
	$(RM) $(CONFIG) sample $T
	$(RM) -r site

realclean:: clean
	$(RM) -r $(PYTHON_VENV) material
	rm -f mt

$(VENV_DIR): $(PYTHON_VENV)

$(PYTHON_VENV):
	$(PYTHON) -m venv $@
	$(VENV) && pip install -r requirements.txt

# YS doesn't support !!python tags yet.
# This hack is a workaround to preserve them.
YS_YAML_TAG_HACK := perl -pe 's{: \+!}{: !}'

$(CONFIG): config.ys config/*
	@( \
	  set -euo pipefail; \
	  echo "# DO NOT EDIT - GENERATED FROM '$<'"; \
	  echo; \
	  ys -Y $< | $(YS_YAML_TAG_HACK) \
	) > $T
	@if ! [[ -s $T ]]; then \
	  echo "*** Error: failed to generate $@"; \
	  $(RM) -f $T; \
	  exit 1; \
	elif diff $T $@ &>/dev/null; then \
	  echo "*** No changes to $@"; \
	  $(RM) $T; \
	else \
	  echo "*** Updated $@"; \
	  mv $T $@; \
	fi

line1 line2:
	@echo =======================================================================

# yamlscript-1920x1080.png: src/images/yamlscript.svg
# 	svgexport $< $@ 1920:1080 pad
