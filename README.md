# dotfiles

## First-time install

```zsh
chezmoi init --apply git@github.com:mkhnsn/dotfiles.git
```

## Force refresh externals (plugins)

```zsh
chezmoi apply -R
```

## If completions get weird

```zsh
rm -f "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"\* 2>/dev/null || true
exec zsh
```
