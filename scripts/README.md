# Bootstrap Scripts

This directory contains the generation tooling for the bootstrap scripts that live in the `bootstrap` repository.

## Structure

```text
scripts/
├── generate-bootstrap.sh        ← Main generator script
├── templates/
│   ├── minimal.sh.template      ← Template for minimal.sh
│   └── full.sh.template         ← Template for full.sh
└── README.md                     ← This file
```

## Purpose

The bootstrap scripts (`minimal.sh` and `full.sh`) live in a **separate public repository** (`bootstrap`), but their logic is defined here as templates. This:

- ✅ Keeps the source of truth in the private dotfiles repo
- ✅ Prevents drift between the two repos
- ✅ Makes it easy to update both at once

## Workflow

### Editing Templates

1. Edit the template you want to change:

   ```bash
   vim scripts/templates/minimal.sh.template
   vim scripts/templates/full.sh.template
   ```

2. Generate the bootstrap scripts:

   ```bash
   make bootstrap-scripts
   # or manually:
   ./scripts/generate-bootstrap.sh
   ```

3. Review the generated files:

   ```bash
   cd ../bootstrap
   git diff minimal.sh full.sh
   ```

4. Commit in both repos:

   ```bash
   # In bootstrap/
   git add minimal.sh full.sh
   git commit -m "scripts: regenerated from dotfiles"

   # In dotfiles/
   git add scripts/templates
   git commit -m "bootstrap: update templates"
   ```

### Important Notes

- **Do NOT edit** `bootstrap/minimal.sh` or `bootstrap/full.sh` directly — they are generated files
- Always edit the `.template` files in this directory
- The generated scripts include a header noting they are auto-generated

## Script Purposes

### minimal.sh

- **Purpose:** Standalone bootstrap to a working shell
- **Deps:** None (self-contained)
- **Requires:** Public access (no authentication needed)
- **Output:** Basic shell environment, git, curl, zsh
- **Use case:** Fresh machine, unknown environment, CI runners

### full.sh

- **Purpose:** Complete machine setup with dotfiles
- **Deps:** Access to private dotfiles repo
- **Requires:** GitHub authentication (for private repo)
- **Output:** All of minimal.sh + chezmoi + dotfiles + Homebrew (macOS)
- **Use case:** Personal machine setup, full configuration

## Testing Generated Scripts

After generating, test both scripts:

```bash
# Test minimal.sh
bash bootstrap/minimal.sh

# Test full.sh
bash bootstrap/full.sh
```

Or in Docker for isolation:

```bash
docker run -it ubuntu:latest bash -c "curl -fsSL https://raw.githubusercontent.com/mkhnsn/bootstrap/main/minimal.sh | bash"
```

## CI/CD Integration

Consider adding a CI check to ensure templates and generated files stay in sync:

```yaml
# .github/workflows/bootstrap-sync.yml
name: Bootstrap Sync

on: [pull_request]

jobs:
  check-sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0
      - name: Check bootstrap scripts are current
        run: |
          ./scripts/generate-bootstrap.sh
          if git diff --quiet bootstrap/; then
            echo "✓ Bootstrap scripts are in sync"
          else
            echo "✗ Bootstrap scripts are out of sync"
            echo "Run: make bootstrap-scripts"
            git diff
            exit 1
          fi
```

Then add to CI so it catches drift before merging.
