-- Auto-generated theme from: fern-m-lomibao-B8OQ551nFFc-unsplash.jpg
-- Generated: 2026-05-23 19:30:48
-- DO NOT EDIT - changes will be overwritten

local theme = {}

-- Colors
theme.colors = {
    background = "120d08",
    foreground = "c3c2c1",
    cursor = "c3c2c1",
    crust = "110c07",
    mantle = "110c07",
    base = "120d08",
    surface0 = "24201b",
    surface1 = "3c3834",
    surface2 = "595552",
    overlay0 = "75726f",
    overlay1 = "918f8d",
    overlay2 = "acaaa8",
    subtext0 = "6e6c69",
    subtext1 = "8b8986",
    text = "c3c2c1",
    red = "dcdcff",
    maroon = "dcdcff",
    peach = "cae2ff",
    yellow = "cae2ff",
    green = "ffd1f9",
    teal = "f0dae3",
    sky = "f0dae3",
    sapphire = "d4e0ff",
    blue = "F28A99",
    mauve = "EE96A6",
    pink = "f0d7f4",
    lavender = "f0dae3",
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
