"""Authored pixel stencils for LoB's supply schematic. No sampled/thresholded source art.

Primitive coordinates are the editable 1x pixel originals; export is exact nearest 2x.
Reference role/shape: approved survey symbols, line UI and the integrated pipe map.
Only map art is exported. Theme surfaces elsewhere are deliberately not regenerated.
"""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw, ImageFont, ImageOps, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / '새-게임-프로젝트/assets/ui/pipe_map_art_20261101'
SOURCE = ROOT / 'art_source/ui/pipe_map_20261101'
WHITE = (255, 255, 255, 255)
CLEAR = (0, 0, 0, 0)
images = {}


def canvas(n):
    im = Image.new('RGBA', (n, n), CLEAR)
    return im, ImageDraw.Draw(im)


def keep(name, im):
    images[name] = im


def crossed_guns():
    # Stock, receiver, box magazine and barrel give firearms a different silhouette
    # from crossed blades. One clear pixel at the crossing separates the two guns.
    im, d = canvas(18)
    d.line([(15,2),(10,7)],fill=WHITE,width=2)
    d.polygon([(10,5),(12,7),(7,12),(5,10)],fill=WHITE)
    d.polygon([(5,10),(7,12),(3,16),(1,14)],fill=WHITE)
    d.polygon([(8,10),(10,12),(9,13),(7,11)],fill=WHITE)
    d.polygon([(10,8),(13,10),(12,12),(9,9)],fill=WHITE)
    back=ImageOps.mirror(im)
    back.paste(CLEAR,(0,0,18,18),im.getchannel('A').filter(ImageFilter.MaxFilter(3)))
    back.alpha_composite(im)
    return back


