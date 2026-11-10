"""Pixel dash styleboxes; decoration only, keeping prior content margins."""
from pathlib import Path
from PIL import Image
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'새-게임-프로젝트/assets/ui/line_theme_20261101'
for side in ['top','bottom']:
    image=Image.new('RGBA',(8,8))
    for x in range(0,8,4):
        for dx in range(2):
            for dy in range(2):image.putpixel((x+dx,dy if side=='top' else 6+dy),(29,79,86,255))
    image.save(OUT/f'px_rule_{side}.png')
    text='[gd_resource type="StyleBoxTexture" format=3]\n[ext_resource type="Texture2D" path="res://assets/ui/line_theme_20261101/px_rule_'+side+'.png" id="tex"]\n[resource]\ntexture = ExtResource("tex")\naxis_stretch_horizontal = 1\naxis_stretch_vertical = 1\n'
    for edge in ['left','top','right','bottom']:
        text+=f'texture_margin_{edge} = '+('2.0' if edge==side else '0.0')+'\n'
        # Legacy shop bare surface reserved 8px all around; route rows used 12/0/12/0.
        text+=f'content_margin_{edge} = '+('8.0' if side=='top' else '12.0' if edge in ['left','right'] else '0.0')+'\n'
    (OUT/f'rule_{side}.tres').write_text(text,encoding='utf-8')
