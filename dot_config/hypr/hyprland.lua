-- Hyprland Lua config — managed by chezmoi (Linux only).
-- Desktop shell: Noctalia v5 (native Wayland, no Qt). Session launched via uwsm.
-- Reference: https://wiki.hypr.land/Configuring/
-- API stubs for LSP: /usr/share/hypr/stubs/hl.meta.lua

-- ---------------------------------------------------------------------------
-- Monitors  (https://wiki.hypr.land/Configuring/Basics/Monitors/)
-- ---------------------------------------------------------------------------
-- Auto-detect fallback; per-machine layout in monitors.lua (tracked).
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})
require("monitors")

-- ---------------------------------------------------------------------------
-- Programs
-- ---------------------------------------------------------------------------
local terminal    = "ghostty"
local fileManager = "thunar"
-- Noctalia surfaces, driven through its IPC CLI (noctalia v5+).
-- Reference: https://docs.noctalia.dev/noctalia/ipc/   (noctalia msg --help)
local noctalia = "noctalia msg "
local menu = noctalia .. "panel-toggle launcher"

-- ---------------------------------------------------------------------------
-- Autostart  (uwsm scopes graphical apps under the systemd session)
-- ---------------------------------------------------------------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("uwsm app -- noctalia")             -- the Noctalia shell itself
    -- polkit agent runs as a systemd user service (hyprpolkitagent.service,
    -- enabled via graphical-session.target) — don't exec it here too
    hl.exec_cmd("uwsm app -- hypridle")             -- idle -> lock/dpms/suspend
    -- Clipboard history feeding cliphist (queried via Noctalia's clipboard panel)
    hl.exec_cmd("wl-paste --type text  --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
end)

-- ---------------------------------------------------------------------------
-- Environment
-- ---------------------------------------------------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- ---------------------------------------------------------------------------
-- Look & feel
-- ---------------------------------------------------------------------------
hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 10,
        border_size = 2,
        -- Border colors are owned by Noctalia's template engine — see the
        -- require("noctalia") at the bottom of this file.
        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },
    decoration = {
        rounding         = 10,
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        blur = {
            enabled           = true,
            size              = 6,
            passes            = 2,
            new_optimizations = true,
        },
        shadow = {
            enabled      = true,
            range        = 4,
            render_power = 3,
            color        = "rgba(120f18ee)",
        },
    },
    animations = {
        enabled = true,
    },
    dwindle = {
        preserve_split = true, -- pseudotiling is the `pseudo` dispatcher (Super+P)
    },
    misc = {
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },
})

hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })

hl.animation({ leaf = "windows",    enabled = true, speed = 4, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 4, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "fade",       enabled = true, speed = 4, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "easeOutQuint", style = "slide" })
hl.animation({ leaf = "border",     enabled = true, speed = 6, bezier = "default" })

-- ---------------------------------------------------------------------------
-- Input
-- ---------------------------------------------------------------------------
hl.config({
    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll       = true,
            disable_while_typing = true,
        },
    },
})

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

-- ---------------------------------------------------------------------------
-- Keybindings  (mainMod = SUPER)
-- ---------------------------------------------------------------------------
local mainMod = "SUPER"

-- Core
hl.bind(mainMod .. " + Return", hl.dsp.exec_cmd("uwsm app -- " .. terminal))
hl.bind(mainMod .. " + Q", hl.dsp.window.close())
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd("uwsm app -- " .. fileManager))
hl.bind(mainMod .. " + Space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + P", hl.dsp.window.pseudo())
hl.bind(mainMod .. " + J", hl.dsp.layout("togglesplit")) -- dwindle only

-- macOS-like copy/paste: ALT+C / ALT+V -> Ctrl+Insert / Shift+Insert.
-- Uses send_key_state, NOT send_shortcut: sendshortcut was broken in 0.55
-- (the keybind fires but the synthetic shortcut never reaches the window).
-- Press sends key-down, release ({release=true}) sends key-up so no modifier gets stuck.
hl.bind("ALT + C", hl.dsp.send_key_state({ mods = "CTRL", key = "INSERT", state = "down", window = "activewindow" }))
hl.bind("ALT + C", hl.dsp.send_key_state({ mods = "CTRL", key = "INSERT", state = "up", window = "activewindow" }), { release = true })
hl.bind("ALT + V", hl.dsp.send_key_state({ mods = "SHIFT", key = "INSERT", state = "down", window = "activewindow" }))
hl.bind("ALT + V", hl.dsp.send_key_state({ mods = "SHIFT", key = "INSERT", state = "up", window = "activewindow" }), { release = true })

