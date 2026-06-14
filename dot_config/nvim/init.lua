if vim.g.vscode then
  require("config/vscode_keymaps")
else
  -- bootstrap lazy.nvim, LazyVim and your plugins
  require("config.lazy")
end
