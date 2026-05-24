-- Auto-generated neovim theme from: jonatan-pie-3l3RwQdHRHg-unsplash.jpg
-- Generated: 2026-05-23 19:00:39
-- DO NOT EDIT - changes will be overwritten

local M = {}

M.colors = {
    rosewater = "#c2c3c5",
    flamingo = "#c2c3c5",
    pink = "229eb0",
    mauve = "EE96A6",
    red = "1897e3",
    maroon = "1897e3",
    peach = "3690ff",
    yellow = "3690ff",
    green = "39a27c",
    teal = "3d9e9f",
    sky = "3d9e9f",
    sapphire = "1696e8",
    blue = "F28A99",
    lavender = "3d9e9f",
    text = "c2c3c5",
    subtext1 = "888b8f",
    subtext0 = "6b6e73",
    overlay2 = "a9abae",
    overlay1 = "8e9195",
    overlay0 = "71747a",
    surface2 = "54585e",
    surface1 = "363b43",
    surface0 = "1e242c",
    base = "0b111a",
    mantle = "0a1019",
    crust = "0a1018",
}

function M.override(catppuccin_colors)
    for k, v in pairs(M.colors) do
        catppuccin_colors[k] = v
    end
    return catppuccin_colors
end

return M
