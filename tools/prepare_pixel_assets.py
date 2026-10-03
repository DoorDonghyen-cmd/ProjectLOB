"""Normalize PixelLab's canvases without resampling or recoloring their pixels."""
import hashlib
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
ART = ROOT / "새-게임-프로젝트/assets/art/pixel_20261003"

def main():
    report = []
    for source in sorted((ART / "source").glob("*.png")):
        with Image.open(source) as original:
            rgba = original.convert("RGBA")
        background = source.stem == "foundry"
        bbox = (0, 0, *rgba.size) if background else rgba.getchannel("A").getbbox()
        if bbox is None:
            raise ValueError(f"Empty image: {source.name}")
        normalized = rgba.crop(bbox)
        feet = normalized.getchannel("A").crop((0, max(0, normalized.height - 4), normalized.width, normalized.height)).getbbox()
        foot_x = round((feet[0] + feet[2]) / 2) if feet and source.stem in {"reclaimer", "runner", "wall", "evader"} else normalized.width // 2
        target = ART / source.name
        normalized.save(target)
        colors = len(normalized.getcolors(normalized.width * normalized.height))
        alpha = sorted(value for count, value in normalized.getchannel("A").getcolors())
        if not background and 0 not in alpha:
            raise ValueError(f"Sprite has no transparent background: {source.name}")
        report.append({"asset": source.stem, "source_size": rgba.size,
                       "source_bounds": bbox, "size": normalized.size,
                       "anchor": [foot_x, normalized.height], "scale": 2, "colors": colors,
                       "alpha_values": alpha, "sha256": hashlib.sha256(target.read_bytes()).hexdigest()})
    (ART / "asset_report.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
    anchors = ",\n".join(f'"{entry["asset"]}": Vector2({entry["anchor"][0]}, {entry["anchor"][1]})' for entry in report)
    (ART / "sprite_anchors.tres").write_text('[gd_resource type="Resource" format=3]\n\n[resource]\nmetadata/anchors = {\n' + anchors + '\n}\n', encoding="utf-8")
    print(f"Prepared {len(report)} pixel assets; exact alpha, palette and anchors: {ART / 'asset_report.json'}")

if __name__ == "__main__":
    main()