-- Noctalia surfaces
hl.bind(mainMod .. " + B", hl.dsp.exec_cmd(noctalia .. "panel-toggle control-center"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd(noctalia .. "panel-toggle clipboard"))
hl.bind(mainMod .. " + Escape", hl.dsp.exec_cmd(noctalia .. "panel-toggle session"))
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd(noctalia .. "session lock"))
hl.bind(mainMod .. " + SHIFT + W", hl.dsp.exec_cmd(noctalia .. "wallpaper-random"))

-- Screenshots (hyprshot) — save to disk + clipboard
-- Print variants kept for external keyboards; this laptop has no Print key, use the Super ones.
local shotDir = os.getenv("HOME") .. "/Pictures/Screenshots"
hl.bind("Print", hl.dsp.exec_cmd("hyprshot -m region -o " .. shotDir))
hl.bind("SHIFT + Print", hl.dsp.exec_cmd("hyprshot -m window -o " .. shotDir))
hl.bind("CTRL + Print", hl.dsp.exec_cmd("hyprshot -m output -o " .. shotDir))
hl.bind(mainMod .. " + S", hl.dsp.exec_cmd("hyprshot -m region -o " .. shotDir))
hl.bind(mainMod .. " + ALT + S", hl.dsp.exec_cmd("hyprshot -m window -o " .. shotDir))
hl.bind(mainMod .. " + CTRL + S", hl.dsp.exec_cmd("hyprshot -m output -o " .. shotDir))

-- Screenshots to clipboard only (for pasting into Claude/chat; no file left behind)
-- -z freezes the screen (via hyprpicker) so hover states and open menus can be captured
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region -z -s --clipboard-only"))
hl.bind(mainMod .. " + SHIFT + Print", hl.dsp.exec_cmd("hyprshot -m window -z -s --clipboard-only"))
hl.bind(mainMod .. " + SHIFT + ALT + S", hl.dsp.exec_cmd("hyprshot -m window -z -s --clipboard-only"))

-- Focus movement (arrow keys; SUPER+L is reserved for lock above)
hl.bind(mainMod .. " + left",  hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + up",    hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + down",  hl.dsp.focus({ direction = "down" }))

-- Workspaces: SUPER + [0-9] to switch, SUPER + SHIFT + [0-9] to move window
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Mouse: drag to move/resize floating windows
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media & brightness keys — routed through Noctalia IPC so its OSD shows.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd(noctalia .. "volume-up"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd(noctalia .. "volume-down"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd(noctalia .. "volume-mute"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd(noctalia .. "brightness-up"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd(noctalia .. "brightness-down"), { locked = true, repeating = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd(noctalia .. "media toggle"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd(noctalia .. "media next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd(noctalia .. "media previous"), { locked = true })

-- ---------------------------------------------------------------------------
-- Window rules
-- ---------------------------------------------------------------------------
-- Ignore maximize requests from all apps (restored: the hyprlang-era
-- `suppressevent` field is `suppress_event` in the Lua API).
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },

    suppress_event = "maximize",
})

hl.window_rule({
    name  = "thunar-file-ops-float",
    match = { class = "thunar", title = "File Operation Progress" },

    float = true,
})

-- ---------------------------------------------------------------------------
-- Theming — Noctalia's built-in `hyprland` template renders ~/.config/hypr/noctalia.lua
-- (border/group colors for the active palette) and keeps it in sync on every
-- palette change. We track only this require; the generated file is intentionally
-- NOT tracked by chezmoi. pcall so a missing palette (fresh install) can't kill
-- the config. Noctalia's own apply hook would append a bare require("noctalia")
-- line if this were missing — keep this block so it doesn't.
-- ---------------------------------------------------------------------------
local ok, noctalia_theme = pcall(require, "noctalia")
if ok and type(noctalia_theme) == "table" and noctalia_theme.apply_theme then
    noctalia_theme.apply_theme()
end
