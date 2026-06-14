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
