-- Static theme: catppuccin-mocha
local M = {}

M.colors = {
    rosewater = "#cdd6f4",
    flamingo = "#cdd6f4",
    pink = "cba6f7",
    mauve = "cba6f7",
    red = "f38ba8",
    maroon = "f38ba8",
    peach = "f9e2af",
    yellow = "f9e2af",
    green = "a6e3a1",
    teal = "94e2d5",
    sky = "94e2d5",
    sapphire = "89b4fa",
    blue = "89b4fa",
    lavender = "94e2d5",
    text = "cdd6f4",
    subtext1 = "bac2de",
    subtext0 = "a6adc8",
    overlay2 = "9399b2",
    overlay1 = "7f849c",
    overlay0 = "6c7086",
    surface2 = "585b70",
    surface1 = "45475a",
    surface0 = "313244",
    base = "1e1e2e",
    mantle = "181825",
    crust = "11111b",
}

function M.override(catppuccin_colors)
    for k, v in pairs(M.colors) do
        catppuccin_colors[k] = v
    end
    return catppuccin_colors
end

return M
