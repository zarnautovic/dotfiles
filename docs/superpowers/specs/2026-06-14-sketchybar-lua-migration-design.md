# SketchyBar → SbarLua migration — design

Date: 2026-06-14
Status: approved design (pre-implementation)
Scope: macOS-only dotfiles managed by chezmoi (`dot_config/sketchybar/`)

## Goal

Migrate the SketchyBar configuration from shell scripts to Lua via
[SbarLua](https://github.com/FelixKratz/SbarLua) (Felix Kratz's Lua bindings
for SketchyBar).

**Chosen goal: 1:1 port + cleanup.** The bar must look and behave identically;
the migration is about architecture/performance plus removing duplication. No
visual redesign.

## Why

- **Performance:** the shell config forks a new process per item per event/tick.
  SbarLua runs a single long-lived Lua process holding all callbacks in memory —
  no per-event shell spawn.
- **Cleanup:** consolidate three icon-map copies into one, share
  colors/defaults instead of `source colors.sh` in every plugin, merge the
  two-file aerospace plugin into one.

## Background — current config (shell)

`dot_config/sketchybar/` (24 files):

- `sketchybarrc` — sets bar (`position=top height=40 blur_radius=10 color=$BAR_COLOR`),
  defaults (fonts `SF Pro:Semibold:12.0`, paddings, `background.corner_radius=5`,
  `background.height=24`), then `source`s items and runs `sketchybar --update`.
- `colors.sh` — exports `WHITE`, `BAR_COLOR`, `ITEM_BG_COLOR`, `ACCENT_COLOR`.
  Active scheme: **Tokyo Night (Storm)** — `BAR_COLOR=0xff24283b`,
  `ITEM_BG_COLOR=0xff2f334d`, `ACCENT_COLOR=0xff7dcfff`, `WHITE=0xffc0caf5`.
  Many other schemes present but commented out.
- `items/*.sh` (8) + `plugins/*.sh` (14): aerospace, front_app, calendar,
  keyboard, volume, battery, cpu, slack.
- `helpers/icon_map.lua` — returns an app-name → `:token:` table
  (sketchybar-app-font). `helpers/icon_map.sh` + `plugins/icon_map_fn.sh` are
  shell equivalents of the same data (redundant).

### AeroSpace integration (unchanged by this migration)

`dot_config/aerospace/aerospace.toml` already drives the bar via:
- `after-startup-command = ['exec-and-forget sketchybar']`
- `exec-on-workspace-change = ['/bin/bash','-c', 'sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=$AEROSPACE_FOCUSED_WORKSPACE; sketchybar --trigger aerospace_windows_change']`

`sketchybar --trigger` hits the running SketchyBar process regardless of how it
is configured (shell or Lua). **`aerospace.toml` needs no changes.**

## Architecture / execution model

| | Now (shell) | After (Lua) |
|---|---|---|
| Entry | `sketchybarrc` adds items with `script=plugins/foo.sh` | `sketchybarrc` is a `#!/usr/bin/env lua` launcher |
| Events | SketchyBar forks the script per event/tick | one persistent Lua process, in-memory callbacks |
| State | stateless per invocation | shared Lua state available |

`sketchybarrc` (Lua launcher) responsibilities:
1. Add the SbarLua module to `package.cpath`
   (`~/.local/share/sketchybar_lua/?.so`).
2. `sbar = require("sketchybar")`.
3. `sbar.begin_config()` → `require("init")` → `sbar.hotload(true)` →
   `sbar.end_config()` (single batched message = fast startup).
4. `sbar.event_loop()` — without this, callbacks never fire.

Items are created with `sbar.add(...)`; logic that lived in `plugins/foo.sh`
becomes an inline `item:subscribe(event, function(env) ... end)` callback in the
same file. Polling items keep `update_freq` and use `:subscribe("routine", fn)`.

## File layout (target)

```
dot_config/sketchybar/
  executable_sketchybarrc   # lua launcher: cpath, begin/end_config, event_loop
  init.lua                  # require: bar, default, then items/*
  bar.lua                   # sbar.bar{ position=top, height=40, blur_radius=10, color=BAR_COLOR }
  colors.lua                # color table (Tokyo Night Storm active)
  default.lua               # sbar.default{ fonts, paddings, background, colors }
  settings.lua              # shared constants (update_freq, fonts)
  items/
    aerospace.lua  front_app.lua  calendar.lua  keyboard.lua
    volume.lua     battery.lua    cpu.lua        slack.lua
  helpers/
    icon_map.lua            # KEPT (app → ":token:" table)
```

Mapping: each `items/foo.sh` + `plugins/foo.sh` → one `items/foo.lua`.
`colors.sh` → `colors.lua`; defaults from `sketchybarrc` → `bar.lua` +
`default.lua`. **Deleted:** `icon_map.sh`, `icon_map_fn.sh`.

## Item mapping

