local cpu = sbar.add("item", "cpu", {
  position = "right",
  update_freq = 2,
  icon = { string = "􀧓" },
})

local CPU_CMD = [[
CORE_COUNT=$(sysctl -n machdep.cpu.thread_count)
CPU_INFO=$(ps -eo pcpu,user)
CPU_SYS=$(echo "$CPU_INFO" | grep -v $(whoami) | sed "s/[^ 0-9\.]//g" | awk "{sum+=\$1} END {print sum/(100.0 * $CORE_COUNT)}")
CPU_USER=$(echo "$CPU_INFO" | grep $(whoami) | sed "s/[^ 0-9\.]//g" | awk "{sum+=\$1} END {print sum/(100.0 * $CORE_COUNT)}")
echo "$CPU_SYS $CPU_USER" | awk '{printf "%.0f", ($1 + $2)*100}'
]]

local function update()
  sbar.exec(CPU_CMD, function(out)
    local pct = (out or ""):match("%d+")
    if pct then cpu:set({ label = { string = pct .. "%" } }) end
  end)
end

cpu:subscribe("routine", update)
cpu:subscribe("forced", update)
