-- Static theme: gruvbox

local theme = {}

theme.colors = {
    background = "282828",
    foreground = "ebdbb2",
    cursor = "fe8019",
    crust = "1d2021",
    mantle = "1d2021",
    base = "282828",
    surface0 = "3c3836",
    surface1 = "504945",
    surface2 = "665c54",
    overlay0 = "7c6f64",
    overlay1 = "928374",
    overlay2 = "a89984",
    subtext0 = "bdae93",
    subtext1 = "d5c4a1",
    text = "ebdbb2",
    red = "cc241d",
    maroon = "cc241d",
    peach = "d79921",
    yellow = "d79921",
    green = "98971a",
    teal = "689d6a",
    sky = "689d6a",
    sapphire = "458588",
    blue = "458588",
    mauve = "b16286",
    pink = "b16286",
    lavender = "689d6a",
}

function theme.rgba(hex, alpha)
    alpha = alpha or "ee"
    return "rgba(" .. hex .. alpha .. ")"
end

return theme
