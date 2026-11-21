---
name: dotfiles-doctor
description: Run the dotfiles diagnostics (doctor.sh) and explain what is healthy, what warns and what to fix. Use when asked to check the dotfiles, chezmoi or this machine's setup.
---

# /dotfiles-doctor — Dotfiles Diagnostics

This is a user-invokable skill. Run it as `/dotfiles-doctor` (Claude Code has its own `/doctor`).

## What To Do

1. Run the diagnostics script:

```bash
bash ~/src/github.com/mkhnsn/dotfiles.git/doctor.sh 2>&1 || bash ~/.local/share/chezmoi/doctor.sh 2>&1
```

2. Read the output carefully and summarize:
   - What's healthy (green checks)
   - What's warning (yellow warnings)
   - What's missing or misconfigured

3. If there are warnings or issues, suggest specific fixes. Reference the chezmoi source files that would need to change.

4. If everything looks good, say so briefly.
