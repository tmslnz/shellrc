# Thin entry points. The test logic lives in tests/run.sh.
#
#   make                  # lint + test
#   make test SHELLS=bash # limit to some shells

SHELLS ?= dash bash zsh

.PHONY: check lint test

check: lint test

lint:
	@for s in $(SHELLS); do \
		if command -v $$s >/dev/null 2>&1; then \
			echo "$$s -n shellrc"; $$s -n shellrc || exit 1; \
		else \
			echo "$$s not installed, skipped"; \
		fi; \
	done
	@if command -v shellcheck >/dev/null 2>&1; then \
		echo "shellcheck shellrc tests/run.sh"; shellcheck shellrc tests/run.sh; \
	else \
		echo "shellcheck not installed, skipped"; \
	fi

test:
	@sh tests/run.sh $(SHELLS)
