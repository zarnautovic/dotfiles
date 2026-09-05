# dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io).
Cross-platform: **Arch Linux (Hyprland + Noctalia)** and **macOS (Apple Silicon)**.

## What's included

**Shared (both OS)**
- **Zsh** (`.zshrc`) — templated per-OS: PATH, history, completions, tool init
- **Starship** prompt, **Tmux** (+ Rosé Pine theme, tpm, powerkit)
- **Ghostty** terminal — themed with **Rose Piné** to match the desktop
- **Zsh plugins** via [Antidote](https://github.com/mattmc3/antidote) (auto-bootstraps):
  `zsh-autosuggestions`, `fast-syntax-highlighting`
- **[herdr](https://herdr.dev)** — terminal multiplexer for AI coding agents.
  Auto-installed on both OSes by `.chezmoiscripts/40-herdr` (static binary in
  `~/.local/bin`, no root); zsh completions wired up in `.zshrc`.
  Upgrade in place with `herdr update`.
- Aliases & functions (git worktrees, tmux AI-dev layouts, ssh forwarding, …)

**Linux only (Arch + Hyprland)**
- **Hyprland** (`.config/hypr/`) — `hyprland.lua`, `hypridle.conf`, per-host `monitors.lua`
- **Noctalia** (`.config/noctalia/config.toml`) — the v5 native-Wayland desktop shell
  (bar, launcher, notifications, lock screen, OSD, wallpaper, app theming).

## Architecture

```
.chezmoiignore                 # templated: hides linux-only paths on macOS, Brewfile on Linux
.chezmoiscripts/               # bootstrap; each script gates on .chezmoi.os
  run_onchange_before_10-packages.sh.tmpl     # linux: pacman + yay (incl. noctalia-shell)
  run_onchange_after_20-sddm-theme.sh.tmpl    # linux: Noctalia SDDM theme + /etc/sddm.conf.d
  run_onchange_after_30-sbarlua.sh.tmpl       # macos: SbarLua module for SketchyBar
  run_onchange_after_40-herdr.sh.tmpl         # both:  herdr via herdr.dev/install.sh
Brewfile                       # macOS — run manually
dot_config/{ghostty,starship,tmux,zsh}        # shared
dot_config/{hypr,noctalia}                    # linux-only
dot_zshrc.tmpl  dot_zsh_plugins.txt           # shared
```

The desktop stack: **SDDM** (login, Noctalia theme) → **uwsm** launches **Hyprland** →
**Noctalia** shell. Idle/lock via **hypridle** → Noctalia lock. File manager: **Thunar**.

## Install

### Arch Linux (clean install → full desktop)

**Prerequisites:** a base Arch system that boots to a TTY, an active network
connection, and a non-root user with `sudo`. The bootstrap pulls everything else.

```bash
# 1. Make sure git + curl exist (minimal installs may lack them)
sudo pacman -S --needed --noconfirm git curl

# 2. Install + apply the dotfiles. This runs the Linux bootstrap automatically.
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply zarnautovic/dotfiles
```

`--apply` runs `.chezmoiscripts/` (you'll be prompted for `sudo`), which:
- installs all packages via **pacman** — incl. `hyprland`, `noctalia`, `sddm`, `uwsm`, the
  `xdg-desktop-portal-hyprland`/`-gtk` portals, pipewire stack, Thunar, NetworkManager;
- builds **yay** from the AUR (if missing) for the remaining AUR apps;
- bootstraps **tmux** plugins (tpm + powerkit) under `~/.config/tmux/plugins/`;
- installs the **Noctalia SDDM** theme and writes `/etc/sddm.conf.d/10-noctalia.conf`;
- **enables `NetworkManager` and `sddm`** (`enable` only — SDDM takes over on the
  next reboot, it won't kill the running session).

The only thing left is your login shell, then reboot:

```bash
chsh -s /usr/bin/zsh     # make zsh your login shell
reboot
```

At the **SDDM** login screen choose the **Hyprland (uwsm)** session and log in.
Antidote (zsh plugins) self-bootstraps on your first interactive shell.

### macOS (Apple Silicon)

```bash
# Homebrew first if needed:
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply zarnautovic/dotfiles
brew bundle --file=~/Brewfile      # manual — Homebrew packages don't auto-install
```
The Linux/desktop scripts are inert on macOS. What does run there: the SbarLua
build (`30-sbarlua`) and the herdr install (`40-herdr`) — plus the shared configs.

## After first login (Linux)

- **Noctalia settings:** the tracked `~/.config/noctalia/config.toml` is the source of
  truth. Changes made in the Settings GUI land in `~/.local/state/noctalia/settings.toml`
  (untracked, per-machine overrides) — fold anything you want to keep back into
  `config.toml` (`noctalia config export` prints the merged user config).
- **Per-machine monitors:** set your outputs/transforms in `~/.config/hypr/monitors.lua`,
  then `chezmoi add` it. Inspect outputs with `hyprctl monitors all`.
- **tmux** plugins were bootstrapped by the installer; inside tmux, `prefix + I`
  reinstalls/updates them at any time (`prefix` is `C-s`).

## Notes

- **Secrets are not tracked.** Machine-local env/secrets go in `~/.zshrc.local`
  (auto-sourced, untracked).
- **Per-machine monitors:** edit `~/.config/hypr/monitors.conf`.
- Everything in `.zshrc` is guarded with `command -v`, so it loads cleanly even when
  optional tools are missing.

## Day-to-day

```bash
chezmoi update          # pull latest from the repo and apply
chezmoi edit <file>     # edit a tracked dotfile (opens the source)
chezmoi apply           # apply pending changes
chezmoi diff            # preview what apply would change
```
