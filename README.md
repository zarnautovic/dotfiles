# dotfiles

Personal dotfiles managed with [chezmoi](https://www.chezmoi.io).
Cross-platform: **Arch Linux (Omarchy)** and **macOS (Apple Silicon)**.

## What's included

- **Zsh** config (`.zshrc`) — templated per-OS: PATH, history, completions, tool init
- **Starship** prompt (`.config/starship.toml`)
- **Tmux** config + tokyo-night theme (`.config/tmux/`)
- **Ghostty** terminal config (`.config/ghostty/`) — templated per-OS (Linux-only GTK/epoll keys gated)
- **Zsh plugins** via [Antidote](https://github.com/mattmc3/antidote) — auto-bootstraps on
  first launch:
  - [`zsh-autosuggestions`](https://github.com/zsh-users/zsh-autosuggestions) — fish-like history suggestions
  - [`fast-syntax-highlighting`](https://github.com/zdharma-continuum/fast-syntax-highlighting) — command-line highlighting

## What to install

| Tool | Required? | Used for |
| --- | --- | --- |
| `chezmoi` | **required** | apply the dotfiles |
| `git` | **required** | clone repo + Antidote plugins |
| `zsh` | **required** | the shell itself |
| `starship` | recommended | the prompt |
| `mise` | recommended | runtime version management (node, etc.) |
| `zoxide` | recommended | smart `cd` |
| `fzf` + `bat` | recommended | `ff` / `eff` fuzzy file finder & previews |
| `eza` | recommended | `ls` / `lt` listing aliases |
| `tmux` | recommended | `t`, `tdl`, `tsl` layouts |
| `neovim` | recommended | `n`, `eff` editor |
| `gum` | recommended | `gd` worktree prompt |
| `ghostty` | optional | terminal emulator (only if you use the tracked ghostty config) |
| JetBrainsMono Nerd Font | recommended | prompt & terminal glyphs |

Everything in `.zshrc` is guarded with `command -v`, so the config applies and loads
cleanly even if the recommended tools are missing — you just don't get that feature.

## Install

### Arch Linux

> On **Omarchy**, most of these are already installed — at minimum you only need `zsh`.

```bash
sudo pacman -S --needed \
  zsh chezmoi git \
  starship mise zoxide fzf bat eza tmux neovim gum \
  ghostty

chezmoi init --apply zarnautovic/dotfiles
chsh -s /usr/bin/zsh        # then log out and back in
```

### macOS (Apple Silicon)

> zsh is already the default shell on macOS — no `chsh` needed.

```bash
# Install Homebrew first if you don't have it:
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

brew install \
  chezmoi git \
  starship mise zoxide fzf bat eza tmux neovim gum
brew install --cask ghostty font-jetbrains-mono-nerd-font

chezmoi init --apply zarnautovic/dotfiles
```

## After installing

- Restart your shell (or log out / back in).
- Antidote clones the plugins automatically on first launch (needs git + network).
- **Secrets are not tracked.** Put machine-local env/secrets in `~/.zshrc.local`
  (auto-sourced, untracked), or use `gh auth login` for GitHub access.

## Day-to-day

```bash
chezmoi update          # pull latest from the repo and apply
chezmoi edit <file>     # edit a tracked dotfile (opens the source)
chezmoi apply           # apply pending changes
chezmoi diff            # preview what apply would change
```
