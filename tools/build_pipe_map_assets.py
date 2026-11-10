"""Draw the pixel stencils for the HTML prototype's pipe-schematic map trial.

Place symbols are reduced from the adopted map icons (map_<kind>.png) to small one-colour pixel
silhouettes, so the page can tint them per state with CSS masks. Normal places use 18 px, elite 22,
the region gate 24 (16 for the thin bar on short screens), which also gives the map a size hierarchy. Home, valve and control-room marks
for the region rail are hand-drawn below. Every image is saved already scaled 2x (nearest), so the
page draws it at native size and one art pixel is 2x2 CSS px, like the line-theme frames.
Output: docs/qa/reports/ui_prototype_2026-10-31/assets/pm_<name>.png
"""
from pathlib import Path
from PIL import Image

ASSETS = Path(__file__).resolve().parents[1] / "docs/qa/reports/ui_prototype_2026-10-31/assets"
SIZES = {"combat": 18, "shop": 18, "workshop": 18, "supply": 18, "event": 18, "bypass": 18, "elite": 22, "boss": 24}
# Thin gate bar on short screens.
VARIANTS = {"boss_small": ("boss", 16)}
SCALE = 2

HAND = {
    "home": [
        "......##......",
        ".....####.....",
        "....######....",
        "...########...",
        "..##########..",
        ".############.",
        "##############",
        ".############.",
        ".##..####..##.",
        ".##..####..##.",
        ".#####..#####.",
        ".#####..#####.",
        ".#####..#####.",
    ],
    "valve": [
        "....#####....",
        "..##..#..##..",
        ".#....#....#.",
        ".#....#....#.",
        "#.....#.....#",
        "#...#####...#",
        "######.######",
        "#...#####...#",
        "#.....#.....#",
        ".#....#....#.",
        ".#....#....#.",
        "..##..#..##..",
        "....#####....",
    ],
    "control": [
        "......##......",
        "......##......",
        "..##########..",
        ".#..........#.",
        ".#.##.##.##.#.",
        ".#.##.##.##.#.",
        ".#..........#.",
        ".#.########.#.",
        ".#..........#.",
        ".############.",
        "..##......##..",
        "..##......##..",
    ],
}


def silhouette(kind, n, threshold=70):
    """Box-reduce the icon to n x n and keep bright, opaque cells (dark interior lines become holes)."""
    im = Image.open(ASSETS / f"map_{kind}.png").convert("RGBA")
    im = im.crop(im.getchannel("A").point(lambda a: 255 if a > 40 else 0).getbbox())
    side = max(im.size)
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    square.paste(im, ((side - im.width) // 2, (side - im.height) // 2))
    small = square.resize((n, n), Image.BOX)
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    src, dst = small.load(), out.load()
    for y in range(n):
        for x in range(n):
            r, g, b, a = src[x, y]
            if a > 110 and (0.3 * r + 0.59 * g + 0.11 * b) * (a / 255) > threshold:
                dst[x, y] = (255, 255, 255, 255)
    return out


def from_rows(rows):
    out = Image.new("RGBA", (len(rows[0]), len(rows)), (0, 0, 0, 0))
    px = out.load()
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch == "#":
                px[x, y] = (255, 255, 255, 255)
    return out


def main():
    images = {kind: silhouette(kind, n) for kind, n in SIZES.items()}
    images.update({name: silhouette(kind, n) for name, (kind, n) in VARIANTS.items()})
    images.update({name: from_rows(rows) for name, rows in HAND.items()})
    for name, img in images.items():
        img.resize((img.width * SCALE, img.height * SCALE), Image.NEAREST).save(ASSETS / f"pm_{name}.png")
    print("pipe map stencils:", len(images), "->", ASSETS)


if __name__ == "__main__":
    main()
