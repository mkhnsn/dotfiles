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
	@shellcheck -s bash tests/.build/mac-setup tests/.build/mac-setup-server dot_local/bin/executable_mac-defaults dot_local/bin/executable_3dx-sync dot_local/bin/executable_trigger dot_local/bin/executable_keep-awake
	@shellcheck -S warning -s bash tests/*.sh install.sh
	@/bin/bash tests/mac-setup.test.sh
	@/bin/bash tests/chezmoiignore.test.sh
	@/bin/bash tests/claude-sync.test.sh
	@/bin/bash tests/cf-mcp-headers.test.sh
	@python3 -I tests/claude_memory_test.py
	@python3 -I tests/app_prefs_test.py
	@python3 -I tests/shortcut_check_test.py
	@python3 -I tests/brew_why_test.py
	@python3 -I tests/brewfile_check.py
	@python3 -I tests/btt_preset_test.py
	@python3 -I tests/trigger_check_test.py
	@python3 -I tests/hints_test.py
	@python3 -I tests/mode_test.py
	@python3 -I tests/no_pycache_test.py
	@python3 -I tests/streamdeck_library_test.py
	@if command -v docker >/dev/null 2>&1; then docker run --rm -v "$$PWD:/w" -w /w bash:3.2 bash tests/mac-setup.test.sh; fi
