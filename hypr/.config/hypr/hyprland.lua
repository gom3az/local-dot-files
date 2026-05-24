-- =====================================================================
-- HYPRLAND LUA CONFIG (v0.55+)
-- =====================================================================

-- Load dynamic theme (auto-generated from wallpaper)
-- Returns a theme table with .colors and .tokens subtables
local function load_theme(path)
    local f = io.open(path, "r")
    if f then
        f:close()
        return dofile(path)
    end
    return nil
end

local function default_theme()
    return {
        colors = {
            mauve = "EE96A6", blue = "F28A99", red = "dcdcff", green = "ffd1f9",
            yellow = "cae2ff", teal = "f0dae3", pink = "f0d7f4",
            surface0 = "24201b", surface1 = "3c3834", surface2 = "595552",
            overlay0 = "75726f", overlay1 = "918f8d", overlay2 = "acaaa8",
            subtext0 = "6e6c69", subtext1 = "8b8986", text = "c3c2c1",
            background = "120d08", foreground = "c3c2c1", cursor = "c3c2c1",
            crust = "110c07", mantle = "110c07", base = "120d08",
        },
        rgba = function(hex, alpha)
            alpha = alpha or "ee"
            return "rgba(" .. hex .. alpha .. ")"
        end,
    }
end

local home = os.getenv("HOME")
local theme = load_theme(home .. "/.config/hypr/theme.lua")
            or load_theme(home .. "/.config/hypr/colors.lua")
            or default_theme()

-- See https://wiki.hypr.land/Configuring/Start/

------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
hl.monitor({
	output = "DP-3",
	mode = "2560x1440@120",
	position = "auto",
	scale = "1",
})

---------------------
---- MY PROGRAMS ----
---------------------
local terminal = "kitty"
local fileManager = "dolphin"
local menu = "rofi -show drun"

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP")
	hl.exec_cmd("waybar")
	hl.exec_cmd("swaync")
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("wl-paste --watch $HOME/.config/scripts/cliphist.sh add")
end)

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
-- hl.on("hyprland.start", function ()
--   hl.exec_cmd(terminal)
-- end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "breeze_cursors")
hl.env("HYPRCURSOR_THEME", "breeze_cursors")
hl.env("QT_QPA_PLATFORMTHEME", "gtk3")

-----------------------
---- LOOK AND FEEL ----
-----------------------

-- Refer to https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
	general = {
		gaps_in = 5,
		gaps_out = 5,
		border_size = 2,

		col = {
			active_border = { colors = { theme.rgba(theme.colors.mauve, "ee"), theme.rgba(theme.colors.blue, "ee") }, angle = 45 },
			inactive_border = theme.rgba(theme.colors.surface1, "aa"),
		},

		resize_on_border = false,
		allow_tearing = false,
		layout = "dwindle",
	},

	decoration = {
		rounding = 0,

		active_opacity = 1.0,
		inactive_opacity = 1.0,

		shadow = {
			enabled = true,
			range = 4,
			color = tonumber("0xee" .. theme.colors.background),
		},

		blur = {
			enabled = true,
			size = 3,
			passes = 1,
			vibrancy = 0.1696,
		},
	},

	animations = {
		enabled = true,
	},
})

hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

hl.animation({ leaf = "border", enabled = false })
hl.animation({ leaf = "windows", enabled = true, speed = 1.1, bezier = "linear" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.1, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.1, bezier = "linear", style = "popin 87%" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.1, bezier = "linear" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.1, bezier = "linear" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.1, bezier = "linear" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.1, bezier = "linear" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.1, bezier = "linear" })
hl.animation({ leaf = "layers", enabled = true, speed = 1.1, bezier = "linear" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 1.1, bezier = "linear", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.1, bezier = "linear", style = "fade" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 1.1, bezier = "linear", style = "fade" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 1.1, bezier = "linear", style = "fade" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 1.1, bezier = "linear", style = "fade" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 1.1, bezier = "linear" })

hl.config({
	dwindle = {
		preserve_split = true,
	},
})

hl.config({
	misc = {
		force_default_wallpaper = -1,
		disable_hyprland_logo = false,
		disable_hyprland_guiutils_check = true,
	},
})

---------------
---- INPUT ----
---------------

hl.config({
	input = {
		kb_layout = "us,ara",
		kb_options = "grp:alt_shift_toggle",
		follow_mouse = 1,
		sensitivity = 0,

		touchpad = {
			natural_scroll = false,
		},
	},
})

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"
hl.bind(mainMod .. " + s", hl.dsp.exec_cmd("$HOME/.config/rofi/scripts/screenshot.sh"))
hl.bind(mainMod .. " + SHIFT + " .. "l", hl.dsp.exec_cmd("hyprlock"))

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(
	mainMod .. " + M",
	hl.dsp.exec_cmd("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch exit")
)
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd(menu))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("~/.config/scripts/wallpaper-rofi.sh"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("$HOME/.config/scripts/theme-switcher.sh rofi"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t"))
hl.bind(mainMod .. " + SHIFT + " .. "V", hl.dsp.exec_cmd("$HOME/.config/scripts/cliphist.sh sel"))
hl.bind(mainMod .. " + SHIFT + " .. "P", hl.dsp.exec_cmd("$HOME/.config/scripts/cliphist.sh pin"))
hl.bind(mainMod .. " + SHIFT + " .. "Escape", hl.dsp.exec_cmd("$HOME/.config/scripts/kill-menu.sh"))
hl.bind(mainMod .. " + h", hl.dsp.focus({ direction = "left" }))
hl.bind(mainMod .. " + l", hl.dsp.focus({ direction = "right" }))
hl.bind(mainMod .. " + k", hl.dsp.focus({ direction = "up" }))
hl.bind(mainMod .. " + j", hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
	local key = i % 10
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMicMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"),
	{ locked = true, repeating = true }
)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })

hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
