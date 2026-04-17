# Atelier HAOS

`atelier_haos` gives you an SSH shell inside a Home Assistant add-on with a
persistent `$HOME`, a pinned Atelier shell/editor config, and direct access to
the real Home Assistant config mounted at `/homeassistant`.

## What Persists

- `HOME=/data/home/atelier`
- Codex state under `~/.codex`
- Claude Code state under `~/.claude`
- Zsh history and Neovim state under the persistent home directory
- SSH host keys and rendered `authorized_keys` under `/data/ssh`

## What Is Mounted

- `/homeassistant`: the real Home Assistant config directory, mounted read-write
- `~/workspace/homeassistant`: symlink to `/homeassistant`

Interactive SSH sessions start in `~/workspace`.

## Authentication

- SSH user: `atelier`
- SSH port inside the add-on: `2222`
- Authentication: public key only
- Password login: disabled
- Root login: disabled

The add-on reads `authorized_keys` from the add-on options and rewrites
`/data/ssh/authorized_keys` on each start. If the configured key list is empty,
startup fails.

## Atelier Layout

On first start, the add-on seeds the persistent home with symlinks to the pinned
Atelier checkout in `/opt/atelier`:

- `~/.local/share/atelier -> /opt/atelier`
- `~/.config -> ~/.local/share/atelier/config/dot-config`
- `~/.zshrc -> ~/.local/share/atelier/config/dot-zshrc`
- `~/.zprofile -> ~/.local/share/atelier/config/dot-zprofile`
- `~/.claude/settings.json -> ~/.local/share/atelier/config/dot-claude/settings.json`
- `~/.claude/statusline-command.sh -> ~/.local/share/atelier/config/dot-claude/statusline-command.sh`

If a managed path already exists as a normal file or directory, the add-on
leaves it in place and logs that it was not replaced.

## Local Testing

When running the container outside Home Assistant, create `options.json`
yourself in the host directory you mount to `/data`. For example, if you run
Docker with `-v /tmp/atelier_haos_data:/data`, create the file at
`/tmp/atelier_haos_data/options.json` on the host. The add-on expects the same
JSON shape Home Assistant writes:

```json
{
  "authorized_keys": [
    "ssh-ed25519 AAAA... your-key"
  ],
  "log_level": "info"
}
```

You also need to mount a host directory at `/homeassistant`. For local smoke
tests, an empty writable directory is enough; it does not need to contain a
real Home Assistant config.
