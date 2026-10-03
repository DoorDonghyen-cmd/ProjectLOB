# Godot UI Integration Skill

A Codex skill for turning approved UI designs and visual references into editor-visible Godot scenes, connected runtime behavior, and reviewable visual evidence.

It is designed for the part that usually gets lost between a mockup and a working game UI:

- preserving an approved composition instead of approximating it with generic panels;
- keeping formal screens visible and editable as `.tscn` scenes;
- separating static art from dynamic text and state;
- connecting navigation, data, focus, and persistent selection;
- validating runtime output against the reference rather than accepting a plausible screenshot.

## Included

- `SKILL.md` — routing, implementation invariants, workflow, and completion gate
- `references/strict-reference-parity.md` — the stricter contract for pixel-close work
- `scripts/alpha_audit.py` — transparency and visible-bounds inspection
- `scripts/contact_sheet.py` — deterministic candidate contact sheets
- `scripts/reference_parity_audit.py` — side-by-side, overlay, and difference comparison
- `scripts/stretch_audit.py` — static audit for distorted Godot texture controls
- `scripts/white_bg_to_alpha.py` — edge-connected white-background removal

## Install

Copy this repository into the Codex skills directory:

```text
~/.codex/skills/godot-ui-integration/
```

Install the helper dependency when using the image audit scripts:

```bash
python -m pip install -r requirements.txt
```

Then invoke it explicitly or let Codex select it for an end-to-end Godot UI integration request:

```text
Use $godot-ui-integration to implement this approved UI in Godot and verify runtime visual parity.
```

## Scope

This skill does not replace ordinary Godot documentation or a general-purpose UI tutorial. It provides the workflow and verification rules needed when visual intent, editor scene structure, gameplay binding, and runtime parity must survive the same implementation.

## License

MIT
