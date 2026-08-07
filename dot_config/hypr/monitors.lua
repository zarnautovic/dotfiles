-- Per-machine monitor layout (tracked). Inspect outputs with: hyprctl monitors all
--
-- Host: zlaya-arch
--   DP-1  Samsung Odyssey G81SF  4K (3840x2160)  — MAIN, right
--   DP-2  Dell U2722DE           2K (2560x1440)  — vertical, LEFT
--
-- transform: 1 = 90° CW, 3 = 90° CCW (270°). Flip 1<->3 if the Dell is upside down.

-- Left monitor: Dell, rotated to portrait. At scale 1.0 its rotated logical
-- width is 1440px, so the main monitor starts at x=1440.
hl.monitor({
    output    = "DP-2",
    mode      = "2560x1440@60",
    position  = "0x0",
    scale     = 1.0,
    transform = 1,
})

-- Main monitor: Samsung 4K. `highrr` picks the panel's highest refresh rate.
-- Scale 1.5 is the sweet spot for a 32" 4K — change to 1.0 (sharper/smaller UI)
-- or 2.0 (larger UI) to taste. y=560 vertically centers it against the tall Dell.
hl.monitor({
    output   = "DP-1",
    mode     = "highrr",
    position = "1440x560",
    scale    = 1.5,
})

-- ---------------------------------------------------------------------------
-- Workspace -> monitor binding
--   Main (DP-1, Samsung 4K):   workspaces 1, 2, 4, 5, 6, 7, 8, 9, 10
--   Vertical (DP-2, Dell):     workspace 3 only
-- `default = true` marks the workspace shown when that monitor first connects.
-- ---------------------------------------------------------------------------
for _, ws in ipairs({ 1, 2, 4, 5, 6, 7, 8, 9, 10 }) do
    hl.workspace_rule({ workspace = ws, monitor = "DP-1", default = (ws == 1) })
end
hl.workspace_rule({ workspace = 3, monitor = "DP-2", default = true })
