-- Auto-generated theme from: jonatan-pie-3l3RwQdHRHg-unsplash.jpg
-- Generated: 2026-05-23 19:00:39
-- DO NOT EDIT - changes will be overwritten

local theme = {}

-- Colors
theme.colors = {
    background = "0b111a",
    foreground = "c2c3c5",
    cursor = "c2c3c5",
    crust = "0a1018",
    mantle = "0a1019",
    base = "0b111a",
    surface0 = "1e242c",
    surface1 = "363b43",
    surface2 = "54585e",
    overlay0 = "71747a",
    overlay1 = "8e9195",
    overlay2 = "a9abae",
    subtext0 = "6b6e73",
    subtext1 = "888b8f",
    text = "c2c3c5",
    red = "1897e3",
    maroon = "1897e3",
    peach = "3690ff",
    yellow = "3690ff",
    green = "39a27c",
    teal = "3d9e9f",
    sky = "3d9e9f",
    sapphire = "1696e8",
    blue = "F28A99",
    mauve = "EE96A6",
    pink = "229eb0",
    lavender = "3d9e9f",
}

-- Design tokens
theme.tokens = {
    fonts = {
        sans = "JetBrainsMono Nerd Font",
        mono = "JetBrainsMono Nerd Font",
        size = "13px",
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
