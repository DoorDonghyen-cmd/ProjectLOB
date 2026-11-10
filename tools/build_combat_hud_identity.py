"""Author the HUD's flat industrial shapes, without bitmap post-processing.

The composition is the serialized combat_hud.tscn. This script only authors
reusable nine-sliced vector shapes and native Godot style resources.
"""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "새-게임-프로젝트/assets/ui/combat_identity"
OUT.mkdir(parents=True, exist_ok=True)


def rgba(value):
    return "Color(" + ",".join(f"{int(value[i:i+2],16)/255:.6f}" for i in (0, 2, 4)) + ",1)"


def flat(name, fill=None, border=None, edges=None, margin=(0, 0, 0, 0)):
    lines = ['[gd_resource type="StyleBoxFlat" format=3]', '[resource]']
    lines += ['bg_color = ' + rgba(fill)] if fill else ['draw_center = false']
    if border:
        lines.append('border_color = ' + rgba(border))
        for side, width in (edges or {}).items():
            lines.append(f'border_width_{side} = {width}')
    for side, amount in zip(('left', 'top', 'right', 'bottom'), margin):
        lines.append(f'content_margin_{side} = {float(amount)}')
    (OUT / (name + '.tres')).write_text('\n'.join(lines) + '\n', encoding='utf-8')


def plate(name, fill, edge, kind='trigger'):
    if kind == 'tag':
        body = 'M0 0H40V4H44V8H48V48H0Z'
        detail = f'<path d="M0 46H48V48H0Z" fill="#{edge}"/>'
    else:
        body = 'M0 0H48V40H44V44H40V48H0Z'
        detail = f'<path d="M0 42H44V44H40V48H0Z" fill="#{edge}"/>'
    svg = f'<svg xmlns="http://www.w3.org/2000/svg" width="48" height="48" viewBox="0 0 48 48" shape-rendering="crispEdges"><path d="{body}" fill="#{fill}"/>{detail}</svg>\n'
    (OUT / (name + '.svg')).write_text(svg, encoding='utf-8')
    lines = ['[gd_resource type="StyleBoxTexture" load_steps=2 format=3]',
             f'[ext_resource type="Texture2D" path="res://assets/ui/combat_identity/{name}.svg" id="texture"]',
             '[resource]', 'texture = ExtResource("texture")']
    for side in ('left', 'top', 'right', 'bottom'):
        lines += [f'texture_margin_{side} = 12.0', f'content_margin_{side} = 0.0']
    (OUT / (name + '.tres')).write_text('\n'.join(lines) + '\n', encoding='utf-8')


plate('primary', 'aa4933', '713b30')
plate('primary_hover', 'a34832', '88432f')
plate('primary_pressed', '8e3e2d', '693127')
plate('slot_active', 'd4c6a8', 'a3957b', 'tag')
flat('slot', None, '454137', {'bottom': 2})
flat('slot_empty', None, '33332d', {'bottom': 1})
flat('slot_removed', '472e28', 'd47556', {'left': 3, 'bottom': 2})
flat('carrier', '262722', '454137', {'bottom': 2})
flat('secondary', None, '777568', {'bottom': 2}, (12, 8, 12, 8))
flat('hover', '363830', 'c0b89f', {'bottom': 2}, (12, 8, 12, 8))
flat('pressed', '1c211f', 'c0b89f', {'top': 2}, (12, 8, 12, 8))
flat('disabled', '252a26', None, margin=(12, 8, 12, 8))
flat('cool', '24383d', '77a9b2', {'left': 3, 'bottom': 2}, (12, 8, 12, 8))
flat('cool_hover', '2d444b', '99c4cb', {'left': 3, 'bottom': 2}, (12, 8, 12, 8))
flat('cool_pressed', '1e3035', '77a9b2', {'left': 3, 'top': 2}, (12, 8, 12, 8))
flat('reload', '35372d', 'b8a775', {'top': 2, 'bottom': 2}, (12, 8, 12, 8))
flat('reload_hover', '414236', 'd6c79e', {'top': 2, 'bottom': 2}, (12, 8, 12, 8))
flat('reload_pressed', '272a23', 'b8a775', {'top': 2}, (12, 8, 12, 8))
plate('remove', '85563c', '5e4232')
plate('remove_hover', '8c593d', '6e4b37')
plate('remove_pressed', '794e37', '563b2d')
flat('track', '393c31')
flat('heat', 'dfa758')
flat('forecast', '756747')
flat('modal', '242b28', 'a49b83', {'top': 2, 'left': 1, 'right': 1, 'bottom': 2})
(OUT / 'clear.tres').write_text('[gd_resource type="StyleBoxEmpty" format=3]\n[resource]\n', encoding='utf-8')

# Two-tone focus stays visible on both the pale labels and the dark tray.
corners = []
for transform in ('', 'translate(32 0) scale(-1 1)', 'translate(0 32) scale(1 -1)', 'translate(32 32) scale(-1 -1)'):
    corners.append(f'<g transform="{transform}"><path d="M0 12V0H12V4H4V12Z" fill="#1b201b"/><path d="M1 11V1H11V3H3V11Z" fill="#f5edda"/></g>')
(OUT / 'focus.svg').write_text('<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32" shape-rendering="crispEdges">' + ''.join(corners) + '</svg>\n', encoding='utf-8')
focus = ['[gd_resource type="StyleBoxTexture" load_steps=2 format=3]', '[ext_resource type="Texture2D" path="res://assets/ui/combat_identity/focus.svg" id="texture"]', '[resource]', 'texture = ExtResource("texture")']
for side in ('left', 'top', 'right', 'bottom'):
    focus += [f'texture_margin_{side} = 12.0', f'content_margin_{side} = 0.0']
(OUT / 'focus.tres').write_text('\n'.join(focus) + '\n', encoding='utf-8')

manifest = {
    'date': '2026-10-31',
    'source': 'tools/build_combat_hud_identity.py',
    'direction': 'Warm charcoal utility tray, pale ammunition labels for imminent shots, oxide-red trigger, cool blue cooling control. Only functional areas receive color; no decorative copy, grain, bolts, baked text, or new raster assets.',
    'reference': 'docs/qa/reports/combat_focus_2026-10-31_assets/journey.png',
    'review_status': 'Implemented direction after user accepted cleanliness and rejected generic same-color panels; user taste confirmation remains separate.',
    'files': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.iterdir()) if p.suffix in ('.svg', '.tres')}
}
(OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(f'Authored {len(manifest["files"])} vector/style resources.')