| Item | Model | Lua equivalent | Notes |
|------|-------|----------------|-------|
| front_app | event | `:subscribe("front_app_switched", fn)` → `set{label=env.INFO, icon=icon_map[env.INFO]}` | trivial |
| cpu | polling `update_freq=2` | `add` + `:subscribe("routine", fn)`; `sbar.exec` for `ps`/`sysctl`, parse % | logic from `cpu.sh` |
| battery | polling + event | `update_freq` + `:subscribe("power_source_change", fn)` | icon by percentage |
| volume | event | `:subscribe("volume_change", fn)` (`env.INFO` = level) | |
| slack | polling `update_freq=10` + `system_woke` | `:subscribe("system_woke", fn)` + routine; `sbar.exec("lsappinfo …")`, color by badge | `pgrep` → drawing on/off |
| keyboard | custom NSDistributed event | `sbar.add("event","keyboard_change","AppleSelectedInputSourcesChangedNotification")` then `:subscribe` | |
| calendar | polling | `update_freq` + date formatting; `:subscribe("system_woke", fn)` | |
| aerospace | custom events | see below | most complex |

### aerospace.lua

```lua
sbar.add("event", "aerospace_workspace_change")
sbar.add("event", "aerospace_windows_change")

-- workspace list at startup (io.popen OK at startup, NOT inside callbacks)
for sid in workspaces() do
  local space = sbar.add("item", "space." .. sid, {
    icon = sid, click_script = "aerospace workspace " .. sid, --[[ fonts/colors ]]
  })
  space:subscribe("aerospace_workspace_change", function(env)
    local focused = (sid == env.FOCUSED_WORKSPACE)   -- comes from the --trigger
    space:set{ --[[ highlight focused: background.drawing, label/icon/bg colors ]] }
  end)
  space:subscribe("aerospace_windows_change", function()
    sbar.exec("aerospace list-windows --workspace " .. sid .. " --format '%{app-name}'",
      function(out)
        -- map apps → icons via icon_map; hide empty + unfocused workspace
      end)
  end)
end
```

Cleanup wins (appearance unchanged):
1. Use `env.FOCUSED_WORKSPACE` (sent by the `--trigger`) — drop the extra
   `aerospace list-workspaces --focused` call.
2. Merge `aerospace.sh` + `aerospace_windows.sh` into one file.
3. `local icon_map = require("helpers.icon_map")` → `icon_map[app] or ":default:"`
   instead of invoking `icon_map_fn.sh` per app.

Unchanged: layout (left: aerospace, front_app; right: calendar, keyboard,
volume, battery, cpu, slack), highlight colors, fonts.

## Build & bootstrap (chezmoi)

New `.chezmoiscripts/run_onchange_after_30-sbarlua.sh.tmpl`, darwin-gated,
idempotent (mirrors the existing Linux bootstrap scripts):

```bash
#!/usr/bin/env bash
# Build & install the SbarLua module (Lua bindings for SketchyBar). macOS only.
{{- if eq .chezmoi.os "darwin" }}
set -euo pipefail
SBARLUA_REF=main          # bump this line to force a rebuild on SbarLua update

command -v lua >/dev/null 2>&1 || brew install lua            # interpreter for sketchybarrc
xcode-select -p >/dev/null 2>&1 || xcode-select --install     # clang/make for the build

if [ ! -f "$HOME/.local/share/sketchybar_lua/sketchybar.so" ]; then
  tmp="$(mktemp -d)"
  git clone --depth=1 -b "$SBARLUA_REF" https://github.com/FelixKratz/SbarLua.git "$tmp/SbarLua"
  ( cd "$tmp/SbarLua" && make install )
  rm -rf "$tmp"
fi
sketchybar --reload || brew services restart sketchybar || true
{{- else }}
exit 0
{{- end }}
```

- Naming `run_onchange_after_30-…` follows the existing `<before|after>_NN`
  convention; `after` so the Lua files are written before the reload.
- `run_onchange_` rebuilds when the script changes — bump `SBARLUA_REF` to update.
- **Brewfile:** add `tap "FelixKratz/formulae"`, `brew "sketchybar"`, `brew "lua"`
  (manual path; the bar already runs, this just records the deps).

### Known risk to validate

SbarLua builds the native module; the `.so` must be ABI-compatible with the
`lua` interpreter that runs `sketchybarrc` (brew `lua` is currently 5.4, SbarLua
bundles 5.5). If `.so` loading fails, the bootstrap surfaces it on first run.
Resolve during implementation (pin/match the lua version if needed).

## Error handling

- Inside callbacks use **only** `sbar.exec` — never `os.execute`/`io.popen`
  (they block the event loop thread). `io.popen` at startup (config build) is OK.
- Wrap output parsing in `pcall` and nil-check `sbar.exec` output, so a failure
  in one item cannot crash the whole bar.

## Migration / cutover workflow

1. All work on a `sketchybar-lua` branch in the chezmoi repo.
2. `chezmoi apply` writes the Lua files, the bootstrap builds SbarLua and
   reloads. The new `sketchybarrc` takes over the bar = cutover on this machine.
   The old `.sh` files stay on disk (and on `main`) until verified.
3. User visually verifies via checklist: workspace highlight, per-workspace app
   icons, front_app, clock, keyboard, volume, battery, cpu, slack badge.
4. **Rollback** if broken: `git checkout main && chezmoi apply` restores the
   shell config (still live on `main`).
5. Once confirmed: delete the dead `.sh` files in one commit, merge
   `sketchybar-lua` → `main`, push.

## Out of scope

- Visual redesign (layout, animations, new items).
- Linux (SketchyBar/AeroSpace are macOS-only; already gated in `.chezmoiignore`).
- Changes to `aerospace.toml`.
```
