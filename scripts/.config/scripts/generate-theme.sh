#!/usr/bin/env bash
# =============================================================================
# generate-theme.sh - Dynamic wallpaper-driven color scheme generator
# =============================================================================
# Generates colors automatically from wallpaper and propagates to:
#   - Waybar (CSS)
#   - Rofi (RASI)
#   - Hyprland (Lua snippet)
#   - Kitty (conf)
#   - Yazi (TOML)
#   - Tmux (conf snippet)
#   - Neovim (Lua snippet)
#
# Usage:
#   generate-theme.sh [wallpaper_path]
#   generate-theme.sh --save-as my-theme-name [wallpaper_path]
#   generate-theme.sh --no-reload [wallpaper_path]
# =============================================================================

set -euo pipefail

# === Configuration ===
THEME_DIR="$HOME/.config/themes/current"
AVAILABLE_DIR="$HOME/.config/themes/available"
OVERRIDE_FILE="$HOME/.config/themes/overrides/global.json"
TOKENS_FILE="$HOME/.config/themes/tokens.json"
CACHE_DIR="$HOME/.cache/wal"
WALLPAPER_CACHE="$HOME/.cache/ml4w/hyprland-dotfiles/current_wallpaper"
export PATH="$HOME/.local/bin:$PATH"
HYPRLAND_CONF="$HOME/.config/hypr/hyprpaper.conf"

THEME_NAME="auto"

# === Color Functions ===
info() { echo -e "\033[0;32m[INFO]\033[0m $1"; }
warn() { echo -e "\033[0;33m[WARN]\033[0m $1"; }
error() { echo -e "\033[0;31m[ERROR]\033[0m $1" >&2; }

notify() {
    notify-send -a "Theme Generator" -i "preferences-desktop-color" "$1" "$2" 2>/dev/null || true
}

# === Resolve Wallpaper Path ===
resolve_wallpaper() {
    local wallpaper="${1:-}"

    if [[ -n "$wallpaper" && -f "$wallpaper" ]]; then
        echo "$wallpaper"
        return
    fi

    if [[ -f "$WALLPAPER_CACHE" ]]; then
        local cached
        cached=$(cat "$WALLPAPER_CACHE" 2>/dev/null | tr -d '[:space:]')
        if [[ -f "$cached" ]]; then
            echo "$cached"
            return
        fi
    fi

    if [[ -f "$HYPRLAND_CONF" ]]; then
        local hyprpaper_wp
        hyprpaper_wp=$(grep -E '^wallpaper\s*=' "$HYPRLAND_CONF" | head -1 | sed 's/.*=\s*//' | xargs)
        if [[ -n "$hyprpaper_wp" && "$hyprpaper_wp" != "," && -f "$hyprpaper_wp" ]]; then
            echo "$hyprpaper_wp"
            return
        fi
    fi

    error "No wallpaper found. Provide path as argument or set wallpaper first."
    exit 1
}

# === Extract Colors from Wallpaper ===
run_extract() {
    local wallpaper="$1"
    info "Extracting colors from: $(basename "$wallpaper")"

    python3 "$HOME/.config/scripts/extract-colors.py" "$wallpaper" "$CACHE_DIR/colors.json" || {
        error "Color extraction failed"
        notify "Theme Generation Failed" "Could not extract colors from wallpaper"
        exit 1
    }

    if [[ ! -f "$CACHE_DIR/colors.json" ]]; then
        error "extract-colors.py did not produce colors.json"
        exit 1
    fi

    info "Colors extracted successfully"
}

