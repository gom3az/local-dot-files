-- Static theme: gruvbox
local M = {}

M.colors = {
    rosewater = "#ebdbb2",
    flamingo = "#ebdbb2",
    pink = "b16286",
    mauve = "b16286",
    red = "cc241d",
    maroon = "cc241d",
    peach = "d79921",
    yellow = "d79921",
    green = "98971a",
    teal = "689d6a",
    sky = "689d6a",
    sapphire = "458588",
    blue = "458588",
    lavender = "689d6a",
    text = "ebdbb2",
    subtext1 = "d5c4a1",
    subtext0 = "bdae93",
    overlay2 = "a89984",
    overlay1 = "928374",
    overlay0 = "7c6f64",
    surface2 = "665c54",
    surface1 = "504945",
    surface0 = "3c3836",
    base = "282828",
    mantle = "1d2021",
    crust = "1d2021",
}

function M.override(catppuccin_colors)
    for k, v in pairs(M.colors) do
        catppuccin_colors[k] = v
    end
    return catppuccin_colors
end

return M
