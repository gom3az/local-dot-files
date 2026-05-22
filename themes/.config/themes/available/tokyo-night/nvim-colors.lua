-- Static theme: tokyo-night
local M = {}

M.colors = {
    rosewater = "#a9b1d6",
    flamingo = "#a9b1d6",
    pink = "bb9af7",
    mauve = "bb9af7",
    red = "f7768e",
    maroon = "f7768e",
    peach = "e0af68",
    yellow = "e0af68",
    green = "9ece6a",
    teal = "7dcfff",
    sky = "7dcfff",
    sapphire = "7aa2f7",
    blue = "7aa2f7",
    lavender = "7dcfff",
    text = "a9b1d6",
    subtext1 = "9aa5ce",
    subtext0 = "8b93b3",
    overlay2 = "7b83a2",
    overlay1 = "6a7391",
    overlay0 = "565f89",
    surface2 = "414868",
    surface1 = "2f3346",
    surface0 = "24283b",
    base = "1a1b26",
    mantle = "16161e",
    crust = "15161e",
}

function M.override(catppuccin_colors)
    for k, v in pairs(M.colors) do
        catppuccin_colors[k] = v
    end
    return catppuccin_colors
end

return M
