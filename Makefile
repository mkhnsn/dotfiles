.PHONY: test
.PHONY: help

# Dotfiles Makefile

help:
	@echo "Available targets:"
	@echo "  make test                 Render scripts, shellcheck them, run tests (bash 3.2 via Docker if present)"
	@echo ""

test:
	@tests/render.sh
	@shellcheck -s bash tests/.build/mac-setup tests/.build/mac-setup-server dot_local/bin/executable_mac-defaults dot_local/bin/executable_3dx-sync dot_local/bin/executable_trigger dot_local/bin/executable_keep-awake
	@shellcheck -S warning -s bash tests/*.sh install.sh
	@/bin/bash tests/mac-setup.test.sh
	@/bin/bash tests/chezmoiignore.test.sh
	@/bin/bash tests/op-service-token.test.sh
	@/bin/bash tests/claude-sync.test.sh
	@/bin/bash tests/cf-mcp-headers.test.sh
	@/bin/bash tests/shell-path.test.sh
	@python3 -I tests/claude_memory_test.py
	@python3 -I tests/app_prefs_test.py
	@python3 -I tests/shortcut_check_test.py
	@python3 -I tests/brew_why_test.py
	@python3 -I tests/brewfile_check.py
	@python3 -I tests/btt_preset_test.py
	@python3 -I tests/trigger_check_test.py
	@python3 -I tests/hints_test.py
	@python3 -I tests/layout_test.py
	@python3 -I tests/no_pycache_test.py
	@python3 -I tests/streamdeck_library_test.py
	@if command -v docker >/dev/null 2>&1; then COPYFILE_DISABLE=1 tar -c --exclude=.git . | docker run --rm -i -w /w bash:3.2 bash -c 'mkdir -p /w && tar -x -C /w && bash tests/mac-setup.test.sh'; fi
