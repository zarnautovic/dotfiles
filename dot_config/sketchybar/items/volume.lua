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
