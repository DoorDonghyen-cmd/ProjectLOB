"""Draw the pixel nine-slice frames for the HTML prototype's line theme.

Each frame is a tiny RGBA image: a 1-pixel outline with stepped (staircase) corner cuts at
the top-left and bottom-right, an optional dithered fill, raised-button highlight/shadow rows,
a selected-state left bar and bright corner glints. CSS scales them 2x with
image-rendering: pixelated, so one art pixel is 2 CSS pixels.
Output: docs/qa/reports/ui_prototype_2026-10-31/assets/px_<name>.png
"""
from pathlib import Path
from PIL import Image

OUT = Path(__file__).resolve().parents[1] / "docs/qa/reports/ui_prototype_2026-10-31/assets"


def rgba(value, alpha=255):
    if isinstance(value, tuple):
        return value
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


# name: size, cut, line, fill, dither-alt, top highlight, bottom shadow (rows), left bar, corner glint
BIG, SMALL = (16, 3), (12, 2)
FRAMES = {
    "panel":    (BIG, "#24646b", rgba("#04181e", 236), rgba("#06212a", 236), None, None, None, "#5cdddc"),
    "standby":  (BIG, "#1f5359", rgba("#051e24", 214), rgba("#082730", 214), None, None, None, None),
    "active":   (BIG, "#5cdddc", rgba("#0d3a40", 232), rgba("#11464c", 232), None, None, "#5cdddc", "#e4fffd"),
    "danger":   (BIG, "#ff6f61", rgba("#2a0e0b", 232), rgba("#331310", 232), None, None, "#ff6f61", "#ffd0c8"),
    "slate":    (BIG, "#2b5c62", rgba("#08242a", 236), None, "#3a7379", ("#03131a", 1), None, None),
    "cool":     (BIG, "#5cdddc", rgba("#0a3238", 236), None, "#2f8f93", ("#03131a", 1), None, None),
    "reload":   (BIG, "#c9a45a", rgba("#2a2214", 236), None, "#6f5a30", ("#120d05", 1), None, None),
    "fire":     (BIG, "#ffb08a", rgba("#ff7a45"), None, "#ffc3a3", ("#b8461f", 2), None, "#fff1e8"),
    "disabled": (BIG, "#173b40", rgba("#04161b", 170), None, None, None, None, None),
    "heat":     (SMALL, "#24646b", rgba("#02100f"), None, None, None, None, None),
    "chip":     (SMALL, "#1d4f56", rgba("#020e12", 140), None, None, None, None, None),
    "chip_on":  (SMALL, "#5cdddc", rgba("#0d3a40", 230), None, None, None, None, "#e4fffd"),
    "tag":      (SMALL, "#2c7a80", rgba("#020e12", 176), None, None, None, None, None),
    "tag_named": (SMALL, "#c9a45a", rgba("#020e12", 190), None, None, None, None, "#f3cf73"),
    "tag_reach": (SMALL, "#ff6f61", rgba("#1a0806", 200), None, None, None, None, "#ffd0c8"),
}


def draw(size, cut, line, fill, alt, hi, lo, bar, glint):
    s = size
    inside = lambda x, y: 0 <= x < s and 0 <= y < s and x + y >= cut and (s - 1 - x) + (s - 1 - y) >= cut
    edge = lambda x, y: inside(x, y) and any(not inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    px = img.load()
    for y in range(s):
        for x in range(s):
            if not inside(x, y):
                continue
            if edge(x, y):
                diagonal = x + y == cut or (s - 1 - x) + (s - 1 - y) == cut
                px[x, y] = rgba(glint) if glint and diagonal else rgba(line)
                continue
            color = alt if alt and (x + y) % 2 else fill
            if hi and edge(x, y - 1):
                color = rgba(hi)
            if lo:
                shade, rows = lo
                if any(edge(x, y + k) for k in range(1, rows + 1)):
                    color = rgba(shade)
            if bar and (edge(x - 1, y) or edge(x - 2, y)) and not edge(x, y - 1) and not edge(x, y + 1):
                color = rgba(bar)
            px[x, y] = color
    return img


def main():
    # --scale 2 --out <dir> writes nearest-upscaled copies for engines that draw nine-slices at
    # texture size (Godot StyleBoxTexture): then texture margins are 12 (big) / 8 (small).
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument("--scale", type=int, default=1)
    parser.add_argument("--out", type=Path, default=OUT)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    for name, ((size, cut), *rest) in FRAMES.items():
        img = draw(size, cut, *rest)
        if args.scale > 1:
            img = img.resize((img.width * args.scale, img.height * args.scale), Image.NEAREST)
        img.save(args.out / f"px_{name}.png")
    print("frames:", len(FRAMES), "scale:", args.scale, "->", args.out)


if __name__ == "__main__":
    main()
