#!/usr/bin/env bash
source "$CONFIG_DIR/colors.sh"

sid="$1"
ITEM="${NAME:-space.$sid}"

FOCUSED_WORKSPACE="$(aerospace list-workspaces --focused 2>/dev/null | head -n 1)"

# If Aerospace is transient and returns nothing, skip highlight changes
# (prevents "flash then off")
if [ -n "$FOCUSED_WORKSPACE" ]; then
  if [ "$sid" = "$FOCUSED_WORKSPACE" ]; then
    sketchybar --set "$ITEM" background.drawing=on \
      label.color="$BAR_COLOR" \
      background.color="$ACCENT_COLOR" \
      icon.color="$BAR_COLOR"
  else
    sketchybar --set "$ITEM" background.drawing=off \
      label.color="$ACCENT_COLOR" \
      icon.color="$ACCENT_COLOR"
  fi
fi

# Update app icons AFTER highlight
"$CONFIG_DIR/plugins/aerospace_windows.sh" "$sid"
