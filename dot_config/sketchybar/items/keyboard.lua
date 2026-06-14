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
