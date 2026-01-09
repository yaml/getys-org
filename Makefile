M := .cache/makes
$(shell [ -d $M ] || ( git clone -q https://github.com/makeplus/makes $M))

include $M/init.mk
include $M/python.mk
include $M/yamlscript.mk
include $M/clean.mk
include $M/shell.mk


PYTHON-VENV-SETUP := pip install -r requirements.txt

CONFIG := mkdocs.yml

MKDOCS-MATERIAL-VERSION := 9.5.50
MKDOCS-MATERIAL-REPO := https://github.com/squidfunk/mkdocs-material

WATCHER := watchmedo shell-command
WATCH := \
  util/mdys \
  mkdocs.ys \
  config/ \
  Makefile \

null :=
space := ${null} ${null}

T := /tmp/ys-website.tmp

WATCH := $(subst $(space),;,$(WATCH))

DEPS := \
  $(PYTHON-VENV) \
  $(CONFIG) \
  src/run \


default::

deps: line1 $(DEPS) line2

ifeq (live,$(website))
  YS-WWW-DOMAIN := getys.org
  YS-WWW-REMOTE := git@github.com:yaml/getys-org
  YS-WWW-BRANCH ?= gh-pages
else ifeq (stage,$(website))
  export YS-WWW-DEV := true
  YS-WWW-DOMAIN := stage.getys.org
  YS-WWW-REMOTE := git@github.com:yaml/stage-getys-org
  YS-WWW-BRANCH := site
endif

build:: $(DEPS)
	$(RM) -r site
	git worktree add -f site
	$(RM) -r site/*
	mkdocs build
	echo $(YS-WWW-DOMAIN) > site/CNAME
	git -C site add -A

# serve: $(DEPS) watch

serve: $(DEPS)
	mkdocs serve

deps-update: deps-update-notify deps

deps-update-notify:
	: *** Rebuilding dependencies ***

# XXX - See 'mkdocs gh-deploy' for a more standard way to do this
# Options remote_branch and remote_name are used for gh-deploy
ifeq (,$(YS-WWW-REMOTE))
publish:
	$(error Use 'make publish website=<live|stage>' to publish)
else
publish: build
	-git -C site commit -m "Publish $$(date)"
	git -C site push $(YS-WWW-REMOTE) HEAD:$(YS-WWW-BRANCH) --force
	@echo
	@echo "Published to https://$(YS-WWW-DOMAIN)"
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
	  --branch $(MKDOCS-MATERIAL-VERSION) \
	  $(MKDOCS-MATERIAL-REPO) $@
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

pip-install: $(PYTHON-VENV)
ifeq (,$(m))
	@echo 'm=<module> is not set'
	@exit 1
endif
	pip install $m
	pip freeze > requirements.txt

clean::
	killall watchmedo || true
	$(RM) $(CONFIG) sample $T src/run
	$(RM) -r site

src/run:
	curl -s https://yamlscript.org/run-ys > $@

# YS doesn't support !!python tags yet.
# This hack is a workaround to preserve them.
YS-YAML-TAG-HACK := perl -pe 's{: \+!}{: !}'

$(CONFIG): mkdocs.ys config/* $(YS)
	@( \
	  set -euo pipefail; \
	  echo "# DO NOT EDIT - GENERATED FROM '$<'"; \
	  echo; \
	  ys -Y $< | $(YS-YAML-TAG-HACK) \
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