# === Parse Colors from JSON ===
parse_colors() {
    local json_file="$CACHE_DIR/colors.json"

    BACKGROUND=$(python3 -c "import json; d=json.load(open('$json_file')); print(d['special']['background'])")
    FOREGROUND=$(python3 -c "import json; d=json.load(open('$json_file')); print(d['special']['foreground'])")
    CURSOR=$(python3 -c "import json; d=json.load(open('$json_file')); print(d['special']['cursor'])")

    for i in $(seq 0 15); do
        eval "COLOR${i}=$(python3 -c "import json; d=json.load(open('$json_file')); print(d['colors']['color${i}'])")"
    done

    read_semantic() {
        python3 -c "import json; d=json.load(open('$json_file')); print(d.get('semantic', {}).get('$1', d['special']['background']))"
    }

    BG="$BACKGROUND"
    FG="$FOREGROUND"
    RED="$COLOR1"
    GREEN="$COLOR2"
    YELLOW="$COLOR3"
    BLUE="$COLOR4"
    MAUVE="$COLOR5"
    TEAL="$COLOR6"
    PINK="$COLOR5"
    MAROON="$COLOR1"
    PEACH="$COLOR3"
    SAPPHIRE="$COLOR4"
    SKY="$COLOR6"
    LAVENDER="$COLOR6"

    CRUST=$(read_semantic crust)
    MANTLE=$(read_semantic mantle)
    BASE=$(read_semantic base)
    SURFACE0=$(read_semantic surface0)
    SURFACE1=$(read_semantic surface1)
    SURFACE2=$(read_semantic surface2)
    OVERLAY0=$(read_semantic overlay0)
    OVERLAY1=$(read_semantic overlay1)
    OVERLAY2=$(read_semantic overlay2)
    SUBTEXT0=$(read_semantic subtext0)
    SUBTEXT1=$(read_semantic subtext1)
    TEXT=$(read_semantic text)

    if [[ -f "$OVERRIDE_FILE" ]]; then
        info "Applying color overrides from: $(basename "$OVERRIDE_FILE")"
        apply_overrides
    fi
}

