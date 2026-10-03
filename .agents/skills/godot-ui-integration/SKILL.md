---
name: godot-ui-integration
description: Build or revise Godot UI from an approved design, separated art, or a visual reference when scene structure, gameplay binding, and runtime visual verification all matter. Use for complete Godot UI integration; use ordinary Godot UI guidance for isolated node or layout questions that do not require an end-to-end visual workflow.
---

# Godot UI Integration

Turn an approved UI direction into editor-visible Godot scenes, connected behavior, and verified runtime output.

## Route the request

- If the user already approved a design or supplied the exact reference to implement, lock that reference and proceed.
- If the visual direction is new or materially changing, prepare one composed preview and obtain approval before producing final assets or editing scenes.
- If the user asks for exact, strict, pixel-close, or design-faithful reproduction, read [references/strict-reference-parity.md](references/strict-reference-parity.md) completely before editing.
- For read-only diagnosis, inspect and report without changing project files.

After the composed preview is approved, continue through asset preparation, scene construction, binding, and validation. Pause only when the approved composition must change, asset rights are unclear, validation remains blocked after targeted retries, or gameplay behavior would expand beyond the requested UI scope.

## Required project checks

Before editing:

1. Read the project instructions and canonical UI/navigation documentation.
2. Inspect the target viewport, existing scenes, themes, input patterns, data sources, and asset directories.
3. Use the Godot MCP first for engine inspection and edits. If it is unavailable, diagnose and attempt reconnection before using a local script, CLI, or UI fallback; report the failure and fallback.
4. Record the approved reference, its dimensions, the target screen or overlay, and the intended entry and exit paths.

## Implementation invariants

- Treat `.tscn` scenes as the visual source of truth. Every formal player-facing screen or major overlay must be directly openable with its representative composition visible before `_ready()` runs.
- Runtime code may populate data, localized text, textures, availability, selection, and transient feedback. It must not construct or relocate the primary layout procedurally.
- Give distinct formal screens distinct scenes; inherited scenes are acceptable. Serialize screen-specific hierarchy, visibility, anchors, offsets, styles, and representative state.
- Keep dynamic names, prices, counts, statistics, labels, lock states, and localized strings as Godot nodes or runtime data rather than baking them into raster art.
- Preserve the approved reference's silhouette, material, texture, edge treatment, proportions, and hierarchy. Use native Godot primitives only where the design itself is visually simple.
- Store final resources inside the Godot project. Do not leave scenes referencing temporary generation or working directories.
- Reuse project conventions unless doing so would contradict the approved design or the user's asset-source constraints.

## Workflow

1. **Survey:** identify the affected scenes, scripts, data, navigation, input, viewport, safe areas, fonts, and reusable components.
2. **Lock the design:** choose the exact approved reference and map major regions, dynamic fields, hit targets, ownership, and responsive behavior.
3. **Plan assets:** classify each visual as direct extraction, reference-guided generation, reconstruction, reusable project art, or native Godot styling. Confirm source rights before reuse.
4. **Prepare assets:** create one final file per asset, remove temporary backgrounds, preserve intended transparency, normalize display size, and avoid destructive whole-canvas stretching.
5. **Build scenes:** serialize the formal composition and reusable repeated components in `.tscn`; keep decorative children from intercepting input.
6. **Bind behavior:** connect data, navigation, disabled/empty/error states, persistent selection, controller/keyboard focus, and save boundaries without rebuilding the authored layout.
7. **Validate:** inspect the editor scene, run the UI at the target resolution, exercise interactions, check errors, compare against the reference, and update the project UI documentation.

## Validation helpers

The included Python tools require Pillow:

```bash
python -m pip install -r requirements.txt
```

- Inspect alpha and visible bounds:

  ```bash
  python scripts/alpha_audit.py path/to/asset.png
  ```

- Build a contact sheet for candidate review:

  ```bash
  python scripts/contact_sheet.py "path/to/candidates/*.png" --out path/to/contact-sheet.png
  ```

- Compare an approved reference with a runtime capture:

  ```bash
  python scripts/reference_parity_audit.py reference.png runtime.png --out path/to/parity.png
  ```

- Audit panel-like textures for deformation and invalid nine-slice margins:

  ```bash
  python scripts/stretch_audit.py --project-root path/to/project --scene res://path/to/screen.tscn
  ```

- Remove an edge-connected white background from an approved cutout:

  ```bash
  python scripts/white_bg_to_alpha.py --input source.png --out asset.png
  ```

Review generated outputs visually. Passing deterministic checks does not prove design fidelity.

## Completion gate

Do not report completion until:

- the formal scene is editor-visible before runtime binding;
- the runtime path reaches and exits the UI correctly;
- dynamic content and interaction states behave correctly;
- there are no new parse, import, or runtime errors caused by the change;
- strict-reference work includes a same-resolution comparison artifact and disclosed deviations;
- the canonical project UI documentation reflects the implemented behavior and validation evidence.

Report the changed scenes, scripts, assets, runtime captures, validation commands, MCP status, known deviations, and any deferred product decisions.
