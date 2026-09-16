-- Static theme: catppuccin-mocha

local theme = {}

theme.colors = {
    background = "1e1e2e",
    foreground = "cdd6f4",
    cursor = "f5e0dc",
    crust = "11111b",
    mantle = "181825",
    base = "1e1e2e",
    surface0 = "313244",
    surface1 = "45475a",
    surface2 = "585b70",
    overlay0 = "6c7086",
    overlay1 = "7f849c",
    overlay2 = "9399b2",
    subtext0 = "a6adc8",
    subtext1 = "bac2de",
    text = "cdd6f4",
    red = "f38ba8",
    maroon = "eba0ac",
    peach = "fab387",
    yellow = "f9e2af",
    green = "a6e3a1",
    teal = "94e2d5",
    sky = "89dceb",
    sapphire = "74c7ec",
    blue = "89b4fa",
    mauve = "cba6f7",
    pink = "f5c2e7",
    lavender = "b4befe",
}

function theme.rgba(hex, alpha)
    alpha = alpha or "ee"
    return "rgba(" .. hex .. alpha .. ")"
end

return theme
