# Strict Reference Parity

Read this file when the user asks for an exact, strict, identical, pixel-close, or design-faithful Godot implementation.

## Design Lock

- Preserve the exact selected image under a stable filename. Candidate letters and phrases such as "the first one" are conversation shorthand, not durable identifiers.
- Show or inspect the locked file once more before implementation when several candidates appeared in the same conversation.
- Record reference width, height, aspect ratio, Godot base viewport, and runtime capture size.
- Treat later user corrections as a new design lock. Remove artifacts belonging only to the rejected variant.

## Design Contract

Create a compact table before editing:

| Region | Reference bbox | Normalized bbox | Target rect | Visual owner | Dynamic content |
| --- | --- | --- | --- | --- | --- |

Use `normalized_x = x / reference_width` and `normalized_y = y / reference_height`, then map those values to the Godot base viewport. Record at least:

- Outer screen margins and header/footer baselines.
- Major panel, illustration, list, modal, and action-area bounds.
- Column widths, gaps, dividers, and dominant alignment axes.
- Button silhouette, visible bbox, label bounds, and hit target.
- Gradient direction, important opacity stops, and overlay strength.

Do not estimate from memory when pixels can be measured.

## Visual Ownership Rules

- Distinctive art-directed controls require matching art. Examples: ticket buttons, clipped-corner plates, irregular paper, textured metal, seals, ornamental frames, and asymmetrical silhouettes.
- `StyleBoxFlat`, `ColorRect`, `GradientTexture2D`, and simple SVG paths are valid for plain geometry that visibly exists in the design: hairlines, rectangular washes, simple fades, and truly flat shapes.
- A custom-looking button cannot be reduced to a generic rounded or rectangular button merely because it is clickable.
- Keep labels, counts, dates, stats, and localized strings dynamic even when their surrounding surface is an image.
- Match the visual surface and hit target separately. A transparent real `Button` may sit over a dedicated normal/hover/pressed texture stack.
- Preserve directional effects. A left-to-right transparency fade is not equivalent to one uniform translucent rectangle.

## Comparison Loop

1. Capture the actual runtime screen, not an editor mockup.
2. Match the reference aspect ratio. If dimensions differ, resample only for comparison; do not confuse that with runtime resolution testing.
3. Run `scripts/reference_parity_audit.py`.
4. Inspect side-by-side at fit-to-screen size for composition and density.
5. Inspect the 50% overlay for edge drift, alignment, region size, and baseline mismatch.
6. Inspect the difference view to locate forgotten rules, corners, textures, and opacity fields.
7. Compare cropped high-detail regions for buttons, typography, and icons.
8. Fix the largest structural mismatch, capture again, and repeat.

Use this inspection order:

1. Correct approved variant.
2. Global composition and outer margins.
3. Major region bounds and negative-space balance.
4. Distinctive silhouettes and bespoke assets.
5. Transparency, material, texture, and line weight.
6. Typography hierarchy and text bounds.
7. Hover, pressed, selected, disabled, focus, dismissal, and motion.

## Common Failure Modes

- Implementing a previously discussed candidate instead of the image the user just identified.
- Approximating a bespoke orange ticket or diagonal edge with a stock Godot rectangle.
- Matching content but not density, leaving one side empty and the other crowded.
- Reusing the correct colors while losing transparency direction, material texture, or edge treatment.
- Treating a full-screen design screenshot as one flattened runtime texture, thereby baking dynamic data.
- Capturing only one polished final frame and missing hover, pressed, modal outside-click, or reveal-state bugs.
- Comparing screenshots with different aspect ratios and mistaking scaling artifacts for layout quality.
- Declaring success after headless parsing without producing a real renderer screenshot.

## Acceptance Language

Do not say "strictly reproduced" unless the comparison artifact was inspected and no material mismatch remains. If technical constraints or dynamic data cause a difference, name it precisely. Prefer:

`The macro layout, distinctive silhouettes, opacity field, typography bounds, and interaction states match the locked reference. Remaining deviation: ...`

Never hide a known visible difference behind "close enough," "basically the same," or "the flavor is right."
