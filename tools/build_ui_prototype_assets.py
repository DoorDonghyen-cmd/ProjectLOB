"""Cut web assets for the HTML UI prototype from the unmodified game sources.

Regions and feet are copied from the registering game scripts:
  redesign/slum_art.gd, redesign/map_chart_symbols.gd, redesign/ammo_art.gd,
  assets/art/combat_feedkit_20261031/provenance.json
Run after tests/ui_prototype_export_runner.gd (which writes game_data.json and
combat_bg.png into the same folder). Source images are never modified.
"""
import json
import shutil
from pathlib import Path
from PIL import Image

REPO = Path(__file__).resolve().parents[1]
GAME = REPO / "새-게임-프로젝트"
ART = GAME / "assets" / "art"
OUT = REPO / "docs" / "qa" / "reports" / "ui_prototype_2026-10-31" / "assets"

# species: (sheet, frame-0 box, feet, game scale)
ENEMIES = {
    "slum_thief": ("slum_20261021/thief_states.png", (0, 180, 512, 980), (317, 924), 0.135),
    "slum_plate": ("slum_20261021/plate_states.png", (0, 200, 512, 970), (332, 924), 0.15),
    "slum_battery": ("slum_20261021/battery_states.png", (0, 220, 460, 960), (275, 902), 0.14),
    "slum_gunner": ("slum_20261021/gunner_states.png", (0, 240, 460, 940), (340, 877), 0.15),
    "slum_leader": ("slum_20261021/leader_states.png", (0, 220, 500, 970), (280, 924), 0.15),
}
MAP_ROLES = ["combat", "elite", "boss", "shop", "workshop", "supply", "event", "bypass"]
MAP_BOUNDS = [(72, 80, 310, 320), (510, 35, 310, 385), (950, 24, 320, 390), (1360, 70, 390, 337),
              (59, 475, 338, 337), (490, 524, 352, 277), (945, 478, 330, 338), (1410, 480, 310, 330)]
MAP_ELITE = (488, 88, 356, 316)
ROUNDS = {
    "basic": (201, 80, 99, 185), "pierce": (462, 55, 96, 210), "precise": (698, 79, 141, 186),
    "charge": (963, 46, 112, 219), "cool": (1201, 95, 166, 171), "arc": (179, 315, 144, 177),
    "push": (452, 314, 125, 177), "bore": (709, 287, 118, 204), "shatter": (976, 300, 109, 192),
    "detonate": (1224, 314, 120, 177), "chase": (185, 519, 129, 203), "bypass": (457, 519, 145, 206),
    "thermal": (693, 536, 150, 186), "vent": (945, 536, 161, 186), "spread": (1206, 530, 160, 192),
    "charge_heat": (179, 751, 160, 212), "charge_hot": (459, 749, 115, 211), "sequence": (718, 757, 111, 203),
    "prepare": (952, 759, 176, 204), "disrupt": (1215, 769, 141, 192),
}
BACKGROUNDS = {
    "shop.png": "service_background_grouped_20261025/shop.png",
    "supply.png": "service_background_grouped_20261025/supply.png",
    "workshop.png": "service_background_grouped_20261025/workshop.png",
    "encounter.png": "director_20261002/transit_platform.png",
}


def rect_box(x, y, w, h):
    return (x, y, x + w, y + h)


def trimmed(image):
    # Ignore the faint generation haze (alpha <= 8) when finding the body.
    box = image.getchannel("A").point(lambda value: 255 if value > 8 else 0).getbbox()
    return image.crop(box), box


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    manifest = {"enemies": {}, "rounds": [], "map": [], "kit": {}}
    for species, (sheet, box, feet, scale) in ENEMIES.items():
        frame = Image.open(ART / sheet).convert("RGBA").crop(box)
        sprite, (left, top, _, _) = trimmed(frame)
        sprite.save(OUT / f"enemy_{species}.png", optimize=True)
        manifest["enemies"][species] = {
            "w": sprite.width, "h": sprite.height, "scale": scale,
            "foot": [feet[0] - box[0] - left, feet[1] - box[1] - top],
        }
    sheet = Image.open(ART / "ammo_quiet_20261031" / "rounds.png").convert("RGBA")
    for source, region in ROUNDS.items():
        sheet.crop(rect_box(*region)).save(OUT / f"round_{source}.png", optimize=True)
        manifest["rounds"].append(source)
    atlas = Image.open(ART / "map_chart_20261009" / "survey_symbols.png").convert("RGBA")
    for role, region in zip(MAP_ROLES, MAP_BOUNDS):
        if role == "elite":
            continue
        trimmed(atlas.crop(rect_box(*region)))[0].save(OUT / f"map_{role}.png", optimize=True)
        manifest["map"].append(role)
    guard = Image.open(ART / "map_chart_20261009" / "survey_symbols_guard.png").convert("RGBA")
    trimmed(guard.crop(rect_box(*MAP_ELITE)))[0].save(OUT / "map_elite.png", optimize=True)
    manifest["map"].append("elite")
    kit_dir = ART / "combat_feedkit_20261031"
    regions = json.loads((kit_dir / "provenance.json").read_text(encoding="utf-8"))["regions"]
    kit = Image.open(kit_dir / "kit.png").convert("RGBA")
    for name, region in regions.items():
        piece = kit.crop(rect_box(*region))
        piece.save(OUT / f"kit_{name}.png", optimize=True)
        manifest["kit"][name] = [piece.width, piece.height]
    for name, source in BACKGROUNDS.items():
        image = Image.open(ART / source).convert("RGB")
        image = image.resize((image.width // 2, image.height // 2), Image.NEAREST)
        image.save(OUT / name, optimize=True)
    shutil.copyfile(GAME / "assets" / "fonts" / "NeoDunggeunmoPro-Regular.ttf", OUT / "NeoDunggeunmoPro-Regular.ttf")
    # Part icons are drawn in code; the export runner renders them on magenta.
    game_data = json.loads((OUT / "game_data.json").read_text(encoding="utf-8"))
    part_sheet = OUT / "part_sheet.png"
    if part_sheet.exists():
        sheet_image = Image.open(part_sheet).convert("RGBA")
        manifest["parts"] = []
        for part_id, (cx, cy) in game_data.get("part_icons", {}).items():
            cell = sheet_image.crop((int(cx) - 46, int(cy) - 40, int(cx) + 46, int(cy) + 40))
            cell.putdata([(0, 0, 0, 0) if (r > 240 and g < 20 and b > 240) else (r, g, b, a) for r, g, b, a in cell.getdata()])
            icon, _ = trimmed(cell)
            icon.save(OUT / f"part_{part_id}.png", optimize=True)
            manifest["parts"].append(part_id)
        part_sheet.unlink()
    (OUT / "asset_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    # file:// pages cannot fetch JSON, so ship the data as a script as well.
    game = json.loads((OUT / "game_data.json").read_text(encoding="utf-8"))
    (OUT / "game_data.js").write_text(
        "window.GAME_DATA = " + json.dumps(game, ensure_ascii=False) + ";\n"
        + "window.ASSET_MANIFEST = " + json.dumps(manifest, ensure_ascii=False) + ";\n",
        encoding="utf-8")
    print("assets:", len(list(OUT.iterdir())))


if __name__ == "__main__":
    main()
