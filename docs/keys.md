# Keys

Which key does what, and where each one lives. No private keys are in this repo.

## SSH keys

| Key | Lives in | Used for |
|---|---|---|
| Github (mkhnsn) | 1Password (SSH agent) | Signing commits; GitHub auth for SSH remotes (repos use HTTPS through `gh`, so this is rarely used) |
| Echo-Net Admin SSH Key | 1Password (SSH agent) | SSH into the Macs and servers. Macs get it in `authorized_keys` from 1Password (Automation > "Mac SSH authorized keys"); Linux hosts get it from Ansible. |
| DigitalOcean SSH Key | 1Password (SSH agent) | The DigitalOcean droplet; 1Password writes its `Match` block to `~/.ssh/1Password/config` |
| `~/.ssh/id_ed25519_remote` | On disk, one per machine | Fallback for signing (and SSH remotes) when 1Password can't ask for approval: Claude Code sessions and SSH logins |
| `~/.ssh/claude-memory` (echo-turbine) | On disk, echo-turbine only | Deploy key (read-write) for the private `mkhnsn/claude-memory` repo, set as that clone's `core.sshCommand` (`docs/claude-memory-sync.md`). echo-core's `echo-turbine-claude-memory.yml` playbook makes it if missing. The Macs use HTTPS through `gh` instead. |
| Blink Shell keys | Blink on the iPad and iPhone | SSH into the Macs (Blink can't use 1Password); listed in the same `authorized_keys` note |

`~/.ssh/config` sends every host to the 1Password agent. `~/.config/git/git-ssh` (git's
`core.sshCommand`) and `~/.config/git/ssh-sign` (`gpg.ssh.program`) switch to the
fallback key when `CLAUDECODE`, `SSH_CONNECTION` or `SSH_CLIENT` is set.

## Commit signing

- Commits are signed with SSH keys (`gpg.format = ssh`), never GPG. GnuPG is on the Macs
  only as a Homebrew dependency (poppler); there are no GPG keys.
- `user.signingkey` is the Github (mkhnsn) public key, so local commits go through
  1Password. Claude Code and SSH sessions sign with the machine's fallback key.
- GitHub's signing-key list is the source of truth. `~/.config/git/allowed_signers` is
  rebuilt from it on each `chezmoi apply` (`dot_config/git/modify_allowed_signers`, using
  the public `users/mkhnsn/ssh_signing_keys` API), so `git log --show-signature` trusts
  exactly what GitHub does.
- A new machine generates its fallback key once (`run_once_11-remote-signing-key`). The
  end-of-apply summary reminds you to add it to GitHub as a signing key until it's there.

## Retiring a machine

Remove its fallback key from GitHub (Settings > SSH and GPG keys, both the signing and the
authentication lists), then `chezmoi apply` on the other machines to drop it from
`allowed_signers`. Listing or deleting keys with `gh` needs these extra scopes:

```bash
gh auth refresh -h github.com -s admin:public_key,admin:ssh_signing_key
```
