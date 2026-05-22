#!/usr/bin/env python3
"""Extract colors from wallpaper using pywal16 and generate Catppuccin-style hierarchy."""

import json
import subprocess
import sys
from pathlib import Path


WAL_CACHE = Path.home() / ".cache" / "wal" / "colors.json"


def hex_to_rgb(h):
    h = h.lstrip("#")
    return int(h[:2], 16), int(h[2:4], 16), int(h[4:6], 16)


def rgb_to_hex(r, g, b):
    return f"#{r:02x}{g:02x}{b:02x}"


def relative_luminance(r, g, b):
    r, g, b = r / 255, g / 255, b / 255
    def linearize(c):
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)


def contrast_ratio(c1_hex, c2_hex):
    r1, g1, b1 = hex_to_rgb(c1_hex)
    r2, g2, b2 = hex_to_rgb(c2_hex)
    l1 = relative_luminance(r1, g1, b1)
    l2 = relative_luminance(r2, g2, b2)
    lighter = max(l1, l2)
    darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)


def lighten_hex(h, amount):
    r, g, b = hex_to_rgb(h)
    r = min(255, int(r + (255 - r) * amount))
    g = min(255, int(g + (255 - g) * amount))
    b = min(255, int(b + (255 - b) * amount))
    return rgb_to_hex(r, g, b)


def darken_hex(h, amount):
    r, g, b = hex_to_rgb(h)
    return rgb_to_hex(
        int(r * (1 - amount)),
        int(g * (1 - amount)),
        int(b * (1 - amount)),
    )


def blend_hex(fg, bg, ratio):
    fr, fg_c, fb = hex_to_rgb(fg)
    br, bg_c, bb = hex_to_rgb(bg)
    return rgb_to_hex(
        int(fr * ratio + br * (1 - ratio)),
        int(fg_c * ratio + bg_c * (1 - ratio)),
        int(fb * ratio + bb * (1 - ratio)),
    )


def build_semantic_hierarchy(bg_hex, fg_hex, accent_hexes):
    """Generate Catppuccin-style semantic hierarchy with contrast enforcement."""

    crust = darken_hex(bg_hex, 0.05)
    mantle = darken_hex(bg_hex, 0.02)
    base = bg_hex

    # Text-bearing surfaces — kept dark enough for ≥4.5:1 contrast with fg
    surface0 = lighten_hex(bg_hex, 0.08)
    surface1 = lighten_hex(bg_hex, 0.18)

    # Non-text layers where text doesn't need full AA contrast
    surface2 = lighten_hex(bg_hex, 0.30)
    overlay0 = lighten_hex(bg_hex, 0.42)
    overlay1 = lighten_hex(bg_hex, 0.54)
    overlay2 = lighten_hex(bg_hex, 0.65)

    text = fg_hex

    # Muted subtext: blend fg into base, starting muted and brightening
    # until minimum contrast against the darkest text surface is met.
    dark_surface = surface0

    def muted_subtext(fg_ratio_start, min_ratio):
        for pct in range(int(fg_ratio_start * 100), 96, 2):
            r = pct / 100
            candidate = blend_hex(fg_hex, dark_surface, r)
            if contrast_ratio(candidate, dark_surface) >= min_ratio:
                return candidate
        return blend_hex(fg_hex, dark_surface, 0.95)

    subtext0 = muted_subtext(0.35, 3.0)
    subtext1 = muted_subtext(0.55, 4.5)

    return {
        "crust": crust,
        "mantle": mantle,
        "base": base,
        "surface0": surface0,
        "surface1": surface1,
        "surface2": surface2,
        "overlay0": overlay0,
        "overlay1": overlay1,
        "overlay2": overlay2,
        "subtext0": subtext0,
        "subtext1": subtext1,
        "text": text,
        "red": accent_hexes[0],
        "maroon": accent_hexes[0],
        "green": accent_hexes[1],
        "yellow": accent_hexes[2],
        "peach": accent_hexes[2],
        "blue": accent_hexes[3],
        "sapphire": accent_hexes[3],
        "mauve": accent_hexes[4],
        "pink": accent_hexes[4],
        "teal": accent_hexes[5],
        "sky": accent_hexes[5],
        "lavender": accent_hexes[5],
    }


def main():
    if len(sys.argv) < 2:
        print("Usage: extract-colors.py <image_path> [output_path]", file=sys.stderr)
        sys.exit(1)

    img_path = sys.argv[1]
    output_path = sys.argv[2] if len(sys.argv) > 2 else None

    if not Path(img_path).exists():
        print(f"Error: {img_path} not found", file=sys.stderr)
        sys.exit(1)

    # Call pywal16
    try:
        subprocess.run(
            ["wal", "-i", img_path, "--cols16", "darken", "--contrast", "4.5", "-n", "-q"],
            check=True, capture_output=True,
        )
    except FileNotFoundError:
        print("Error: 'wal' not found. Install pywal16 or check PATH.", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError as e:
        print(f"Error: pywal16 failed: {e.stderr.decode()}", file=sys.stderr)
        sys.exit(1)

    if not WAL_CACHE.exists():
        print(f"Error: {WAL_CACHE} not found after pywal16 run", file=sys.stderr)
        sys.exit(1)

    wal_data = json.loads(WAL_CACHE.read_text())

    bg = wal_data["special"]["background"]
    fg = wal_data["special"]["foreground"]
    accents = [wal_data["colors"][f"color{i}"] for i in range(1, 7)]

    semantic = build_semantic_hierarchy(bg, fg, accents)

    result = {
        "special": wal_data["special"],
        "colors": wal_data["colors"],
        "semantic": semantic,
    }

    json_str = json.dumps(result, indent=4)

    if output_path:
        Path(output_path).write_text(json_str)
        print(f"Palette saved to {output_path}")
    else:
        print(json_str)


if __name__ == "__main__":
    main()
