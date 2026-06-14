# SketchyBar → SbarLua migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port the macOS SketchyBar config from shell scripts to Lua (SbarLua), keeping the bar visually/behaviorally identical while removing duplication, all tracked in chezmoi and gated to macOS.

**Architecture:** SbarLua replaces the per-event shell-script model with one long-lived Lua process. `sketchybarrc` becomes a `lua` launcher that loads `init.lua`, which requires `bar`, `default`, and one file per item under `items/`. Each item file creates its item with `sbar.add` and registers its logic as inline `:subscribe(event, fn)` callbacks. The native module is built on each Mac by an idempotent chezmoi `run_onchange` bootstrap script.

**Tech Stack:** Lua 5.x, [SbarLua](https://github.com/FelixKratz/SbarLua), SketchyBar, AeroSpace, chezmoi, Homebrew. macOS (Apple Silicon) only.

**Spec:** `docs/superpowers/specs/2026-06-14-sketchybar-lua-migration-design.md`

---

## Conventions used in every task

- **Source dir** (chezmoi): `~/.local/share/chezmoi/dot_config/sketchybar/`
- **Deployed dir** (live): `~/.config/sketchybar/`
- **Edit source → `chezmoi apply` → reload → verify.** Never edit the live dir directly.
- **Syntax check:** `luac -p <file>` (compiles, does not execute — safe for files that `require("sketchybar")`).
- **Reload:** `sketchybar --reload` (re-runs `sketchybarrc`, restarting the Lua process).
- **Commit:** on branch `sketchybar-lua`, no `Co-Authored-By` trailer (machine preference).
- **Lua module names** are global-`sbar` based (the launcher sets `sbar` global before requiring anything), matching the upstream example. Each module still does `local colors = require("colors")` etc. for its own deps.

## Open runtime assumptions (verify while executing — do not assume)

These are best-effort translations of runtime behavior that cannot be unit-tested headlessly. Watch for them during the reload+verify steps:

1. **lua ABI:** the SbarLua `.so` must load in the `lua` that runs `sketchybarrc`. brew `lua` is currently 5.4; SbarLua may build against 5.5. If the bar fails to start, run `lua ~/.config/sketchybar/sketchybarrc` manually and read the error (Task 1 verify covers this).
2. **`sbar.exec` runs via a shell** (so pipes/`$(...)`/redirection work). Confirmed by upstream examples (`pmset -g batt`, yabai pipelines). If a piped command misbehaves, wrap as `sbar.exec("/bin/sh -c '…'", fn)`.
3. **Polling** items render on `"routine"` (every `update_freq`) and `"forced"` (initial). Confirmed by upstream `calendar.lua`/`battery.lua`.
4. **`:set` text** uses `{ string = "…" }`; colors are integers like `0xff7dcfff`; dot-props nest (`icon.color` → `icon = { color = … }`). Confirmed by upstream examples.

---

## Task 1: Branch, SbarLua bootstrap, and Brewfile deps

**Files:**
- Create: `~/.local/share/chezmoi/.chezmoiscripts/run_onchange_after_30-sbarlua.sh.tmpl`
- Modify: `~/.local/share/chezmoi/Brewfile`

- [ ] **Step 1: Create the migration branch**

```bash
cd ~/.local/share/chezmoi
git checkout -b sketchybar-lua
git rev-parse --abbrev-ref HEAD   # expect: sketchybar-lua
```

- [ ] **Step 2: Write the bootstrap script**

Create `.chezmoiscripts/run_onchange_after_30-sbarlua.sh.tmpl`:

```bash
#!/usr/bin/env bash
# Build & install the SbarLua module (Lua bindings for SketchyBar). macOS only.
# Idempotent: skips the clone/build if the module is already present.
{{- if eq .chezmoi.os "darwin" }}
set -euo pipefail
SBARLUA_REF=main          # bump this line to force a rebuild on a SbarLua update

command -v lua >/dev/null 2>&1 || brew install lua            # interpreter for sketchybarrc
xcode-select -p >/dev/null 2>&1 || xcode-select --install     # clang/make for the build

if [ ! -f "$HOME/.local/share/sketchybar_lua/sketchybar.so" ]; then
  echo "==> Building SbarLua module…"
  tmp="$(mktemp -d)"
  git clone --depth=1 -b "$SBARLUA_REF" https://github.com/FelixKratz/SbarLua.git "$tmp/SbarLua"
  ( cd "$tmp/SbarLua" && make install )
  rm -rf "$tmp"
fi

sketchybar --reload 2>/dev/null || brew services restart sketchybar 2>/dev/null || true
{{- else }}
exit 0
{{- end }}
```

- [ ] **Step 3: Add deps to the Brewfile**

In `~/.local/share/chezmoi/Brewfile`, add the SketchyBar tap and packages. Change:

```
cask "ghostty"
cask "font-jetbrains-mono-nerd-font"
```

to:

```
cask "ghostty"
cask "font-jetbrains-mono-nerd-font"

# SketchyBar + Lua (SbarLua config). Tap hosts the sketchybar formula.
tap "FelixKratz/formulae"
brew "sketchybar"
brew "lua"
```

- [ ] **Step 4: Verify the template renders on darwin**

```bash
cd ~/.local/share/chezmoi
chezmoi execute-template < .chezmoiscripts/run_onchange_after_30-sbarlua.sh.tmpl | head -5
```
Expected: starts with `#!/usr/bin/env bash` and shows the `set -euo pipefail` body (NOT `exit 0`).

- [ ] **Step 5: Apply — bootstrap builds the module**

```bash
cd ~/.local/share/chezmoi
chezmoi apply
ls -l ~/.local/share/sketchybar_lua/sketchybar.so
```
Expected: `sketchybar.so` exists. If the build fails on Command Line Tools, run `xcode-select --install`, finish the GUI install, and re-run `chezmoi apply`.

- [ ] **Step 6: Confirm `lua` can load the module (ABI check — assumption #1)**

```bash
lua -e 'package.cpath=package.cpath..";"..os.getenv("HOME").."/.local/share/sketchybar_lua/?.so"; assert(require("sketchybar")); print("sbarlua OK")'
```
Expected: `sbarlua OK`. If it errors with a version mismatch, reconcile the `lua` version with what SbarLua built against before continuing (see assumption #1).

- [ ] **Step 7: Commit**

```bash
cd ~/.local/share/chezmoi
git add .chezmoiscripts/run_onchange_after_30-sbarlua.sh.tmpl Brewfile
git commit -m "sketchybar: add SbarLua build bootstrap + brew deps"
```

---

## Task 2: Core skeleton (launcher + shared modules → empty Lua bar)

This is the **cutover point**: after this task the bar is Lua-driven (empty of items, correct color/size). Old shell `.sh` files remain on disk but are no longer sourced.

**Files (all under `~/.local/share/chezmoi/dot_config/sketchybar/`):**
- Modify: `executable_sketchybarrc` (replace shell content with Lua launcher)
- Create: `init.lua`, `settings.lua`, `colors.lua`, `bar.lua`, `default.lua`

- [ ] **Step 1: Write the launcher** — `executable_sketchybarrc`

```lua
#!/usr/bin/env lua

-- Load the SbarLua native module
package.cpath = package.cpath .. ";" .. os.getenv("HOME") .. "/.local/share/sketchybar_lua/?.so"
-- Resolve our own config modules regardless of cwd
package.path = package.path .. ";" .. os.getenv("HOME") .. "/.config/sketchybar/?.lua"

sbar = require("sketchybar")

-- Batch the whole initial config into one message for fast startup
sbar.begin_config()
require("init")
sbar.hotload(true)
sbar.end_config()

-- Keep the process alive so callbacks fire
sbar.event_loop()
```

- [ ] **Step 2: Write `settings.lua`** (shared constants — DRY)

```lua
return {
  font = "SF Pro:Semibold:12.0",
  app_font = "sketchybar-app-font:Regular:16.0",
}
```

- [ ] **Step 3: Write `colors.lua`** (Tokyo Night Storm — the active scheme from `colors.sh`)

```lua
return {
  white = 0xffc0caf5,
  bar = 0xff24283b,      -- BAR_COLOR
  item_bg = 0xff2f334d,  -- ITEM_BG_COLOR
  accent = 0xff7dcfff,   -- ACCENT_COLOR (cyan)
}
```

- [ ] **Step 4: Write `bar.lua`** (from `sketchybar --bar position=top height=40 blur_radius=10 color=$BAR_COLOR`)

```lua
local colors = require("colors")

sbar.bar({
  position = "top",
  height = 40,
  blur_radius = 10,
  color = colors.bar,
})
```

- [ ] **Step 5: Write `default.lua`** (from the `default=(…)` array in the old `sketchybarrc`)

```lua
local colors = require("colors")
local settings = require("settings")

sbar.default({
  padding_left = 2,
  padding_right = 2,
  icon = {
    font = settings.font,
    color = colors.white,
    padding_left = 2,
    padding_right = 5,
  },
  label = {
    font = settings.font,
    color = colors.white,
    padding_left = 5,
    padding_right = 4,
  },
  background = {
    color = colors.item_bg,
    corner_radius = 5,
    height = 24,
  },
})
```

- [ ] **Step 6: Write `init.lua`** (loads bar + defaults; item requires added in later tasks, in left→right order)

```lua
require("bar")
require("default")

-- Items are wired in over Tasks 3–10 (order preserves on-bar placement):
-- left:  aerospace, front_app
-- right: calendar, keyboard, volume, battery, cpu, slack
```

- [ ] **Step 7: Syntax-check all new Lua files**

```bash
cd ~/.local/share/chezmoi/dot_config/sketchybar
for f in sketchybarrc init.lua settings.lua colors.lua bar.lua default.lua; do luac -p "$f" && echo "OK $f"; done
```
Expected: `OK` for each (no parse errors).

- [ ] **Step 8: Apply + reload + verify empty bar**

```bash
cd ~/.local/share/chezmoi && chezmoi apply
sketchybar --reload
```
Expected: the bar appears at the top, height 40, dark Tokyo-Night background. No items yet. (If the bar is blank/crashed, run `lua ~/.config/sketchybar/sketchybarrc` to read the error.)

- [ ] **Step 9: Commit**

```bash
cd ~/.local/share/chezmoi
git add dot_config/sketchybar/executable_sketchybarrc dot_config/sketchybar/init.lua \
        dot_config/sketchybar/settings.lua dot_config/sketchybar/colors.lua \
        dot_config/sketchybar/bar.lua dot_config/sketchybar/default.lua
git commit -m "sketchybar: Lua launcher + bar/default/colors/settings skeleton"
```

---

## Task 3: front_app item (+ icon_map module check)

Establishes the event-callback + `icon_map` pattern. `helpers/icon_map.lua` already exists (returns an app→`:token:` table) and is kept as-is.

**Files:**
- Create: `dot_config/sketchybar/items/front_app.lua`
- Modify: `dot_config/sketchybar/init.lua`

- [ ] **Step 1: Verify `icon_map.lua` is require-able and maps a known app**

```bash
cd ~/.config/sketchybar
lua -e 'package.path=package.path..";./?.lua"; local m=require("helpers.icon_map"); assert(m["Zed"]==":zed:", "got "..tostring(m["Zed"])); print("icon_map OK")'
```
Expected: `icon_map OK`. (Confirms the table is a valid module returning app→token.)

- [ ] **Step 2: Write `items/front_app.lua`**

From `items/front_app.sh` (accent bg, bar-colored icon/label, app-font icon) + `plugins/front_app.sh` (label=app name, icon=mapped glyph):

```lua
local colors = require("colors")
local settings = require("settings")
local icon_map = require("helpers.icon_map")

local front_app = sbar.add("item", "front_app", {
  position = "left",
  background = { color = colors.accent },
  icon = { color = colors.bar, font = settings.app_font },
  label = { color = colors.bar },
})

front_app:subscribe("front_app_switched", function(env)
  front_app:set({
    icon = { string = icon_map[env.INFO] or ":default:" },
    label = { string = env.INFO },
  })
end)
```

- [ ] **Step 3: Wire it into `init.lua`**

Add after `require("default")`:

```lua
require("items.front_app")
```

- [ ] **Step 4: Syntax check**

```bash
cd ~/.local/share/chezmoi/dot_config/sketchybar && luac -p items/front_app.lua && echo OK
```
Expected: `OK`.

- [ ] **Step 5: Apply + reload + verify**

```bash
cd ~/.local/share/chezmoi && chezmoi apply && sketchybar --reload
```
Expected: a left-side item with an accent (cyan) background showing the focused app's logo + name. Switch apps → icon/name update.

- [ ] **Step 6: Commit**

```bash
cd ~/.local/share/chezmoi
git add dot_config/sketchybar/items/front_app.lua dot_config/sketchybar/init.lua
git commit -m "sketchybar: port front_app to Lua"
```

---

## Task 4: calendar item

**Files:**
- Create: `dot_config/sketchybar/items/calendar.lua`
- Modify: `dot_config/sketchybar/init.lua`

- [ ] **Step 1: Write `items/calendar.lua`**

From `items/calendar.sh` (icon 􀧞, `update_freq=30`) + `plugins/calendar.sh` (`date +'%a %d %b %I:%M %p'`). Uses `os.date` directly (no shell spawn):

```lua
local calendar = sbar.add("item", "calendar", {
  position = "right",
  update_freq = 30,
  icon = { string = "􀧞" },
})

local function update()
  calendar:set({ label = { string = os.date("%a %d %b %I:%M %p") } })
end

calendar:subscribe("routine", update)
calendar:subscribe("forced", update)
```

- [ ] **Step 2: Wire into `init.lua`** — add after the front_app require:

```lua
require("items.calendar")
```

- [ ] **Step 3: Syntax check**

```bash
cd ~/.local/share/chezmoi/dot_config/sketchybar && luac -p items/calendar.lua && echo OK
```
Expected: `OK`.

- [ ] **Step 4: Apply + reload + verify**

```bash
cd ~/.local/share/chezmoi && chezmoi apply && sketchybar --reload
```
Expected: right-side clock like `Sun 14 Jun 05:30 PM`, updating.

- [ ] **Step 5: Commit**

```bash
cd ~/.local/share/chezmoi
git add dot_config/sketchybar/items/calendar.lua dot_config/sketchybar/init.lua
git commit -m "sketchybar: port calendar to Lua"
```

---

## Task 5: cpu item

**Files:**
- Create: `dot_config/sketchybar/items/cpu.lua`
- Modify: `dot_config/sketchybar/init.lua`

- [ ] **Step 1: Write `items/cpu.lua`**

From `items/cpu.sh` (icon 􀧓, `update_freq=2`) + `plugins/cpu.sh`. The original shell pipeline is preserved verbatim inside a Lua long-bracket string (no escaping) and run via `sbar.exec`:

```lua
local cpu = sbar.add("item", "cpu", {
  position = "right",
  update_freq = 2,
  icon = { string = "􀧓" },
})

local CPU_CMD = [[
CORE_COUNT=$(sysctl -n machdep.cpu.thread_count)
CPU_INFO=$(ps -eo pcpu,user)
CPU_SYS=$(echo "$CPU_INFO" | grep -v $(whoami) | sed "s/[^ 0-9\.]//g" | awk "{sum+=\$1} END {print sum/(100.0 * $CORE_COUNT)}")
CPU_USER=$(echo "$CPU_INFO" | grep $(whoami) | sed "s/[^ 0-9\.]//g" | awk "{sum+=\$1} END {print sum/(100.0 * $CORE_COUNT)}")
echo "$CPU_SYS $CPU_USER" | awk '{printf "%.0f", ($1 + $2)*100}'
]]

local function update()
  sbar.exec(CPU_CMD, function(out)
    local pct = (out or ""):match("%d+")
    if pct then cpu:set({ label = { string = pct .. "%" } }) end
  end)
end

cpu:subscribe("routine", update)
cpu:subscribe("forced", update)
```

- [ ] **Step 2: Wire into `init.lua`** — calendar/keyboard/volume/battery come before cpu on the bar; add the require in the right-side order. For now append after the calendar require (later tasks insert keyboard/volume/battery ahead of it):

```lua
require("items.cpu")
```

> Note: final right-side require order in `init.lua` must be `calendar, keyboard, volume, battery, cpu, slack`. Each task inserts its require in that position; if you implement out of order, fix the order in Task 10's final check.

- [ ] **Step 3: Syntax check**

```bash
cd ~/.local/share/chezmoi/dot_config/sketchybar && luac -p items/cpu.lua && echo OK
```
Expected: `OK`.

- [ ] **Step 4: Apply + reload + verify**

```bash
cd ~/.local/share/chezmoi && chezmoi apply && sketchybar --reload
```
Expected: right-side CPU percentage (e.g. `4%`), refreshing every 2s. If it stays blank, verify assumption #2 (wrap `CPU_CMD` in `/bin/sh -c '…'`).

- [ ] **Step 5: Commit**

```bash
cd ~/.local/share/chezmoi
git add dot_config/sketchybar/items/cpu.lua dot_config/sketchybar/init.lua
git commit -m "sketchybar: port cpu to Lua"
```

---

## Task 6: battery item

**Files:**
- Create: `dot_config/sketchybar/items/battery.lua`
- Modify: `dot_config/sketchybar/init.lua`

- [ ] **Step 1: Write `items/battery.lua`**

From `items/battery.sh` (`update_freq=120`, subscribes `system_woke power_source_change`) + `plugins/battery.sh` (pmset parse, icon thresholds, charging override). Thresholds kept identical to the shell version:

```lua
local battery = sbar.add("item", "battery", {
  position = "right",
  update_freq = 120,
})

local function update()
  sbar.exec("pmset -g batt", function(out)
    out = out or ""
    local pct = tonumber(out:match("(%d+)%%"))
    if not pct then return end
    local charging = out:find("AC Power") ~= nil

    local icon
    if charging then        icon = "􀢋"
    elseif pct >= 90 then    icon = "􀛨"
    elseif pct >= 60 then    icon = "􀺸"
    elseif pct >= 30 then    icon = "􀺶"
    elseif pct >= 10 then    icon = "􀛩"
    else                     icon = "􀛪" end

    battery:set({ icon = { string = icon }, label = { string = pct .. "%" } })
  end)
end

battery:subscribe({ "routine", "forced", "system_woke", "power_source_change" }, update)
```

- [ ] **Step 2: Wire into `init.lua`** — insert before the cpu require:

```lua
require("items.battery")
```

- [ ] **Step 3: Syntax check**

```bash
cd ~/.local/share/chezmoi/dot_config/sketchybar && luac -p items/battery.lua && echo OK
```
Expected: `OK`.

- [ ] **Step 4: Apply + reload + verify**

```bash
cd ~/.local/share/chezmoi && chezmoi apply && sketchybar --reload
```
Expected: battery icon + percentage. Unplug/replug power → charging icon (􀢋) toggles.

- [ ] **Step 5: Commit**

```bash
cd ~/.local/share/chezmoi
git add dot_config/sketchybar/items/battery.lua dot_config/sketchybar/init.lua
git commit -m "sketchybar: port battery to Lua"
```

---

## Task 7: volume item

**Files:**
- Create: `dot_config/sketchybar/items/volume.lua`
- Modify: `dot_config/sketchybar/init.lua`

- [ ] **Step 1: Write `items/volume.lua`**

From `items/volume.sh` (subscribe `volume_change`) + `plugins/volume.sh` (`env.INFO` = level, icon by range). Ranges kept identical:

```lua
local volume = sbar.add("item", "volume", { position = "right" })

volume:subscribe("volume_change", function(env)
  local v = tonumber(env.INFO) or 0
  local icon
  if v >= 60 then     icon = "􀊩"
  elseif v >= 30 then icon = "􀊥"
  elseif v >= 1 then  icon = "􀊡"
  else                icon = "􀊣" end
  volume:set({ icon = { string = icon }, label = { string = v .. "%" } })
end)
```

- [ ] **Step 2: Wire into `init.lua`** — insert before the battery require:

```lua
require("items.volume")
```

- [ ] **Step 3: Syntax check**

```bash
cd ~/.local/share/chezmoi/dot_config/sketchybar && luac -p items/volume.lua && echo OK
```
Expected: `OK`.

- [ ] **Step 4: Apply + reload + verify**

```bash
cd ~/.local/share/chezmoi && chezmoi apply && sketchybar --reload
```
Expected: change system volume → speaker icon + `NN%` update. (Item shows only after the first `volume_change`, matching original.)

- [ ] **Step 5: Commit**

```bash
cd ~/.local/share/chezmoi
git add dot_config/sketchybar/items/volume.lua dot_config/sketchybar/init.lua
git commit -m "sketchybar: port volume to Lua"
```

---

## Task 8: keyboard (input source) item

**Files:**
- Create: `dot_config/sketchybar/items/keyboard.lua`
- Modify: `dot_config/sketchybar/init.lua`

- [ ] **Step 1: Write `items/keyboard.lua`**

From `items/keyboard.sh` (icon off, custom event `keyboard_change` = `AppleSelectedInputSourcesChangedNotification`) + `plugins/keyboard.sh` (read layout via `defaults`, map Croatian→HR, "U.S."→US, else 한). The shell layout-extraction is preserved verbatim via `sbar.exec`:

```lua
local settings = require("settings")

local keyboard = sbar.add("item", "keyboard", {
  position = "right",
  icon = { drawing = false },
  label = { font = settings.font },
})

sbar.add("event", "keyboard_change", "AppleSelectedInputSourcesChangedNotification")

local LAYOUT_CMD = [[defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources | grep "KeyboardLayout Name" | cut -c 33- | rev | cut -c 2- | rev]]

local function update()
  sbar.exec(LAYOUT_CMD, function(out)
    local layout = (out or ""):gsub("%s+$", "")
    local short = "한"
    if layout == "Croatian" then short = "HR"
    elseif layout == '"U.S."' then short = "US" end
    keyboard:set({ label = { string = short } })
  end)
end

keyboard:subscribe({ "keyboard_change", "forced" }, update)
```

- [ ] **Step 2: Wire into `init.lua`** — insert before the volume require:

```lua
require("items.keyboard")
```

- [ ] **Step 3: Syntax check**

```bash
cd ~/.local/share/chezmoi/dot_config/sketchybar && luac -p items/keyboard.lua && echo OK
```
Expected: `OK`.

- [ ] **Step 4: Apply + reload + verify**

```bash
cd ~/.local/share/chezmoi && chezmoi apply && sketchybar --reload
```
Expected: right-side `HR`/`US`/`한` label. Switch input source (e.g. ⌃Space) → label updates. If the initial label is empty, confirm the `defaults`/`cut` extraction still matches your macOS version's plist format.

- [ ] **Step 5: Commit**

```bash
cd ~/.local/share/chezmoi
git add dot_config/sketchybar/items/keyboard.lua dot_config/sketchybar/init.lua
git commit -m "sketchybar: port keyboard layout to Lua"
```

---

## Task 9: slack item

**Files:**
- Create: `dot_config/sketchybar/items/slack.lua`
- Modify: `dot_config/sketchybar/init.lua`

- [ ] **Step 1: Write `items/slack.lua`**

From `items/slack.sh` (icon 󰒱, size 18, `update_freq=10`, click opens Slack, subscribe `system_woke`) + `plugins/slack.sh` (hide if Slack not running; else color icon + label by `lsappinfo` badge):

```lua
local slack = sbar.add("item", "slack", {
  position = "right",
  update_freq = 10,
  click_script = "open -a 'Slack'",
  background = { padding_left = 15 },
  icon = { string = "󰒱", font = { size = 18.0 } },
})

local function update()
  sbar.exec("pgrep -x Slack >/dev/null 2>&1 && echo yes || echo no", function(running)
    if (running or ""):find("no") then
      slack:set({ drawing = false })
      return
    end
    slack:set({ drawing = true })
    sbar.exec("lsappinfo info -only StatusLabel Slack 2>/dev/null", function(out)
      local label = (out or ""):match('"label"="([^"]*)"')
      local color = 0xffa6da95            -- no badge → green
      if label == nil or label == "" then
        label = ""
      elseif label == "•" then
        color = 0xffeed49f                -- dot → yellow
      elseif label:match("^%d+$") then
        color = 0xffed8796                -- count → red
      else
        label = ""                        -- unknown badge → keep green, no label
      end
      slack:set({ icon = { string = "󰒱", color = color }, label = { string = label } })
    end)
  end)
end

slack:subscribe({ "routine", "forced", "system_woke" }, update)
```

- [ ] **Step 2: Wire into `init.lua`** — append after the cpu require (slack is last on the right):

```lua
require("items.slack")
```

- [ ] **Step 3: Syntax check**

```bash
cd ~/.local/share/chezmoi/dot_config/sketchybar && luac -p items/slack.lua && echo OK
```
Expected: `OK`.

- [ ] **Step 4: Apply + reload + verify**

```bash
cd ~/.local/share/chezmoi && chezmoi apply && sketchybar --reload
```
Expected: with Slack running, the 󰒱 icon shows (green/yellow/red by unread badge); quit Slack → item hides. Click → Slack opens.

- [ ] **Step 5: Commit**

```bash
cd ~/.local/share/chezmoi
git add dot_config/sketchybar/items/slack.lua dot_config/sketchybar/init.lua
git commit -m "sketchybar: port slack to Lua"
```

---

## Task 10: aerospace workspaces (the complex one)

**Files:**
- Create: `dot_config/sketchybar/items/aerospace.lua`
- Modify: `dot_config/sketchybar/init.lua`

Merges `items/aerospace.sh` + `plugins/aerospace.sh` + `plugins/aerospace_windows.sh` into one file. Cleanup wins: uses `env.FOCUSED_WORKSPACE` from the trigger (drops the extra `list-workspaces --focused`), shares a `focused_workspace` Lua upvalue, and maps app icons via `icon_map.lua`. `aerospace.toml` is unchanged (already triggers `aerospace_workspace_change` / `aerospace_windows_change`).

- [ ] **Step 1: Write `items/aerospace.lua`**

```lua
local colors = require("colors")
local settings = require("settings")
local icon_map = require("helpers.icon_map")

sbar.add("event", "aerospace_workspace_change")
sbar.add("event", "aerospace_windows_change")

-- Workspace list at startup. io.popen is fine here (startup); never inside a callback.
local handle = io.popen("aerospace list-workspaces --all 2>/dev/null")
local workspaces = {}
if handle then
  for sid in handle:lines() do
    sid = sid:gsub("%s+$", "")
    if sid ~= "" then workspaces[#workspaces + 1] = sid end
  end
  handle:close()
end

local focused_workspace = nil  -- shared across all space items; set on each workspace_change

for _, sid in ipairs(workspaces) do
  local space = sbar.add("item", "space." .. sid, {
    position = "left",
    icon = { string = sid },
    label = {
      font = settings.app_font,
      padding_right = 20,
      y_offset = -1,
    },
    click_script = "aerospace workspace " .. sid,
  })

  -- Highlight the focused workspace (same colors as the old plugin).
  space:subscribe("aerospace_workspace_change", function(env)
    focused_workspace = env.FOCUSED_WORKSPACE
    if sid == focused_workspace then
      space:set({
        background = { drawing = true, color = colors.accent },
        icon = { color = colors.bar },
        label = { color = colors.bar },
      })
    else
      space:set({
        background = { drawing = false },
        icon = { color = colors.accent },
        label = { color = colors.accent },
      })
    end
  end)

  -- App-icon strip; hide empty + unfocused workspaces.
  space:subscribe("aerospace_windows_change", function()
    sbar.exec("aerospace list-windows --workspace " .. sid .. " --format '%{app-name}' 2>/dev/null | sort -u",
      function(out)
        local strip, has_apps = "", false
        for app in (out or ""):gmatch("[^\n]+") do
          app = app:gsub("%s+$", "")
          if app ~= "" then
            has_apps = true
            strip = strip .. " " .. (icon_map[app] or ":default:")
          end
        end
        if not has_apps and sid ~= focused_workspace then
          space:set({ drawing = false })
        else
          space:set({ drawing = true, label = { string = strip } })
        end
      end)
  end)
end

-- Initial render: replay the same triggers aerospace.toml fires, so highlight +
-- icons populate without waiting for the first workspace switch.
sbar.exec("aerospace list-workspaces --focused 2>/dev/null", function(out)
  local f = (out or ""):gsub("%s+$", "")
  sbar.exec("sketchybar --trigger aerospace_workspace_change FOCUSED_WORKSPACE=" .. f)
  sbar.exec("sketchybar --trigger aerospace_windows_change")
end)
```

- [ ] **Step 2: Wire into `init.lua`** — aerospace is the FIRST left item, so its require must come before `require("items.front_app")`:

```lua
require("items.aerospace")
require("items.front_app")
```

- [ ] **Step 3: Verify final `init.lua` order**

`init.lua` must read (after `require("bar")`/`require("default")`), top to bottom:

```lua
require("items.aerospace")
require("items.front_app")
require("items.calendar")
require("items.keyboard")
require("items.volume")
require("items.battery")
require("items.cpu")
require("items.slack")
```
Fix the order if earlier tasks appended out of sequence.

- [ ] **Step 4: Syntax check**

```bash
cd ~/.local/share/chezmoi/dot_config/sketchybar && luac -p items/aerospace.lua && luac -p init.lua && echo OK
```
Expected: `OK`.

- [ ] **Step 5: Apply + reload + verify**

```bash
cd ~/.local/share/chezmoi && chezmoi apply && sketchybar --reload
```
Expected: one item per AeroSpace workspace on the left; the focused one is highlighted (cyan bg, dark text); each shows app-logo icons for its windows; empty unfocused workspaces hide. Switch workspaces (and move windows) → highlight + icon strips follow. Click a workspace item → focuses it.

- [ ] **Step 6: Commit**

```bash
cd ~/.local/share/chezmoi
git add dot_config/sketchybar/items/aerospace.lua dot_config/sketchybar/init.lua
git commit -m "sketchybar: port aerospace workspaces to Lua"
```

---

## Task 11: Full visual verification (user gate)

No code. Confirm the whole bar matches the old shell bar before deleting anything.

- [ ] **Step 1: Fresh reload**

```bash
cd ~/.local/share/chezmoi && chezmoi apply && sketchybar --reload
```

- [ ] **Step 2: Walk the checklist** — each must look/behave as before:
  - [ ] Bar: top, height 40, Tokyo-Night dark background.
  - [ ] AeroSpace: per-workspace items, correct highlight on the focused one, app icons per workspace, empty+unfocused hidden, click focuses.
  - [ ] front_app: accent background, focused app logo + name, updates on switch.
  - [ ] calendar: `Wkd DD Mon HH:MM AM/PM`, ticking.
  - [ ] keyboard: HR/US/한 label, updates on input-source switch.
  - [ ] volume: icon + `NN%` on volume change.
  - [ ] battery: icon + `NN%`, charging icon on AC.
  - [ ] cpu: `NN%`, refreshing.
  - [ ] slack: shows when running, badge color correct, hidden when quit, click opens.

- [ ] **Step 3: If anything is wrong**, fix the relevant `items/<name>.lua`, re-apply, re-verify. Rollback escape hatch if needed: `git checkout main && chezmoi apply && sketchybar --reload` restores the shell bar (still intact on `main`).

- [ ] **Step 4: STOP and get explicit user sign-off** that the Lua bar is correct before Task 12 deletes the shell files.

---

## Task 12: Delete dead shell files, merge, push

Only after Task 11 sign-off. These files are no longer referenced by the Lua config.

**Files to delete (chezmoi source, under `dot_config/sketchybar/`):**
- `executable_colors.sh`
- `helpers/executable_icon_map.sh`
- `plugins/executable_icon_map_fn.sh`
- `plugins/executable_aerospace.sh`, `plugins/executable_aerospace_windows.sh`
- `plugins/executable_space.sh`, `plugins/executable_space_windows.sh` (dead since before this migration — never sourced)
- `plugins/executable_front_app.sh`, `plugins/executable_calendar.sh`, `plugins/executable_keyboard.sh`, `plugins/executable_volume.sh`, `plugins/executable_battery.sh`, `plugins/executable_cpu.sh`, `plugins/executable_slack.sh`
- `items/executable_aerospace.sh`, `items/executable_front_app.sh`, `items/executable_calendar.sh`, `items/executable_keyboard.sh`, `items/executable_volume.sh`, `items/executable_battery.sh`, `items/executable_cpu.sh`, `items/executable_slack.sh`

**Keep:** `helpers/icon_map.lua` and all new `*.lua`.

- [ ] **Step 1: Remove the shell sources**

```bash
cd ~/.local/share/chezmoi/dot_config/sketchybar
git rm executable_colors.sh \
       helpers/executable_icon_map.sh \
       plugins/executable_*.sh \
       items/executable_*.sh
```

- [ ] **Step 2: Confirm only Lua + icon_map.lua remain in source**

```bash
cd ~/.local/share/chezmoi/dot_config/sketchybar
find . -type f | sort
```
Expected: `executable_sketchybarrc`, `init.lua`, `bar.lua`, `default.lua`, `colors.lua`, `settings.lua`, `items/*.lua` (8), `helpers/icon_map.lua`. No `.sh` files.

- [ ] **Step 3: Apply — chezmoi removes the deployed shell files**

```bash
cd ~/.local/share/chezmoi && chezmoi apply
ls ~/.config/sketchybar ~/.config/sketchybar/items ~/.config/sketchybar/plugins 2>&1
sketchybar --reload
```
Expected: live dir now holds only the Lua files + `helpers/icon_map.lua`; `plugins/` is empty or gone; the bar still works fully. (If chezmoi left a stale `.sh` in the live dir, run `chezmoi apply` again or `chezmoi managed | grep sketchybar` to confirm none are tracked.)

- [ ] **Step 4: Commit the deletions**

```bash
cd ~/.local/share/chezmoi
git commit -m "sketchybar: drop shell config now that Lua port is live"
```

- [ ] **Step 5: Merge to main and push**

```bash
cd ~/.local/share/chezmoi
git checkout main
git merge --no-ff sketchybar-lua -m "Migrate SketchyBar config to Lua (SbarLua)"
git push
git branch -d sketchybar-lua
```
Expected: `main` updated and pushed; branch deleted.

- [ ] **Step 6: Final sanity on main**

```bash
cd ~/.local/share/chezmoi && chezmoi apply && sketchybar --reload
```
Expected: bar still fully functional from `main`.

---

## Self-review notes

- **Spec coverage:** launcher/event-loop (T2) ✓, file layout (T2–T10) ✓, all 8 items mapped (T3–T10) ✓, aerospace `env.FOCUSED_WORKSPACE` + merged file + icon_map (T10) ✓, build bootstrap + Brewfile + `SBARLUA_REF` pin (T1) ✓, icon_map consolidation / dead `.sh` removal (T12) ✓, branch + atomic-swap + rollback (T2, T11, T12) ✓, error handling via `sbar.exec`-only + nil-guards (all callbacks) ✓, `aerospace.toml` untouched ✓.
- **Dead code found:** `plugins/space.sh` + `plugins/space_windows.sh` are SketchyBar-default leftovers (native Mission Control spaces, never sourced by the active `sketchybarrc`) — not ported, deleted in T12.
- **Type/name consistency:** module names (`colors`, `settings`, `helpers.icon_map`), item handles, and `init.lua` require order are consistent across tasks.
- **Runtime assumptions** (lua ABI, `sbar.exec` shell, `routine`/`forced`, `{string=…}`) are listed up top and checked at the relevant verify steps rather than assumed silent-correct.
