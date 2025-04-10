#!/bin/bash

# Define themes and corresponding icons as pairs (light and dark versions)
THEME_PAIRS=(
    "Magnetic-Green-Light-Dracula Magnetic-Green-Dark-Dracula"
    "Breeze Breeze-Dark"
    "Magnetic-Light-Dracula Magnetic-Dark-Dracula"
    "Magnetic-Orange-Light-Dracula Magnetic-Orange-Dark-Dracula"
    "Magnetic-Purple-Light-Dracula Magnetic-Purple-Dark-Dracula"
    "Magnetic-Teal-Light-Dracula Magnetic-Teal-Dark-Dracula"
    "WhiteSur-Light WhiteSur-Dark"
    "WhiteSur-Light-solid WhiteSur-Dark-solid"
)

ICON_PAIRS=(
    "Tela-light Tela-dark"
)

# Files for state management
STATE_FILE="$HOME/.theme_state"
THEME_JSON="$HOME/.theme.json"

# Check if jq is installed
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is not installed. Please install it 
ubuntu/debian :~ sudo apt install jq
archlinux/manjaro :~ sudo pacman -S jq"
    exit 1
fi

if [ ! -f "$STATE_FILE" ]; then
    echo "none" > "$STATE_FILE"
    echo "Initialized state file with: none"
fi

if [ ! -f "$THEME_JSON" ]; then
    echo '{"used_themes": []}' > "$THEME_JSON"
    echo "Initialized theme.json with empty used_themes array"
fi

read LAST_THEME < "$STATE_FILE"
echo "Last applied theme: $LAST_THEME"

USED_THEMES=$(jq -r '.used_themes[]' "$THEME_JSON" 2>/dev/null | tr '\n' ' ' | xargs) || USED_THEMES=""
echo "Used themes from theme.json: $USED_THEMES"

is_theme_used() {
    local theme="$1"
    for used in $USED_THEMES; do
        if [ "$used" == "$theme" ]; then
            return 0 
        fi
    done
    return 1  
}

is_light_theme() {
    local theme="$1"
    for pair in "${THEME_PAIRS[@]}"; do
        IFS=' ' read -r light dark <<< "$pair"
        if [ "$theme" == "$light" ]; then
            return 0 
        elif [ "$theme" == "$dark" ]; then
            return 1  
        fi
    done
    return 2 
}

TOTAL_THEMES=$(( ${#THEME_PAIRS[@]} * 2 )) 
USED_COUNT=$(jq '.used_themes | length' "$THEME_JSON" 2>/dev/null || echo 0)
echo "Total themes: $TOTAL_THEMES, Used count: $USED_COUNT"

if [ "$USED_COUNT" -ge "$TOTAL_THEMES" ]; then
    echo '{"used_themes": []}' > "$THEME_JSON"
    USED_THEMES=""
    USED_COUNT=0
    echo "All $TOTAL_THEMES themes have been used. Resetting theme.json."
fi

get_unused_light_theme() {
    local available=()
    for pair in "${THEME_PAIRS[@]}"; do
        IFS=' ' read -r light dark <<< "$pair"
        if ! is_theme_used "$light"; then
            available+=("$light")
        fi
    done
    if [ ${#available[@]} -eq 0 ]; then
        echo "No unused light themes available" >&2
        return 1
    fi
    RANDOM_INDEX=$((RANDOM % ${#available[@]}))
    echo "${available[$RANDOM_INDEX]}"
    return 0
}

if [ "$LAST_THEME" == "none" ] || ! is_light_theme "$LAST_THEME"; then
    echo "Selecting a random light theme..."
    THEME=$(get_unused_light_theme)
    if [ $? -ne 0 ]; then
        echo "Error: No unused light themes found. This shouldn’t happen after a reset."
        echo "Current used_themes: $USED_THEMES"
        exit 1
    fi
    CURRENT_TYPE="light"
    echo "Selected unused light theme: $THEME"
else

    echo "Switching to the dark counterpart of $LAST_THEME..."
    for pair in "${THEME_PAIRS[@]}"; do
        IFS=' ' read -r light dark <<< "$pair"
        if [ "$LAST_THEME" == "$light" ]; then
            THEME="$dark"
            CURRENT_TYPE="dark"
            echo "Selected dark theme: $THEME"
            break
        fi
    done
fi

IFS=' ' read -r LIGHT_ICON DARK_ICON <<< "${ICON_PAIRS[0]}"
if [ "$CURRENT_TYPE" == "light" ]; then
    ICON="$LIGHT_ICON"
else
    ICON="$DARK_ICON"
fi

echo "Selected icon: $ICON"

xfconf-query -c xsettings -p /Net/ThemeName -s "$THEME"
xfconf-query -c xfwm4 -p /general/theme -s "$THEME"
xfconf-query -c xsettings -p /Net/IconThemeName -s "$ICON"
echo "Switched to $CURRENT_TYPE theme: $THEME with icon $ICON"

jq --arg theme "$THEME" '.used_themes += [$theme]' "$THEME_JSON" > "$THEME_JSON.tmp"
if [ $? -eq 0 ]; then
    mv "$THEME_JSON.tmp" "$THEME_JSON"
    echo "theme.json updated with $THEME"
else
    echo "Error: Failed to update theme.json"
    rm -f "$THEME_JSON.tmp"
    exit 1
fi

echo "$THEME" > "$STATE_FILE"
echo "State saved: $THEME"
