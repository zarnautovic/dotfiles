#!/bin/bash

ICON="󰒱"

# If Slack isn't running, hide the item completely
if ! pgrep -x "Slack" >/dev/null 2>&1; then
  sketchybar --set "$NAME" drawing=off
  exit 0
fi

# Slack is running, ensure item is visible
sketchybar --set "$NAME" drawing=on

STATUS_LABEL=$(lsappinfo info -only StatusLabel "Slack" 2>/dev/null)

LABEL=""
ICON_COLOR="0xffa6da95" # default "no badge" green-ish

if [[ $STATUS_LABEL =~ \"label\"=\"([^\"]*)\" ]]; then
  LABEL="${BASH_REMATCH[1]}"

  if [[ "$LABEL" == "" ]]; then
    ICON_COLOR="0xffa6da95"
  elif [[ "$LABEL" == "•" ]]; then
    ICON_COLOR="0xffeed49f"
  elif [[ "$LABEL" =~ ^[0-9]+$ ]]; then
    ICON_COLOR="0xffed8796"
  else
    # unknown badge -> keep visible but don't update label
    LABEL=""
  fi
fi

sketchybar --set "$NAME" \
  icon="$ICON" \
  label="$LABEL" \
  icon.color="$ICON_COLOR"
