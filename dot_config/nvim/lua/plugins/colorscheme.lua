-- Colorscheme follows the desktop palette (Noctalia App Theming).
--
-- Noctalia renders lua/noctalia_colors.lua (generated, untracked) from the
-- active scheme and sends SIGUSR1 to running nvim instances; aether.nvim
-- builds a full colorscheme from that palette. Where the file is missing
-- (macOS, fresh install) we fall back to Rosé Pine.
local function noctalia_colors()
  package.loaded["noctalia_colors"] = nil
  local ok, colors = pcall(require, "noctalia_colors")
  if ok and type(colors) == "table" then
    return colors
  end
  return nil
end

return {
  { "rose-pine/neovim", name = "rose-pine" },

  {
    "omacom-io/aether.nvim",
    branch = "v3",
    name = "aether",
    priority = 1000,
    opts = function()
      return { colors = noctalia_colors() or {} }
    end,
    config = function(_, opts)
      local aether = require("aether")
      aether.setup(opts)

      -- Live reload: Noctalia's post_hook runs `pkill -SIGUSR1 -x nvim`.
      if _G.__noctalia_signal then
        _G.__noctalia_signal:stop()
        _G.__noctalia_signal:close()
      end
      local signal = vim.uv.new_signal()
      _G.__noctalia_signal = signal
      signal:start(
        "sigusr1",
        vim.schedule_wrap(function()
          local colors = noctalia_colors()
          if colors then
            aether.setup({ colors = colors })
            vim.cmd.colorscheme("aether")
          end
        end)
      )
    end,
  },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = function()
        vim.cmd.colorscheme(noctalia_colors() and "aether" or "rose-pine")
      end,
    },
  },
}
