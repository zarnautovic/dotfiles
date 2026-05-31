# dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io).
Cross-platform: **Arch Linux (Hyprland + Noctalia)** and **macOS (Apple Silicon)**.

## What's included

**Shared (both OS)**
- **Zsh** (`.zshrc`) — templated per-OS: PATH, history, completions, tool init
- **Starship** prompt, **Tmux** (+ tokyo-night theme, tpm, powerkit)
- **Ghostty** terminal — themed with **Rose Piné** to match the desktop
- **Zsh plugins** via [Antidote](https://github.com/mattmc3/antidote) (auto-bootstraps):
  `zsh-autosuggestions`, `fast-syntax-highlighting`
- Aliases & functions (git worktrees, tmux AI-dev layouts, ssh forwarding, …)

**Linux only (Arch + Hyprland)**
- **Hyprland** (`.config/hypr/`) — `hyprland.conf`, `hypridle.conf`, per-host `monitors.conf`
- **Noctalia** (`.config/noctalia/`) — the Quickshell desktop shell (bar, launcher,
  notifications, lock screen, OSD, wallpaper). *Settings captured after first run.*

## Architecture

```
.chezmoiignore                 # templated: hides linux-only paths on macOS, Brewfile on Linux
.chezmoiscripts/               # Linux-gated bootstrap (no-ops on macOS)
  run_onchange_before_10-packages.sh.tmpl     # pacman + yay (incl. noctalia-shell)
  run_onchange_after_20-sddm-theme.sh.tmpl    # Noctalia SDDM theme + /etc/sddm.conf.d
Brewfile                       # macOS — run manually
dot_config/{ghostty,starship,tmux,zsh}        # shared
dot_config/{hypr,noctalia}                    # linux-only
dot_zshrc.tmpl  dot_zsh_plugins.txt           # shared
```

The desktop stack: **SDDM** (login, Noctalia theme) → **uwsm** launches **Hyprland** →
**Noctalia** shell. Idle/lock via **hypridle** → Noctalia lock. File manager: **Thunar**.

## Install

### Arch Linux (fresh box → full desktop)

```bash
sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply zarnautovic/dotfiles
```
This applies the dotfiles **and** runs the Linux bootstrap (installs packages via
pacman/yay, installs the Noctalia SDDM theme). You'll be prompted for `sudo`.

Then set zsh as your shell:
```bash
chsh -s /usr/bin/zsh
```

### macOS (Apple Silicon)

```bash
# Homebrew first if needed:
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

sh -c "$(curl -fsLS get.chezmoi.io)" -- init --apply zarnautovic/dotfiles
brew bundle --file=~/Brewfile      # manual — nothing auto-installs on macOS
```
The Linux/desktop scripts are inert on macOS; only the shared configs apply.

## First-run checklist (Linux)

1. **Capture Noctalia settings** once you've tuned them in its GUI:
   ```bash
   chezmoi add ~/.config/noctalia/settings.json
   ```
   (Not hand-authored — Noctalia uses a versioned, auto-migrated schema.)
2. **Test** the new session: log out, pick *Hyprland (uwsm)* at SDDM, verify the desktop.
3. **Cutover** GDM → SDDM (only after testing; keep a TTY ready, Ctrl+Alt+F3):
   ```bash
   sudo systemctl disable gdm.service
   sudo systemctl enable sddm.service
   ```
4. **Remove kitty** once ghostty is confirmed: `sudo pacman -Rns kitty`
5. **Remove GNOME** (scorched earth) — *from a TTY, never inside a session*:
   ```bash
   sudo pacman -Rns $(pacman -Qgq gnome) gdm
   sudo pacman -S --needed gnome-keyring xdg-desktop-portal-gtk
   ```

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