# === Load Design Tokens ===
load_tokens() {
    if [[ ! -f "$TOKENS_FILE" ]]; then
        warn "tokens.json not found, using defaults"
        FONT_SANS="JetBrainsMono Nerd Font"
        FONT_MONO="JetBrainsMono Nerd Font"
        FONT_SIZE="12px"
        FONT_SIZE_SMALL="12px"
        RADIUS_WINDOW=0
        RADIUS_BUTTON=0
        RADIUS_POPUP=0
        SPACING_TIGHT="4px"
        SPACING_NORMAL="8px"
        SPACING_WIDE="16px"
        OPACITY_BG="0.8"
        OPACITY_BG_SOLID="1.0"
        OPACITY_POPUP="0.95"
        OPACITY_DIM="0.3"
        BORDER_SIZE=2
        GAPS_INNER=5
        GAPS_OUTER=5
        return
    fi

    info "Loading design tokens"

    local t
    t=$(python3 -c "
import json
d = json.load(open('$TOKENS_FILE'))
def g(*keys, default=''):
    v = d
    for k in keys:
        if isinstance(v, dict): v = v.get(k, {})
        else: return default
    return v if v != {} else default

out = {}
out['FONT_SANS'] = g('fonts', 'sans', default='JetBrainsMono Nerd Font')
out['FONT_MONO'] = g('fonts', 'mono', default='JetBrainsMono Nerd Font')
out['FONT_SIZE'] = g('fonts', 'size', default='14px')
out['FONT_SIZE_SMALL'] = g('fonts', 'size_small', default='12px')
out['RADIUS_WINDOW'] = str(g('radii', 'window', default=0))
out['RADIUS_BUTTON'] = str(g('radii', 'button', default=0))
out['RADIUS_POPUP'] = str(g('radii', 'popup', default=0))
out['SPACING_TIGHT'] = g('spacing', 'tight', default='4px')
out['SPACING_NORMAL'] = g('spacing', 'normal', default='8px')
out['SPACING_WIDE'] = g('spacing', 'wide', default='16px')
out['OPACITY_BG'] = str(g('opacity', 'background', default=0.8))
out['OPACITY_BG_SOLID'] = str(g('opacity', 'background_solid', default=1.0))
out['OPACITY_POPUP'] = str(g('opacity', 'popup', default=0.95))
out['OPACITY_DIM'] = str(g('opacity', 'dim', default=0.3))
out['BORDER_SIZE'] = str(g('border', 'size', default=2))
out['GAPS_INNER'] = str(g('gaps', 'inner', default=5))
out['GAPS_OUTER'] = str(g('gaps', 'outer', default=5))

for k, v in out.items():
    print(f'{k}={v}')
")

    while IFS='=' read -r key value; do
        [[ -n "$key" ]] && eval "${key}=\"${value}\""
    done <<< "$t"
}

# === Apply Manual Color Overrides ===
apply_overrides() {
    local keys
    keys=$(python3 -c "import json; d=json.load(open('$OVERRIDE_FILE')); print(' '.join(d.keys()))" 2>/dev/null) || return

    for key in $keys; do
        local value
        value=$(python3 -c "import json; d=json.load(open('$OVERRIDE_FILE')); print(d['$key'])" 2>/dev/null) || continue

        if [[ "$value" != \#* ]]; then
            value="#$value"
        fi

        eval "${key^^}=\"$value\""
        info "  Override: $key = $value"
    done
}

# === Generate CSS (Waybar) ===
generate_css() {
    local wallpaper="$1"
    local output="$THEME_DIR/theme.css"
    info "Generating CSS: $(basename "$output")"

    cat > "$output.tmp" << EOF
/* Auto-generated theme from: $(basename "$wallpaper") */
/* Generated: $(date '+%Y-%m-%d %H:%M:%S') */
/* DO NOT EDIT - changes will be overwritten */

@define-color background $BG;
@define-color foreground $FG;
@define-color cursor $CURSOR;

@define-color crust $CRUST;
@define-color mantle $MANTLE;
@define-color base $BASE;
@define-color surface0 $SURFACE0;
@define-color surface1 $SURFACE1;
@define-color surface2 $SURFACE2;
@define-color overlay0 $OVERLAY0;
@define-color overlay1 $OVERLAY1;
@define-color overlay2 $OVERLAY2;
@define-color subtext0 $SUBTEXT0;
@define-color subtext1 $SUBTEXT1;
@define-color text $TEXT;

@define-color red $RED;
@define-color maroon $MAROON;
@define-color peach $PEACH;
@define-color yellow $YELLOW;
@define-color green $GREEN;
@define-color teal $TEAL;
@define-color sky $SKY;
@define-color sapphire $SAPPHIRE;
@define-color blue $BLUE;
@define-color mauve $MAUVE;
@define-color pink $PINK;
@define-color lavender $LAVENDER;

/* 16-color palette */
@define-color color0 $COLOR0;
@define-color color1 $COLOR1;
@define-color color2 $COLOR2;
@define-color color3 $COLOR3;
@define-color color4 $COLOR4;
@define-color color5 $COLOR5;
@define-color color6 $COLOR6;
@define-color color7 $COLOR7;
@define-color color8 $COLOR8;
@define-color color9 $COLOR9;
@define-color color10 $COLOR10;
@define-color color11 $COLOR11;
@define-color color12 $COLOR12;
@define-color color13 $COLOR13;
@define-color color14 $COLOR14;
@define-color color15 $COLOR15;
EOF

    mv "$output.tmp" "$output"
}

# === Generate RASI (Rofi) ===
generate_rasi() {
    local wallpaper="$1"
    local output="$THEME_DIR/colors.rasi"
    info "Generating RASI: $(basename "$output")"

    cat > "$output.tmp" << EOF
/* Auto-generated theme from: $(basename "$wallpaper") */
/* Generated: $(date '+%Y-%m-%d %H:%M:%S') */
/* DO NOT EDIT - changes will be overwritten */

* {
    background: $BG;
    foreground: $FG;
    background-color: $BG;
    border-color: $BG;
    separatorcolor: $BG;
    normal-foreground: $FG;
    normal-background: $SURFACE0;
    selected-normal-foreground: $MAUVE;
    selected-normal-background: $SURFACE1;
    alternate-normal-foreground: $FG;
    alternate-normal-background: $SURFACE0;
    overlay0: $OVERLAY0;
    overlay1: $OVERLAY1;
    overlay2: $OVERLAY2;
    surface0: $SURFACE0;
    surface1: $SURFACE1;
    surface2: $SURFACE2;
    subtext0: $SUBTEXT0;
    subtext1: $SUBTEXT1;
    urgent-foreground: $RED;
    urgent-background: $SURFACE0;
    selected-urgent-foreground: $MAUVE;
    selected-urgent-background: $SURFACE1;
    active-foreground: $GREEN;
    active-background: $SURFACE0;
    selected-active-foreground: $MAUVE;
    selected-active-background: $SURFACE1;
    spacing: 4;
    border: 0;
    border-radius: 0;
    margin: 0;
    padding: 0;
}
EOF

    mv "$output.tmp" "$output"
}

# === Generate Lua (Hyprland) ===
generate_lua() {
    local wallpaper="$1"
    local output="$THEME_DIR/theme.lua"
    info "Generating Lua: $(basename "$output")"

    local bg_hex="${BG#\#}"
    local fg_hex="${FG#\#}"
    local mauve_hex="${MAUVE#\#}"
    local blue_hex="${BLUE#\#}"
    local surface1_hex="${SURFACE1#\#}"
    local red_hex="${RED#\#}"
    local green_hex="${GREEN#\#}"
    local teal_hex="${TEAL#\#}"
    local yellow_hex="${YELLOW#\#}"
    local pink_hex="${PINK#\#}"
    local crust_hex="${CRUST#\#}"
    local mantle_hex="${MANTLE#\#}"
    local base_hex="${BASE#\#}"
    local surface0_hex="${SURFACE0#\#}"
    local overlay1_hex="${OVERLAY1#\#}"

    cat > "$output.tmp" << LUAEOF
-- Auto-generated theme from: $(basename "$wallpaper")
-- Generated: $(date '+%Y-%m-%d %H:%M:%S')
-- DO NOT EDIT - changes will be overwritten

local theme = {}

-- Colors
theme.colors = {
    background = "$bg_hex",
    foreground = "$fg_hex",
    cursor = "${CURSOR#\#}",
    crust = "$crust_hex",
    mantle = "$mantle_hex",
    base = "$base_hex",
    surface0 = "$surface0_hex",
    surface1 = "$surface1_hex",
    surface2 = "${SURFACE2#\#}",
    overlay0 = "${OVERLAY0#\#}",
    overlay1 = "$overlay1_hex",
    overlay2 = "${OVERLAY2#\#}",
    subtext0 = "${SUBTEXT0#\#}",
    subtext1 = "${SUBTEXT1#\#}",
    text = "$fg_hex",
    red = "$red_hex",
    maroon = "${MAROON#\#}",
    peach = "${PEACH#\#}",
    yellow = "$yellow_hex",
    green = "$green_hex",
    teal = "$teal_hex",
    sky = "${SKY#\#}",
    sapphire = "${SAPPHIRE#\#}",
    blue = "$blue_hex",
    mauve = "$mauve_hex",
    pink = "$pink_hex",
    lavender = "${LAVENDER#\#}",
}

-- Design tokens
theme.tokens = {
    fonts = {
        sans = "$FONT_SANS",
        mono = "$FONT_MONO",
        size = "$FONT_SIZE",
    },
    radii = {
        window = "$RADIUS_WINDOW",
        button = "$RADIUS_BUTTON",
        popup = "$RADIUS_POPUP",
    },
    spacing = {
        tight = "$SPACING_TIGHT",
        normal = "$SPACING_NORMAL",
        wide = "$SPACING_WIDE",
    },
    opacity = {
        background = "$OPACITY_BG",
        background_solid = "$OPACITY_BG_SOLID",
        popup = "$OPACITY_POPUP",
        dim = "$OPACITY_DIM",
    },
    gaps = {
        inner = "$GAPS_INNER",
        outer = "$GAPS_OUTER",
    },
    border = {
        size = "$BORDER_SIZE",
    },
}

-- Helper function for rgba strings
function theme.rgba(hex, alpha)
    alpha = alpha or "ee"
    return "rgba(" .. hex .. alpha .. ")"
end

return theme
LUAEOF

    mv "$output.tmp" "$output"
}

# === Generate Kitty Color Config ===
generate_kitty() {
    local wallpaper="$1"
    local output="$THEME_DIR/kitty.conf"
    info "Generating Kitty: $(basename "$output")"

    cat > "$output.tmp" << KITTYEOF
# Auto-generated theme from: $(basename "$wallpaper")
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# DO NOT EDIT - changes will be overwritten

font_family $FONT_SANS
font_size ${FONT_SIZE/px/}

foreground $FG
background $BG
cursor $MAUVE
selection_foreground $BG
selection_background $MAUVE
color0 $COLOR0
color1 $COLOR1
color2 $COLOR2
color3 $COLOR3
color4 $COLOR4
color5 $COLOR5
color6 $COLOR6
color7 $COLOR7
color8 $COLOR8
color9 $COLOR9
color10 $COLOR10
color11 $COLOR11
color12 $COLOR12
color13 $COLOR13
color14 $COLOR14
color15 $COLOR15
KITTYEOF

    mv "$output.tmp" "$output"
}

# === Generate Yazi Theme ===
generate_yazi() {
    local wallpaper="$1"
    local output="$THEME_DIR/yazi.toml"
    info "Generating Yazi: $(basename "$output")"

    cat > "$output.tmp" << YAZIEOF
# Auto-generated theme from: $(basename "$wallpaper")
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# DO NOT EDIT - changes will be overwritten

[app]
overall = { bg = "$BG" }

[mgr]
cwd = { fg = "$MAUVE" }
find_keyword = { fg = "$YELLOW", bold = true }
find_position = { fg = "$MAUVE" }
symlink_target = { fg = "$TEAL" }
marker_copied = { fg = "$GREEN" }
marker_cut = { fg = "$RED" }
marker_marked = { fg = "$MAUVE" }
marker_selected = { fg = "$BLUE" }
count_copied = { fg = "$GREEN" }
count_cut = { fg = "$RED" }
count_selected = { fg = "$BLUE" }
border_symbol = "│"
border_style = { fg = "$SURFACE1" }

[indicator]
parent = { bg = "$SURFACE0" }
current = { bg = "$SURFACE1" }
preview = { bg = "$SURFACE0" }

[tabs]
active = { fg = "$FG", bg = "$SURFACE1" }
inactive = { fg = "$SUBTEXT0", bg = "$CRUST" }

[mode]
normal_main = { fg = "$BG", bg = "$BLUE" }
normal_alt = { fg = "$FG", bg = "$SURFACE0" }
select_main = { fg = "$BG", bg = "$MAUVE" }
select_alt = { fg = "$FG", bg = "$SURFACE0" }
unset_main = { fg = "$BG", bg = "$TEAL" }
unset_alt = { fg = "$FG", bg = "$SURFACE0" }

[status]
overall = { bg = "$SURFACE0" }
perm_type = { fg = "$MAUVE" }
perm_read = { fg = "$GREEN" }
perm_write = { fg = "$YELLOW" }
perm_exec = { fg = "$RED" }
perm_sep = { fg = "$SUBTEXT0" }
progress_label = { fg = "$FG" }
progress_normal = { bg = "$SURFACE1" }
progress_error = { bg = "$RED" }

[which]
cols = 2
mask = { bg = "$SURFACE0" }
cand = { fg = "$MAUVE", bold = true }
rest = { fg = "$SUBTEXT0" }
desc = { fg = "$FG" }
separator = "  "
separator_style = { fg = "$SUBTEXT0" }

[confirm]
border = { fg = "$SURFACE1" }
title = { fg = "$MAUVE", bold = true }
body = { fg = "$FG" }
list = { fg = "$SUBTEXT1" }
btn_yes = { fg = "$GREEN" }
btn_no = { fg = "$RED" }

[spot]
border = { fg = "$SURFACE1" }
title = { fg = "$MAUVE" }
tbl_col = { fg = "$MAUVE" }
tbl_cell = { fg = "$FG" }

[notify]
title_info = { fg = "$BLUE", bold = true }
title_warn = { fg = "$YELLOW", bold = true }
title_error = { fg = "$RED", bold = true }

[pick]
border = { fg = "$SURFACE1" }
active = { fg = "$BG", bg = "$MAUVE" }
inactive = { fg = "$FG" }

[input]
border = { fg = "$SURFACE1" }
title = { fg = "$MAUVE" }
value = { fg = "$FG" }
selected = { fg = "$MAUVE", bold = true }

[cmp]
border = { fg = "$SURFACE1" }
active = { fg = "$BG", bg = "$MAUVE" }
inactive = { fg = "$FG" }

[tasks]
border = { fg = "$SURFACE1" }
title = { fg = "$MAUVE" }
hovered = { fg = "$BG", bg = "$MAUVE" }

[help]
on = { fg = "$MAUVE", bold = true }
run = { fg = "$FG" }
desc = { fg = "$SUBTEXT1" }
hovered = { fg = "$BG", bg = "$MAUVE" }
footer = { fg = "$SUBTEXT0" }

[filetype]
rules = [
    { mime = "image/*", fg = "$TEAL" },
    { mime = "{audio,video}/*", fg = "$MAUVE" },
    { mime = "inode/empty", fg = "$SUBTEXT0" },
    { mime = "text/*", fg = "$GREEN" },
    { mime = "application/gzip", fg = "$RED" },
    { mime = "application/zip", fg = "$RED" },
    { mime = "application/x-{tar,bzip*}*", fg = "$RED" },
    { mime = "application/pdf", fg = "$PEACH" },
    { url = "*/", fg = "$BLUE" },
    { url = "*", is = "orphan", fg = "$RED" },
]
YAZIEOF

    mv "$output.tmp" "$output"
}

# === Generate Tmux Color Snippet ===
generate_tmux() {
    local wallpaper="$1"
    local output="$THEME_DIR/tmux-colors.conf"
    info "Generating Tmux: $(basename "$output")"

    cat > "$output.tmp" << TMUXEOF
# Auto-generated tmux theme from: $(basename "$wallpaper")
# Generated: $(date '+%Y-%m-%d %H:%M:%S')
# DO NOT EDIT - changes will be overwritten
# Source this from tmux.conf: source-file ~/.config/themes/current/tmux-colors.conf

set -g @thm_bg "$BG"
set -g @thm_fg "$FG"
set -g @thm_rosewater "$TEXT"
set -g @thm_flamingo "$TEXT"
set -g @thm_pink "$COLOR5"
set -g @thm_mauve "$COLOR5"
set -g @thm_red "$COLOR1"
set -g @thm_maroon "$COLOR1"
set -g @thm_peach "$COLOR3"
set -g @thm_yellow "$COLOR3"
set -g @thm_green "$COLOR2"
set -g @thm_teal "$COLOR6"
set -g @thm_sky "$COLOR6"
set -g @thm_sapphire "$COLOR4"
set -g @thm_blue "$COLOR4"
set -g @thm_lavender "$COLOR6"
set -g @thm_subtext_1 "$SUBTEXT1"
set -g @thm_subtext_0 "$SUBTEXT0"
set -g @thm_overlay_2 "$OVERLAY2"
set -g @thm_overlay_1 "$OVERLAY1"
set -g @thm_overlay_0 "$OVERLAY0"
set -g @thm_surface_2 "$SURFACE2"
set -g @thm_surface_1 "$SURFACE1"
set -g @thm_surface_0 "$SURFACE0"
set -g @thm_mantle "$MANTLE"
set -g @thm_crust "$CRUST"
TMUXEOF

    mv "$output.tmp" "$output"
}

# === Generate Neovim Theme Snippet ===
generate_nvim() {
    local wallpaper="$1"
    local output="$THEME_DIR/nvim-colors.lua"
    info "Generating Neovim: $(basename "$output")"

    cat > "$output.tmp" << NVIMEOF
-- Auto-generated neovim theme from: $(basename "$wallpaper")
-- Generated: $(date '+%Y-%m-%d %H:%M:%S')
-- DO NOT EDIT - changes will be overwritten

local M = {}

M.colors = {
    rosewater = "$TEXT",
    flamingo = "$TEXT",
    pink = "${COLOR5#\#}",
    mauve = "${MAUVE#\#}",
    red = "${RED#\#}",
    maroon = "${MAROON#\#}",
    peach = "${PEACH#\#}",
    yellow = "${YELLOW#\#}",
    green = "${GREEN#\#}",
    teal = "${TEAL#\#}",
    sky = "${SKY#\#}",
    sapphire = "${SAPPHIRE#\#}",
    blue = "${BLUE#\#}",
    lavender = "${LAVENDER#\#}",
    text = "${FG#\#}",
    subtext1 = "${SUBTEXT1#\#}",
    subtext0 = "${SUBTEXT0#\#}",
    overlay2 = "${OVERLAY2#\#}",
    overlay1 = "${OVERLAY1#\#}",
    overlay0 = "${OVERLAY0#\#}",
    surface2 = "${SURFACE2#\#}",
    surface1 = "${SURFACE1#\#}",
    surface0 = "${SURFACE0#\#}",
    base = "${BG#\#}",
    mantle = "${MANTLE#\#}",
    crust = "${CRUST#\#}",
}

function M.override(catppuccin_colors)
    for k, v in pairs(M.colors) do
        catppuccin_colors[k] = v
    end
    return catppuccin_colors
end

return M
NVIMEOF

    mv "$output.tmp" "$output"
}

# === Update Symlinks Atomically ===
update_symlinks() {
    info "Updating symlinks..."

    local configs=(
        "$HOME/.config/waybar/theme.css"
        "$HOME/.config/rofi/colors.rasi"
        "$HOME/.config/hypr/theme.lua"
        "$HOME/.config/kitty/current-theme.conf"
        "$HOME/.config/yazi/theme.toml"
        "$HOME/.config/tmux/tmux-colors.conf"
        "$HOME/.config/nvim/lua/theme.lua"
    )

    local targets=(
        "$THEME_DIR/theme.css"
        "$THEME_DIR/colors.rasi"
        "$THEME_DIR/theme.lua"
        "$THEME_DIR/kitty.conf"
        "$THEME_DIR/yazi.toml"
        "$THEME_DIR/tmux-colors.conf"
        "$THEME_DIR/nvim-colors.lua"
    )

    for i in "${!configs[@]}"; do
        local config="${configs[$i]}"
        local target="${targets[$i]}"

        local config_dir
        config_dir=$(dirname "$config")
        mkdir -p "$config_dir"

        if [[ -e "$config" && ! -L "$config" ]]; then
            local backup="${config}.bak.$(date +%Y%m%d%H%M%S)"
            cp "$config" "$backup"
            info "  Backed up: $(basename "$config") -> $(basename "$backup")"
        fi

        rm -f "$config"
        ln -s "$target" "$config"
        info "  Linked: $(basename "$config") -> $target"
    done
}

# === Save copy to available themes ===
save_to_available() {
    local name="$1"

    if [[ "$name" == "auto" ]]; then
        name="auto-$(date +%Y%m%d-%H%M%S)"
    fi

    local dest="$AVAILABLE_DIR/$name"
    mkdir -p "$dest"

    for f in theme.css colors.rasi theme.lua kitty.conf yazi.toml tmux-colors.conf nvim-colors.lua metadata.json; do
        cp "$THEME_DIR/$f" "$dest/$f" 2>/dev/null || true
    done

    info "Saved theme to: available/$name"
}

# === Reload Configs ===
reload_configs() {
    info "Reloading configurations..."

    if pgrep -x "waybar" > /dev/null 2>&1; then
        pkill -SIGUSR2 waybar
        info "  Waybar reloaded (SIGUSR2)"
    else
        info "  Waybar not running, skipping reload"
    fi

    if command -v hyprctl > /dev/null 2>&1; then
        hyprctl reload 2>/dev/null && info "  Hyprland reloaded" || warn "  Hyprland reload failed"
    else
        warn "  hyprctl not available, skipping Hyprland reload"
    fi

    info "  Rofi will use new theme on next launch"

    if pgrep -x "kitty" > /dev/null 2>&1; then
        killall -SIGUSR1 kitty 2>/dev/null && info "  Kitty reloaded (SIGUSR1)" || warn "  Kitty reload failed"
    else
        info "  Kitty not running, skipping reload"
    fi

    info "  Yazi will use new theme on next launch"
    info "  Tmux will use new theme on next source-file or server restart"
    info "  Neovim will use new theme on next restart"
}

# === Save Metadata ===
save_metadata() {
    local wallpaper="$1"
    local metadata="$THEME_DIR/metadata.json"

    cat > "$metadata" << EOF
{
    "wallpaper": "$wallpaper",
    "generated": "$(date -Iseconds)",
    "generator": "auto-extract",
    "theme_name": "$THEME_NAME",
    "mode": "dark",
    "overrides_applied": $([[ -f "$OVERRIDE_FILE" ]] && echo "true" || echo "false")
}
EOF

    info "Metadata saved"
}

# === Main Execution ===
RELOAD=true

main() {
    info "=== Theme Generation Started ==="

    swaync-client -Ia "theme-generator" 2>/dev/null || true
    trap 'swaync-client -Ir "theme-generator" 2>/dev/null || true' EXIT

    local wallpaper=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --no-reload)
                RELOAD=false
                shift
                ;;
            --save-as)
                if [[ -n "${2:-}" ]]; then
                    THEME_NAME="$2"
                    shift 2
                else
                    error "--save-as requires a theme name"
                    exit 1
                fi
                ;;
            *)
                if [[ -z "$wallpaper" ]]; then
                    wallpaper="$1"
                fi
                shift
                ;;
        esac
    done

    wallpaper=$(resolve_wallpaper "$wallpaper")
    info "Wallpaper: $(basename "$wallpaper")"

    mkdir -p "$THEME_DIR"
    mkdir -p "$AVAILABLE_DIR"

    run_extract "$wallpaper"
    parse_colors
    load_tokens

    generate_css "$wallpaper"
    generate_rasi "$wallpaper"
    generate_lua "$wallpaper"
    generate_kitty "$wallpaper"
    generate_yazi "$wallpaper"
    generate_tmux "$wallpaper"
    generate_nvim "$wallpaper"

    update_symlinks
    save_to_available "$THEME_NAME"

    if [[ "$RELOAD" == "true" ]]; then
        reload_configs
    else
        info "Skipping config reload (--no-reload)"
    fi

    save_metadata "$wallpaper"

    notify "Theme Updated" "Colors generated from $(basename "$wallpaper")"
    info "=== Theme Generation Complete ==="
}

main "$@"
