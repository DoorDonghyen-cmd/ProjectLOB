# Shop preview UI skins

Hand-authored vector pixel geometry, created by `tools/build_shop_preview_scene.py` on 2026-10-25 for the isolated shop prototype. No third-party asset extraction or raster generation. Each SVG is paired with an 8-pixel-margin StyleBoxTexture resource.

Palette: charcoal effect plates `#192629`, slate metal `#273638`, ivory labels, muted brass purchase action `#bba479`. Sparse material seams and selection corners replace nested generic boxes. Dynamic text remains in Godot controls. This palette is a review proposal, not a new global art rule.

Use: `res://redesign/samples/shop_wireframe_preview.tscn`. Production shop assets are unchanged. Runtime visual evidence and validation: `docs/history/design/shop-wireframe-preview-2026-10-25.md` in the repository root. Latest checks: three viewport ratios, purchase and details flows, 889 checks, zero failures. Physical-device readability and user aesthetic approval remain pending.
