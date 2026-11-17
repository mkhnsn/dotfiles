.PHONY: bootstrap-scripts test
.PHONY: help

# Dotfiles Makefile

help:
	@echo "Available targets:"
	@echo "  make bootstrap-scripts    Generate bootstrap scripts from templates"
	@echo "  make test                 Render scripts, shellcheck them, run tests (bash 3.2 via Docker if present)"
	@echo ""

bootstrap-scripts:
	@./scripts/generate-bootstrap.sh
	@echo ""
	@echo "✓ Bootstrap scripts generated"
	@echo ""
	@echo "To complete the sync:"
	@echo "  1. Review: cd ../bootstrap && git diff"
	@echo "  2. Commit bootstrap: git add *.sh && git commit -m 'scripts: regenerated from dotfiles'"
	@echo "  3. Commit dotfiles: git add scripts/templates && git commit"

test:
	@tests/render.sh
	@shellcheck -s bash tests/.build/mac-setup tests/.build/mac-setup-server dot_local/bin/executable_mac-defaults
	@shellcheck -S warning -s bash tests/*.sh install.sh
	@/bin/bash tests/mac-setup.test.sh
	@python3 -I tests/app_prefs_test.py
	@if command -v docker >/dev/null 2>&1; then docker run --rm -v "$$PWD:/w" -w /w bash:3.2 bash tests/mac-setup.test.sh; fi
