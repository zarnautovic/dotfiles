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
