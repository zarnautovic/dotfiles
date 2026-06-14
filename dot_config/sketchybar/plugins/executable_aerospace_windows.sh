#!/usr/bin/env bash

sid="$1"

FOCUSED_WORKSPACE="$(aerospace list-workspaces --focused 2>/dev/null | head -n 1)"

# list apps in workspace
apps="$(
  aerospace list-windows --workspace "$sid" --format "%{app-name}" 2>/dev/null |
    sort -u
)"

# If workspace empty AND not focused → hide it
if [ -z "$apps" ] && [ "$sid" != "$FOCUSED_WORKSPACE" ]; then
  sketchybar --set "space.$sid" drawing=off
  exit 0
fi

# Otherwise show workspace
sketchybar --set "space.$sid" drawing=on

# Build icons
icon_strip=""
if [ -n "$apps" ]; then
  while IFS= read -r app; do
    [ -z "$app" ] && continue
    icon_strip+=" $("$CONFIG_DIR/plugins/icon_map_fn.sh" "$app")"
  done <<<"$apps"
fi

sketchybar --set "space.$sid" label="$icon_strip"
