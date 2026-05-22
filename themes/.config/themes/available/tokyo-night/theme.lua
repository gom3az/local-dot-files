-- Static theme: tokyo-night

local theme = {}

theme.colors = {
    background = "1a1b26",
    foreground = "a9b1d6",
    cursor = "c0caf5",
    crust = "15161e",
    mantle = "16161e",
    base = "1a1b26",
    surface0 = "24283b",
    surface1 = "2f3346",
    surface2 = "414868",
    overlay0 = "565f89",
    overlay1 = "6a7391",
    overlay2 = "7b83a2",
    subtext0 = "8b93b3",
    subtext1 = "9aa5ce",
    text = "a9b1d6",
    red = "f7768e",
    maroon = "f7768e",
    peach = "e0af68",
    yellow = "e0af68",
    green = "9ece6a",
    teal = "7dcfff",
    sky = "7dcfff",
    sapphire = "7aa2f7",
    blue = "7aa2f7",
    mauve = "bb9af7",
    pink = "bb9af7",
    lavender = "7dcfff",
}

function theme.rgba(hex, alpha)
    alpha = alpha or "ee"
    return "rgba(" .. hex .. alpha .. ")"
end

return theme
