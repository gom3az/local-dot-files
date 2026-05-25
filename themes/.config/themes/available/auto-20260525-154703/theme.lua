-- Auto-generated theme from: urban-vintage-78A265wPiO4-unsplash.jpg
-- Generated: 2026-05-25 15:47:03
-- DO NOT EDIT - changes will be overwritten

local theme = {}

-- Colors
theme.colors = {
    background = "1f1f0d",
    foreground = "c7c7c2",
    cursor = "c7c7c2",
    crust = "1d1d0c",
    mantle = "1e1e0c",
    base = "1f1f0d",
    surface0 = "303020",
    surface1 = "474738",
    surface2 = "626255",
    overlay0 = "7d7d72",
    overlay1 = "97978f",
    overlay2 = "b0b0aa",
    subtext0 = "79796f",
    subtext1 = "98988f",
    text = "c7c7c2",
    red = "f1f616",
    maroon = "f1f616",
    peach = "ffedb5",
    yellow = "ffedb5",
    green = "e0f1e0",
    teal = "ffedbb",
    sky = "ffedbb",
    sapphire = "f7efc1",
    blue = "F28A99",
    mauve = "EE96A6",
    pink = "ffecbd",
    lavender = "ffedbb",
}

-- Design tokens
theme.tokens = {
    fonts = {
        sans = "NotoSans Nerd Font",
        mono = "NotoSans Nerd Font",
        size = "12px",
    },
    radii = {
        window = "0",
        button = "0",
        popup = "0",
    },
    spacing = {
        tight = "4px",
        normal = "8px",
        wide = "16px",
    },
    opacity = {
        background = "0.8",
        background_solid = "1.0",
        popup = "0.95",
        dim = "0.3",
    },
    gaps = {
        inner = "5",
        outer = "5",
    },
    border = {
        size = "2",
    },
}

-- Helper function for rgba strings
function theme.rgba(hex, alpha)
    alpha = alpha or "ee"
    return "rgba(" .. hex .. alpha .. ")"
end

return theme
