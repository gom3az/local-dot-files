-- Auto-generated neovim theme from: fern-m-lomibao-B8OQ551nFFc-unsplash.jpg
-- Generated: 2026-05-23 19:00:28
-- DO NOT EDIT - changes will be overwritten

local M = {}

M.colors = {
    rosewater = "#c3c2c1",
    flamingo = "#c3c2c1",
    pink = "f0d7f4",
    mauve = "EE96A6",
    red = "dcdcff",
    maroon = "dcdcff",
    peach = "cae2ff",
    yellow = "cae2ff",
    green = "ffd1f9",
    teal = "f0dae3",
    sky = "f0dae3",
    sapphire = "d4e0ff",
    blue = "F28A99",
    lavender = "f0dae3",
    text = "c3c2c1",
    subtext1 = "8b8986",
    subtext0 = "6e6c69",
    overlay2 = "acaaa8",
    overlay1 = "918f8d",
    overlay0 = "75726f",
    surface2 = "595552",
    surface1 = "3c3834",
    surface0 = "24201b",
    base = "120d08",
    mantle = "110c07",
    crust = "110c07",
}

function M.override(catppuccin_colors)
    for k, v in pairs(M.colors) do
        catppuccin_colors[k] = v
    end
    return catppuccin_colors
end

return M
