"""Author original grid-aligned UI resources. No external image extraction.

32px masters, 10px protected corners, flat rect-only SVG + Godot nine-slice.
Run from any directory; regenerates only this dedicated asset family.
"""
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '새-게임-프로젝트/assets/ui/console'
OUT.mkdir(parents=True, exist_ok=True)
PALETTES = {
    'card': ('9eaa9e', 'c5cbbb', '536762'),
    'cartridge': ('344a4e', '7f9290', '203238'),
    'well': ('14252c', '53686b', '0b171e'),
    'button': ('35494e', '758886', '17272e'),
    'primary': ('b3c4aa', 'd7dfc6', '647e70'),
    'reload': ('3b5863', '94b5bc', '213640'),
    'danger': ('62443c', 'd79b7a', '35282a'),
    'panel': ('24373c', '607473', '101f26'),
    'tray': ('1a2c33', '526b6c', '101e26'),
}
STATES = ('normal', 'hover', 'focus', 'selected', 'pressed', 'disabled')

def make(kind, state):
    face, light, depth = PALETTES[kind]
    if state == 'disabled':
        face, light, depth = ('677873', '7f8e84', '394f50') if kind == 'card' else ('293c42', '485e61', '1b2c33')
    pressed = state == 'pressed'
    shapes = []
    def rect(x, y, w, h, color):
        shapes.append(f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="#{color}"/>')
    # Family silhouettes: shallow label corners, deep key shoulders, square housing.
    key = kind in ('button', 'primary', 'reload', 'danger')
    if key:
        rect(6, 0, 20, 32, '0e1d24')
        rect(2, 2, 28, 28, '0e1d24')
        rect(0, 6, 32, 20, '0e1d24')
    else:
        rect(2, 0, 28, 32, '0e1d24')
        rect(0, 2, 32, 28, '0e1d24')
    if kind == 'well':
        rect(2, 2, 28, 28, light)
        rect(2, 2, 28, 4, depth)
        rect(2, 6, 3, 22, depth)
        rect(5, 6, 25, 22, face)
        rect(7, 8, 21, 18, face)
        # Slot lips sit on the outside, leaving the interior empty.
        rect(6, 29, 20, 1, '76857b')
    elif kind in ('panel', 'tray'):
        rect(2, 2, 28, 27, face)
        rect(4, 2, 24, 2, light)
        rect(2, 4, 2, 23, depth)
        rect(4, 28, 24, 2, depth)
        rect(28, 4, 2, 23, depth)
    elif key:
        # A full face sits above a four-pixel plinth; pressing sinks it into the rim.
        rect(6, 2, 20, 28, depth)
        rect(4, 4, 24, 24, depth)
        rect(2, 6, 28, 20, depth)
        top = 4 if pressed else 2
        rect(6, top, 20, 26-top, face)
        rect(4, top+2, 24, 22-top, face)
        rect(2, top+4, 28, 18-top, face)
        rect(6, top, 20, 2, depth if pressed else light)
        rect(4, top+2, 2, 2, depth if pressed else light)
        rect(2, top+4, 2, 16-top, depth if pressed else light)
        rect(26, top+2, 2, 2, light if pressed else depth)
        rect(28, top+4, 2, 16-top, light if pressed else depth)
        rect(6, 24, 20, 2, light if pressed else depth)
        if not pressed:
            rect(6, 28, 20, 2, depth)
            # Two restrained reflected clusters, confined to the protected corner.
            if state != 'disabled':
                rect(6, 4, 2, 2, light)
                rect(4, 22, 2, 2, light)
        else:
            rect(6, 26, 20, 2, face)
    else:
        top = 4 if pressed else 2
        rect(2, top, 28, 28-top, face)
        rect(4, top, 24, 2, depth if pressed else light)
        rect(2, top+2, 2, 24-top, light if not pressed else depth)
        rect(28, top+2, 2, 24-top, depth)
        rect(4, 26, 24, 2, depth)
        rect(4, 28, 24, 2, depth if not pressed else face)
        if kind == 'card':
            # Offset corner join: a label plate rather than another push button.
            rect(28, 0, 4, 4, '0e1d24')
            rect(26, 2, 2, 2, light)
            rect(28, 4, 2, 3, light)
            rect(2, 24, 2, 4, depth)
            rect(4, 28, 5, 2, light)
        elif kind == 'cartridge':
            # Broad seating lugs stay at the corners when stretched.
            rect(4, 26, 4, 3, light)
            rect(24, 26, 4, 3, light)
    # Godot draws focus OVER normal/pressed; never cover the depressed key face.
    if state == 'focus':
        shapes.clear()
    if state in ('hover', 'focus', 'selected'):
        accent = '9abdc8' if kind == 'reload' else ('e39b79' if kind == 'danger' else 'c6dec7')
        for x in (0, 30):
            rect(x, 2, 2, 7, accent)
            rect(x, 23, 2, 7, accent)
        for y in (0, 30):
            rect(2, y, 7, 2, accent)
            rect(23, y, 7, 2, accent)
    return '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32" viewBox="0 0 32 32" shape-rendering="crispEdges">\n' + '\n'.join(shapes) + '\n</svg>\n'

for kind in PALETTES:
    for state in STATES:
        stem = f'{kind}_{state}'
        (OUT / f'{stem}.svg').write_text(make(kind, state), encoding='utf-8')
        resource = f'''[gd_resource type="StyleBoxTexture" load_steps=2 format=3]

[ext_resource type="Texture2D" path="res://assets/ui/console/{stem}.svg" id="1"]

[resource]
texture = ExtResource("1")
'''
        for side in ('left', 'top', 'right', 'bottom'):
            resource += f'texture_margin_{side} = 10.0\ncontent_margin_{side} = 0.0\n'
        (OUT / f'{stem}.tres').write_text(resource, encoding='utf-8')
(OUT / 'provenance.json').write_text(json.dumps({
    'authoring': 'Original rect-only pixel-grid construction; no third-party asset pixels reused.',
    'tool': 'tools/build_console_ui.py',
    'references': ['docs/art/style-reference/detail-ui-study.md', 'docs/art/style-reference/shop-card-ui-study.md', 'docs/art/style-reference/craftpix-ui-study.md', 'docs/art/style-reference/pinterest-ui-study.md'],
    'master_size': [32,32], 'protected_margin': 10,
    'states': STATES, 'families': list(PALETTES),
    'status': 'Integrated director proposal; user visual review pending',
}, ensure_ascii=False, indent=2), encoding='utf-8')
print(f'Wrote {len(PALETTES)*len(STATES)} UI skins to {OUT}')
