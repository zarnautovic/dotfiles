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
