-- Auto-generated neovim theme from: urban-vintage-78A265wPiO4-unsplash.jpg
-- Generated: 2026-05-23 19:03:09
-- DO NOT EDIT - changes will be overwritten

local M = {}

M.colors = {
    rosewater = "#c7c7c2",
    flamingo = "#c7c7c2",
    pink = "ffecbd",
    mauve = "EE96A6",
    red = "f1f616",
    maroon = "f1f616",
    peach = "ffedb5",
    yellow = "ffedb5",
    green = "e0f1e0",
    teal = "ffedbb",
    sky = "ffedbb",
    sapphire = "f7efc1",
    blue = "F28A99",
    lavender = "ffedbb",
    text = "c7c7c2",
    subtext1 = "98988f",
    subtext0 = "79796f",
    overlay2 = "b0b0aa",
    overlay1 = "97978f",
    overlay0 = "7d7d72",
    surface2 = "626255",
    surface1 = "474738",
    surface0 = "303020",
    base = "1f1f0d",
    mantle = "1e1e0c",
    crust = "1d1d0c",
}

function M.override(catppuccin_colors)
    for k, v in pairs(M.colors) do
        catppuccin_colors[k] = v
    end
    return catppuccin_colors
end

return M
