# Windows Package Manifests

This directory contains package manifests for Windows installation via winget.

## Files

- `common.txt` - Packages installed on all Windows machines
- `windows-only.txt` - Windows-specific tools (Terminal, PowerToys, etc.)
- `{{ hostname }}.txt` - Optional per-machine packages (create as needed)

## Format

Each file should contain one winget package ID per line:
- Comments start with `#`
- Blank lines are ignored
- Package IDs should be exact winget IDs (e.g., `Git.Git`, `Microsoft.VisualStudioCode`)

## Example hostname-specific file

To create a machine-specific manifest, create a file named after your hostname:

```
# manifests/windows/MY-MACHINE.txt

# Work-specific tools
Slack.Slack
Microsoft.Teams

# Dev tools for this machine only
JetBrains.Rider
```

## Finding Package IDs

To find the correct package ID:
```powershell
winget search <package-name>
```

Use the ID from the "Id" column in the results.
