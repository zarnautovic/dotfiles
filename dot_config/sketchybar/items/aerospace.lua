local colors = require("colors")
local settings = require("settings")
local icon_map = require("helpers.icon_map")

sbar.add("event", "aerospace_workspace_change")
sbar.add("event", "aerospace_windows_change")

-- Workspace list at startup. io.popen is fine here (startup); never inside a callback.
local handle = io.popen("aerospace list-workspaces --all 2>/dev/null")
local workspaces = {}
if handle then
  for line in handle:lines() do
    local sid = line:gsub("%s+$", "")
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
        for line in (out or ""):gmatch("[^\n]+") do
          local app = line:gsub("%s+$", "")
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
