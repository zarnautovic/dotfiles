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
