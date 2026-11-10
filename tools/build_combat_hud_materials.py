"""Author crisp, nine-sliced metal UI frames. No runtime drawing or raster edits."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '새-게임-프로젝트/assets/ui/combat_hardware'
OUT.mkdir(parents=True, exist_ok=True)


def rect(x, y, w, h, color):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" fill="{color}"/>'


def path(points, color):
    return f'<path d="{points}" fill="{color}"/>'


def svg(name, body, width=64, height=64):
    target = OUT / (name + '.svg')
    target.write_text(f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" shape-rendering="crispEdges">\n' + '\n'.join(body) + '\n</svg>\n', encoding='utf-8')


def style(name, margins=(12, 12, 12, 12), content=(12, 8, 12, 8)):
    lines = ['[gd_resource type="StyleBoxTexture" load_steps=2 format=3]', '', f'[ext_resource type="Texture2D" path="res://assets/ui/combat_hardware/{name}.svg" id="texture"]', '', '[resource]', 'texture = ExtResource("texture")']
    for side, margin, inset in zip(['left', 'top', 'right', 'bottom'], margins, content):
        lines += [f'texture_margin_{side} = {float(margin)}', f'content_margin_{side} = {float(inset)}']
    (OUT / (name + '.tres')).write_text('\n'.join(lines) + '\n', encoding='utf-8')


def key(name, face, light, shadow, pressed=False):
    # Fixed pixel steps and restrained wear live only in the unscaled corners.
    body = [path('M8 0H56V4H60V8H64V56H60V60H56V64H8V60H4V56H0V8H4V4H8Z', '#101c22'),
            path('M8 4H56V8H60V54H56V60H8V56H4V8H8Z', shadow),
            path('M10 6H54V10H58V52H54V56H10V52H6V10H10Z', face),
            rect(10, 6 if not pressed else 10, 44, 2, light), rect(6, 10, 2, 40, light),
            rect(56, 12, 2, 40, shadow), rect(10, 54, 44, 2, shadow),
            rect(12, 58, 40, 2, '#17252b'), rect(12, 6, 4, 2, face),
            rect(48, 54, 4, 2, light)]
    svg(name, body); style(name)


key('key', '#354a50', '#6c817c', '#203037')
key('key_hover', '#41585b', '#a6b6a0', '#263a3f')
key('key_pressed', '#263a40', '#536c68', '#13232b', True)
key('key_disabled', '#233339', '#40534f', '#17272e')
key('fire', '#bd9c69', '#dfc394', '#785d40')
key('fire_hover', '#cdb080', '#ead4a9', '#886948')
key('fire_pressed', '#9f8058', '#bd9c69', '#624d39', True)
key('remove', '#ae7756', '#e1ad7e', '#664838')
key('remove_hover', '#c48e66', '#ebbf90', '#78503b')
key('remove_pressed', '#916146', '#c7956a', '#503a30', True)


def card(name, face, rim, label, shadow='#15252b'):
    body = [path('M6 0H90V3H93V6H96V158H93V161H90V164H6V161H3V158H0V6H3V3H6Z', '#101d23'),
            rect(3, 6, 90, 152, rim), rect(6, 3, 84, 158, rim),
            rect(6, 7, 84, 150, face), rect(7, 8, 82, 30, label),
            rect(8, 38, 80, 2, shadow), rect(8, 40, 80, 2, face),
            rect(8, 132, 80, 2, shadow), rect(8, 134, 80, 22, label),
            rect(6, 7, 84, 2, rim), rect(6, 158, 84, 3, shadow),
            rect(88, 10, 2, 146, shadow), rect(10, 3, 4, 2, face),
            rect(82, 159, 4, 2, rim)]
    svg(name, body, 96, 164); style(name, (12, 42, 12, 32), (0, 0, 0, 0))


card('cartridge', '#26383f', '#4b6061', '#30454a')
card('cartridge_live', '#3a4c49', '#bba679', '#4b594f')
card('cartridge_removed', '#473931', '#c88c62', '#5a4236')
card('cartridge_empty', '#192b33', '#33494e', '#20323a')


def housing(name, content=(8, 4, 8, 4), modal=False):
    body = [path('M6 0H58V3H61V6H64V58H61V61H58V64H6V61H3V58H0V6H3V3H6Z', '#101c22'),
            rect(3, 6, 58, 52, '#273b42'), rect(6, 3, 52, 58, '#273b42'),
            rect(6, 6, 52, 50, '#203239' if not modal else '#21323a'),
            rect(8, 3, 48, 2, '#647773'), rect(4, 8, 2, 46, '#364b50'),
            rect(58, 8, 2, 46, '#13232a'), rect(8, 58, 48, 3, '#14242b'),
            rect(9, 3, 6, 2, '#354a4f'), rect(49, 59, 5, 2, '#485b58')]
    svg(name, body); style(name, content=content)


housing('housing')
housing('tray', (8, 6, 8, 6))
housing('modal', (12, 8, 12, 8), True)
svg('recess', [rect(0, 0, 32, 32, '#16272e'), rect(2, 2, 28, 26, '#1b2e34'), rect(2, 28, 28, 2, '#43574f'), rect(0, 0, 32, 2, '#0f2027')], 32, 32)
style('recess', (4, 4, 4, 4), (0, 0, 0, 0))
svg('focus', [rect(x, y, w, h, '#e1cea3') for x, y, w, h in [(0, 6, 2, 6), (6, 0, 6, 2), (30, 6, 2, 6), (20, 0, 6, 2), (0, 20, 2, 6), (6, 30, 6, 2), (30, 20, 2, 6), (20, 30, 6, 2)]], 32, 32)
style('focus', (12, 12, 12, 12), (0, 0, 0, 0))
svg('heat_fill', [rect(0, 0, 12, 12, '#956347'), rect(2, 2, 8, 8, '#c29765'), rect(2, 2, 8, 2, '#ddba81')], 12, 12)
style('heat_fill', (4, 4, 4, 4), (0, 0, 0, 0))

# Small hardware symbols: dynamic action names and costs remain live Godot labels.
ink = '#b8c6b1'
svg('cool_icon', [rect(14, 3, 4, 26, ink), rect(3, 14, 26, 4, ink)] + [rect(x, y, 4, 4, ink) for x, y in [(6,6),(10,10),(22,6),(18,10),(6,22),(10,18),(22,22),(18,18)]], 32, 32)
svg('reload_icon', [path('M6 4H22V8H26V25H22V29H8V25H6Z', ink), rect(10, 8, 12, 15, '#263b42'), rect(13, 10, 3, 9, ink), rect(18, 10, 2, 9, ink), rect(10, 25, 12, 2, '#637e77')], 32, 32)
svg('fire_icon', [path('M2 10H22V6H26V10H30V16H22V20H15V27H8V17H2Z', '#3e362c'), rect(4, 11, 18, 2, '#705638'), rect(17, 17, 4, 3, '#bd9c69')], 32, 32)

mapping = {'button':'key','hover':'key_hover','pressed':'key_pressed','disabled':'key_disabled','focus':'focus',
           'primary':'fire','primary_hover':'fire_hover','primary_pressed':'fire_pressed',
           'remove':'remove','remove_hover':'remove_hover','remove_pressed':'remove_pressed',
           'ammo':'cartridge','ammo_active':'cartridge_live','ammo_removed':'cartridge_removed','ammo_empty':'cartridge_empty',
           'well':'recess','modal':'modal','housing':'housing','tray':'tray','heat':'heat_fill'}
lines = ['[gd_resource type="Theme" format=3]', '[ext_resource type="Font" path="res://redesign/combat_pixel_font.tres" id="font"]']
for alias, name in mapping.items():
    lines.append(f'[ext_resource type="StyleBox" path="res://assets/ui/combat_hardware/{name}.tres" id="{alias}"]')
lines += ['[sub_resource type="StyleBoxEmpty" id="clear"]', '[resource]', 'default_font = ExtResource("font")', 'default_font_size = 22']
for property_name, color in [('font_color','0.902,0.910,0.843'),('font_hover_color','0.969,0.941,0.847'),('font_pressed_color','0.969,0.941,0.847'),('font_disabled_color','0.510,0.596,0.569')]:
    lines.append(f'Button/colors/{property_name} = Color({color},1)')
lines.append('Label/colors/font_color = Color(0.902,0.910,0.843,1)')
for state, alias in [('normal','button'),('hover','hover'),('pressed','pressed'),('disabled','disabled'),('focus','focus')]:
    lines.append(f'Button/styles/{state} = ExtResource("{alias}")')
for alias in mapping: lines.append(f'Panel/styles/{alias} = ExtResource("{alias}")')
lines += ['Panel/styles/panel = ExtResource("ammo")', 'Panel/styles/clear = SubResource("clear")', 'ProgressBar/styles/background = ExtResource("well")', 'ProgressBar/styles/fill = ExtResource("heat")', 'ScrollContainer/styles/panel = SubResource("clear")']
(ROOT/'새-게임-프로젝트/redesign/samples/hud/combat_hud_theme.tres').write_text('\n\n'.join(lines)+'\n', encoding='utf-8')
manifest = {'purpose':'Battle HUD materials matched to the existing industrial pixel environment', 'decision':'User requested cohesion with background and actors; art judgement pending user review', 'tool':'Authored SVG rectangles/paths and Godot StyleBoxTexture nine-slice; no generated raster art', 'reference':['assets/art/tower_sample_20261003/residential_tower.png','assets/art/hero_contours_20261025/work_pistol.png','redesign/instrument_skin.gd','qa_runtime/combat_hud_20261031/cohesion/before/ready_single_1280x800.png'], 'rendering':'Nearest sampling; fixed corner pixels, stretch only in broad quiet surfaces; all text/numbers remain Godot controls', 'files':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.iterdir() if p.suffix in ['.svg','.tres']}}
(OUT/'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(f'Authored {len(manifest["files"])} material/icon resources')