def armored_guns(n):
    im,d=canvas(n)
    # Empty armor plate stays behind the shared combat mark, with an air gap.
    d.line([(4,0),(n-5,0),(n-1,4),(n-1,n-8),(n-5,n-3),
            (n//2,n-1),(4,n-3),(0,n-8),(0,4),(4,0)],fill=WHITE,width=1)
    guns=crossed_guns()
    if n==22: im.alpha_composite(guns,(2,1))
    else:
        # Separate 18px legend drawing: compact barrels and stock, no resampling.
        small,sd=canvas(18)
        sd.line([(13,3),(9,7)],fill=WHITE,width=2)
        sd.polygon([(9,6),(11,8),(7,12),(5,10)],fill=WHITE)
        sd.polygon([(5,10),(7,12),(5,14),(3,12)],fill=WHITE)
        sd.polygon([(9,9),(11,11),(10,12),(8,10)],fill=WHITE)
        back=ImageOps.mirror(small)
        back.paste(CLEAR,(0,0,18,18),small.getchannel('A').filter(ImageFilter.MaxFilter(3)))
        back.alpha_composite(small)
        im.alpha_composite(back)
    return im


def symbols():
    keep('combat', crossed_guns())

    keep('elite', armored_guns(22))
    keep('elite_detail', armored_guns(18))

    # A trading balance, open jaw spanner, ammunition case and radio mast.
    im, d = canvas(18)
    d.rectangle((8,1,9,14), fill=WHITE); d.rectangle((3,4,14,5), fill=WHITE)
    d.rectangle((5,15,12,16), fill=WHITE)
    for x in [3,13]:
        d.line([(x,5),(x-3,10),(x+3,10),(x,5)], fill=WHITE, width=1)
        d.polygon([(x-3,11),(x+3,11),(x+2,13),(x-2,13)], fill=WHITE)
    keep('shop', im)
    im, d = canvas(18)
    d.polygon([(11,0),(14,0),(11,3),(11,6),(14,6),(17,3),(17,7),(14,10),(11,10),(5,16),(2,17),(0,15),(1,12),(8,5),(8,3)], fill=WHITE)
    d.rectangle((2,13,3,14), fill=CLEAR)
    keep('workshop', im)
    im, d = canvas(18)
    d.rectangle((1,5,16,15), fill=WHITE)
    d.rectangle((6,1,11,4), fill=WHITE); d.rectangle((8,2,9,4), fill=CLEAR)
    d.rectangle((2,8,15,8), fill=CLEAR)
    d.rectangle((8,7,9,10), fill=WHITE)
    d.rectangle((4,11,5,13), fill=CLEAR); d.rectangle((12,11,13,13), fill=CLEAR)
    keep('supply', im)
    im, d = canvas(18)
    d.rectangle((8,4,9,13), fill=WHITE); d.rectangle((7,3,10,6), fill=WHITE)
    d.rectangle((5,14,12,15), fill=WHITE); d.rectangle((3,16,14,17), fill=WHITE)
    for points in [[(3,2),(1,4),(1,8),(3,10)],[(5,4),(4,5),(4,7),(5,8)],[(14,2),(16,4),(16,8),(14,10)],[(12,4),(13,5),(13,7),(12,8)]]:
        d.line(points, fill=WHITE, width=1)
    keep('event', im)
    im, d = canvas(18)
    d.line([(2,16),(2,7),(5,4),(12,4),(12,2)], fill=WHITE, width=3)
    d.polygon([(9,3),(12,0),(15,3)], fill=WHITE)
    d.line([(6,16),(6,10),(9,7),(16,7)], fill=WHITE, width=2)
    keep('bypass', im)


def gate(n, state):
    im, d = canvas(n)
    a, b = 2, n-3
    d.line([(a,n-2),(a,4),(5,1),(n-6,1),(b,4),(b,n-2)], fill=WHITE, width=2)
    d.rectangle((0,n-2,4,n-1), fill=WHITE); d.rectangle((n-5,n-2,n-1,n-1), fill=WHITE)
    if state == 'open':
        d.rectangle((4,4,5,n-4), fill=WHITE); d.rectangle((n-6,4,n-5,n-4), fill=WHITE)
        d.line([(n//2,n-3),(n//2,7)], fill=WHITE, width=2)
        d.polygon([(n//2-3,9),(n//2,6),(n//2+2,9)], fill=WHITE)
    else:
        for x in range(5,n-4,3):d.line([(x,5),(x,n-4)], fill=WHITE, width=1)
        if state == 'closed':d.rectangle((4,n//2,n-5,n//2+1), fill=WHITE)
        else:
            d.rectangle((4,n//2,6,n//2+1), fill=WHITE)
            d.rectangle((n-7,n//2,n-5,n//2+1), fill=WHITE)
    return im


GLYPHS = {
    'residential': ['..###..','.#####.','#######','.##.##.','.#####.','.##.##.','.#####.'],
    'foundry': ['...#...','..##...','..###..','.#.###.','##..###','##..###','.#####.'],
    'garden': ['....###','..#####','.###.##','.##.##.','.#.##..','..##...','.#.....'],
    'noble': ['.#####.','##...##','##...##','##...##','##...##','##...##','###.###'],
    'central': ['.#.#.#.','.#####.','##...##','.##.##.','##...##','.#####.','.#.#.#.'],
}


def regions():
    # One 28px slot. Broad region mark inside a supply coupling, flow changes its shape.
    for name, rows in GLYPHS.items():
        for state in ['closed','current','open']:
            im, d = canvas(14)
            d.line([(2,0),(11,0),(13,2),(13,10),(11,12)], fill=WHITE, width=1)
            d.line([(2,0),(0,2),(0,10),(2,12)], fill=WHITE, width=1)
            for y,row in enumerate(rows):
                for x,v in enumerate(row):
                    if v=='#':d.point((x+3,y+3), fill=WHITE)
            if state=='closed':d.rectangle((3,12,10,13), fill=WHITE)
            elif state=='current':
                d.line([(3,12),(5,12),(6,11),(7,11),(8,12),(10,12)], fill=WHITE)
                d.rectangle((6,0,7,1), fill=CLEAR)
            else:
                d.rectangle((2,12,3,13), fill=WHITE);d.rectangle((10,12,11,13), fill=WHITE)
                d.rectangle((6,11,7,13), fill=WHITE)
                d.rectangle((6,0,7,1), fill=CLEAR)
            keep('region_'+name+'_'+state,im)
    for state in ['closed','open']:
        im,d=canvas(14)
        d.line([(4,1),(9,1),(12,4),(12,9),(9,12),(4,12),(1,9),(1,4),(4,1)],fill=WHITE)
        d.rectangle((5,5,8,8),fill=WHITE)
        if state=='closed':d.rectangle((0,6,13,7),fill=WHITE)
        else:d.rectangle((6,0,7,13),fill=WHITE)
        keep('valve_'+state,im)


def panel():
    im,d=canvas(16)
    d.polygon([(3,0),(15,0),(15,12),(12,15),(0,15),(0,3)],fill='#04181e',outline='#24646b')
    d.line([(0,3),(3,0)],fill='#5cdddc');d.line([(12,15),(15,12)],fill='#5cdddc')
    keep('board',im)


def main():
    OUT.mkdir(parents=True,exist_ok=True);SOURCE.mkdir(parents=True,exist_ok=True)
    symbols(); regions(); panel()
    for state in ['closed','ready']:
        keep('gate_'+state,gate(16,state))
    keep('gate_detail_closed',gate(18,'closed'))
    records=[]
    for name,im in images.items():
        im.save(SOURCE/(name+'_1x.png'))
        path=OUT/(name+'.png');im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST).save(path)
        records.append({'name':name,'native_size':list(im.size),'export_size':[im.width*2,im.height*2],'sha256':hashlib.sha256(path.read_bytes()).hexdigest()})
    style='''[gd_resource type="StyleBoxTexture" format=3]
[ext_resource type="Texture2D" path="res://assets/ui/pipe_map_art_20261101/board.png" id="tex"]
[resource]
texture = ExtResource("tex")
content_margin_left = 12.0
content_margin_top = 8.0
content_margin_right = 12.0
content_margin_bottom = 8.0
texture_margin_left = 12.0
texture_margin_top = 12.0
texture_margin_right = 12.0
texture_margin_bottom = 12.0
axis_stretch_horizontal = 1
axis_stretch_vertical = 1
'''
    (OUT/'board.tres').write_text(style,encoding='utf-8')
    provenance={'method':'Hand-authored pixel geometry; Python/Pillow lossless nearest export. No generative model or image thresholding.','source':'tools/build_pipe_map_art.py','references':['docs/qa/reports/pipe_map_godot_2026-11-01_assets/region_1_1280x800.png','새-게임-프로젝트/assets/art/map_chart_20261009/survey_symbols.png','새-게임-프로젝트/assets/art/map_chart_20261009/survey_symbols_guard.png','docs/art/references/2026-11-01-user/sanabi_difficulty_list.png'],'status':'Implementation; human visual preference pending','assets':records}
    provenance['combat_direction']='2026-11-01 user-approved direction: ordinary combat uses crossed firearms; elite shares the same weapons with a backing armor plate. Ordinary 36px, elite 44px, separately authored elite detail 36px. The gate remains a shutter. Existing slots, input and route rules unchanged; rendered preference pending.'
    (OUT/'provenance.json').write_text(json.dumps(provenance,ensure_ascii=False,indent=2),encoding='utf-8')
    # Evidence contact sheet, original exported scale plus a nearest zoom.
    sheet=Image.new('RGB',(840,((len(images)+5)//6)*116),'#03141a');d=ImageDraw.Draw(sheet)
    font=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',10)
    for i,(name,im) in enumerate(images.items()):
        x,y=(i%6)*140,(i//6)*116
        large=im.resize((im.width*3,im.height*3),Image.Resampling.NEAREST)
        sheet.paste(large,(x+8,y+12),large)
        small=im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST)
        sheet.paste(small,(x+86,y+20),small)
        d.text((x+4,y+86),name.replace('region_',''),font=font,fill='#a4c9c8')
    sheet.save(SOURCE/'contact_sheet.png')
    print('Exported',len(images),'map art assets.')


if __name__=='__main__':main()
