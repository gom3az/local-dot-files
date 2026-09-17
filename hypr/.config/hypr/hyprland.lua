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

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
	hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE")
	hl.exec_cmd("systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_TYPE")
	hl.exec_cmd("systemctl --user start graphical-session.target")
	hl.exec_cmd("systemctl --user start xdg-desktop-portal")
	hl.exec_cmd("waybar")
	hl.exec_cmd("hyprpaper")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("wl-paste --watch $HOME/.local/bin/flex-clip add")
	hl.exec_cmd("$HOME/.local/bin/flex-notify daemon")
	-- Default to high-quality A2DP (switch the card profile to headset when the mic is needed)
	hl.exec_cmd("sleep 2 && pactl set-card-profile alsa_card.pci-0000_12_00.6 off; pactl set-card-profile bluez_card.5C_DC_49_8F_03_26 a2dp-sink || true")
end)

-- See https://wiki.hypr.land/Configuring/Basics/Autostart/
-- hl.on("hyprland.start", function ()
--   hl.exec_cmd(terminal)
-- end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Environment-variables/
hl.env("TERMINAL", terminal)
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
hl.bind(mainMod .. " + s", hl.dsp.exec_cmd("$HOME/.local/bin/flex-shot"))
hl.bind(mainMod .. " + SHIFT + " .. "s", hl.dsp.exec_cmd("$HOME/.local/bin/flex-record stop"))
hl.bind(mainMod .. " + SHIFT + " .. "l", hl.dsp.exec_cmd("hyprlock"))

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(
	mainMod .. " + M",
	hl.dsp.exec_cmd("$HOME/.local/bin/flex-power")
)
hl.bind(mainMod .. " + E", hl.dsp.exec_cmd(fileManager))
hl.bind(mainMod .. " + V", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + X", hl.dsp.exec_cmd("$HOME/.local/bin/flex-center"))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd("$HOME/.local/bin/flex-launch"))
hl.bind(mainMod .. " + space", hl.dsp.exec_cmd("$HOME/.local/bin/flex-launch"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd("$HOME/.local/bin/flex-wallpaper"))
hl.bind(mainMod .. " + T", hl.dsp.exec_cmd("$HOME/.local/bin/flex-theme"))
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("$HOME/.local/bin/flex notify"))
hl.bind(mainMod .. " + SHIFT + " .. "V", hl.dsp.exec_cmd("$HOME/.local/bin/flex-clip"))
hl.bind(mainMod .. " + SHIFT + " .. "P", hl.dsp.exec_cmd("$HOME/.local/bin/flex-clip pin"))
hl.bind(mainMod .. " + SHIFT + " .. "Escape", hl.dsp.exec_cmd("$HOME/.local/bin/flex-proc"))
hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("$HOME/.local/bin/flex-mixer"))
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

---------------------
---- WINDOW RULES ---
---------------------

-- Exiled Exchange 2 overlay
hl.window_rule({
	name = "EE2 Overlay",
	match = { class = "exiled-exchange-2" },
	float = true,
	no_focus = true,
	no_initial_focus = true,
	no_anim = true,
	border_size = 0,
	no_shadow = true,
	no_blur = true,
})

-- Floating wiremix mixer (kitty + wiremix, toggled via SUPER+A / Waybar).
-- Compact centered popup; size enforced here, font (10pt) in the launcher.
hl.window_rule({
	name = "wiremix-mixer",
	match = { class = "kitty-wiremix" },
	float = true,
	size = { 640, 420 },
	stay_focused = true,
})

-- Floating flex popup menus (flex TUIs, launched via flex popup).
-- `stay_focused` keeps the popup's keyboard focus while it is visible, so
-- moving the cursor off it (over a fullscreen game, with follow_mouse=1) does
-- not hand focus back to the window under the cursor.
hl.window_rule({
	name = "popup-menu",
	match = { class = "flex-menu" },
	float = true,
	size = { 640, 420 },
	stay_focused = true,
})
hl.window_rule({
	name = "popup-menu-wide",
	match = { class = "flex-menu-wide" },
	float = true,
	size = { 1000, 600 },
	stay_focused = true,
})
hl.window_rule({
	name = "popup-menu-drawer",
	match = { class = "flex-notify-center" },
	float = true,
	size = { 460, 1340 },
	move = { 2090, 48 },
	stay_focused = true,
})

-- Transient notification toast: top-right corner, no focus steal, no borders.
-- Width=500 (~50 chars at 11pt), Height=96 (5 rows with vertical padding). X=2560-500-16=2044, Y=52.
hl.window_rule({
	name = "notify-toast",
	match = { class = "flex-notify-toast" },
	float = true,
	size = { 500, 96 },
	move = { 2044, 52 },
	no_focus = true,
	no_initial_focus = true,
	border_size = 0,
	no_shadow = true,
	no_blur = true,
	no_anim = true,
	pin = true,
})

-- A fullscreen game holding an active pointer constraint suppresses the
-- initial focus of any new window (Window.cpp: `!isConstrained()`), so the
-- popup opens unfocused and keystrokes keep reaching the game. Re-focus flex
-- popups explicitly once mapped; `hl.dsp.focus` is not gated by that guard.
hl.on("window.open", function(w)
	if
		w.class == "flex-menu"
		or w.class == "flex-menu-wide"
		or w.class == "kitty-wiremix"
		or w.class == "flex-notify-center"
	then
		hl.dispatch(hl.dsp.focus({ window = w }))
	end
end)
