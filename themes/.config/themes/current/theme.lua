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
    maroon = "f38ba8",
    peach = "f9e2af",
    yellow = "f9e2af",
    green = "a6e3a1",
    teal = "94e2d5",
    sky = "94e2d5",
    sapphire = "89b4fa",
    blue = "89b4fa",
    mauve = "cba6f7",
    pink = "cba6f7",
    lavender = "94e2d5",
}

function theme.rgba(hex, alpha)
    alpha = alpha or "ee"
    return "rgba(" .. hex .. alpha .. ")"
end

return theme
