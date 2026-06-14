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
