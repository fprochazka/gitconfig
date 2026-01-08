.PHONY: lint lint-all check test test-help help

SHELL := /bin/bash
SCRIPTS := $(shell find bin -type f -name 'git-*' -executable) $(wildcard bin/lib/*.sh)

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-15s\033[0m %s\n", $$1, $$2}'

lint: ## Run shellcheck on all scripts
	@echo "Running shellcheck on $(words $(SCRIPTS)) scripts..."
	@shellcheck --shell=bash --severity=warning $(SCRIPTS)
	@echo "All scripts passed shellcheck"

lint-all: ## Run shellcheck with all severity levels (including style)
	@shellcheck --shell=bash --severity=style $(SCRIPTS)

check: lint ## Alias for lint

test: ## Run syntax check on all scripts
	@echo "Running bash syntax check..."
	@for script in $(SCRIPTS); do \
		bash -n "$$script" || exit 1; \
	done
	@echo "All scripts passed syntax check"

test-help: ## Verify all scripts respond to --help
	@echo "Testing --help for all git-* commands..."
	@for script in bin/git-*; do \
		if [[ -x "$$script" ]]; then \
			"$$script" --help >/dev/null 2>&1 || { echo "FAIL: $$script --help"; exit 1; }; \
		fi; \
	done
	@echo "All scripts respond to --help correctly"
