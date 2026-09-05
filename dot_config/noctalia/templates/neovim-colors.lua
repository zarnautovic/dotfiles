-- Rendered by Noctalia (user template `neovim-colors`) — do not edit.
-- Palette for aether.nvim, consumed by ~/.config/nvim/lua/plugins/colorscheme.lua.
-- Terminal ANSI roles carry the syntax semantics (red = error, green = string…),
-- Material roles fill the UI surfaces.
return {
  bg         = "{{colors.terminal_background.default.hex}}",
  dark_bg    = "{{colors.surface_dim.default.hex}}",
  darker_bg  = "{{colors.surface_container_lowest.default.hex}}",
  lighter_bg = "{{colors.surface_container_high.default.hex}}",
  background = "{{colors.terminal_background.default.hex}}",

  fg         = "{{colors.terminal_foreground.default.hex}}",
  dark_fg    = "{{colors.on_surface_variant.default.hex}}",
  light_fg   = "{{colors.on_surface.default.hex}}",
  bright_fg  = "{{colors.terminal_bright_white.default.hex}}",
  muted      = "{{colors.outline.default.hex}}",
  foreground = "{{colors.terminal_foreground.default.hex}}",

  accent  = "{{colors.primary.default.hex}}",
  red     = "{{colors.terminal_normal_red.default.hex}}",
  yellow  = "{{colors.terminal_normal_yellow.default.hex}}",
  orange  = "{{colors.tertiary.default.hex}}",
  green   = "{{colors.terminal_normal_green.default.hex}}",
  cyan    = "{{colors.terminal_normal_cyan.default.hex}}",
  blue    = "{{colors.terminal_normal_blue.default.hex}}",
  purple  = "{{colors.terminal_normal_magenta.default.hex}}",
  brown   = "{{colors.outline_variant.default.hex}}",

  bright_red     = "{{colors.terminal_bright_red.default.hex}}",
  bright_yellow  = "{{colors.terminal_bright_yellow.default.hex}}",
  bright_green   = "{{colors.terminal_bright_green.default.hex}}",
  bright_cyan    = "{{colors.terminal_bright_cyan.default.hex}}",
  bright_blue    = "{{colors.terminal_bright_blue.default.hex}}",
  bright_purple  = "{{colors.terminal_bright_magenta.default.hex}}",

  cursor               = "{{colors.terminal_cursor.default.hex}}",
  selection            = "{{colors.terminal_selection_bg.default.hex}}",
  selection_background = "{{colors.terminal_selection_bg.default.hex}}",
  selection_foreground = "{{colors.terminal_selection_fg.default.hex}}",
}
