#!/bin/bash

sketchybar --add event aerospace_workspace_change
sketchybar --add event aerospace_windows_change

for sid in $(aerospace list-workspaces --all); do
  sketchybar --add item space.$sid left \
    --subscribe space.$sid aerospace_workspace_change aerospace_windows_change \
    --set space.$sid \
    icon=$sid \
    label.font="sketchybar-app-font:Regular:16.0" \
    label.padding_right=20 \
    label.y_offset=-1 \
    click_script="aerospace workspace $sid" \
    script="$CONFIG_DIR/plugins/aerospace.sh $sid"
done
