.PHONY: bootstrap-scripts
.PHONY: help

# Dotfiles Makefile

help:
	@echo "Available targets:"
	@echo "  make bootstrap-scripts    Generate bootstrap scripts from templates"
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
