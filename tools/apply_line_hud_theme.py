"""One-time appearance migration; preserves controls, hit areas and commands."""
from pathlib import Path
import re, json, shutil, hashlib
ROOT=Path(__file__).resolve().parents[1]
P=ROOT/'새-게임-프로젝트'
OUT=ROOT/'qa_runtime/line_theme_20261101/source_before'
OUT.mkdir(parents=True,exist_ok=True)
def backup(p):
    target=OUT/p.relative_to(ROOT)
    if not target.exists():
        target.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(p,target)
def write(p,s):
    if p.exists(): backup(p)
    p.parent.mkdir(parents=True,exist_ok=True);p.write_text(s,encoding='utf-8')
def prop(s,k,v):
    pattern=r'^'+re.escape(k)+r' = .*?$'
    return re.sub(pattern,k+' = '+v,s,flags=re.M) if re.search(pattern,s,re.M) else s.rstrip()+'\n'+k+' = '+v+'\n\n'
AS='res://assets/ui/line_theme_20261101/'
assets=P/'assets/ui/line_theme_20261101'
assets.mkdir(parents=True,exist_ok=True)
def box(name,kind,margin=(12,8,12,8),bright=1):
    m=8 if kind in ['heat','chip','chip_on','tag','tag_named','tag_reach'] else 12
    s='[gd_resource type="StyleBoxTexture" format=3]\n[ext_resource type="Texture2D" path="'+AS+'px_'+kind+'.png" id="tex"]\n[resource]\ntexture = ExtResource("tex")\n'
    for side,v in zip(['left','top','right','bottom'],margin):s+=f'content_margin_{side} = {float(v)}\n'
    for side in ['left','top','right','bottom']:s+=f'texture_margin_{side} = {m}.0\n'
    s+='axis_stretch_horizontal = 1\naxis_stretch_vertical = 1\n'
    if bright!=1:s+=f'modulate_color = Color({bright},{bright},{bright},1)\n'
    write(assets/(name+'.tres'),s)
def main():
    for kind in ['panel','standby','active','danger','slate','cool','reload','fire','disabled','heat','chip','chip_on','tag','tag_named','tag_reach']:
        box(kind,kind)
        box(kind+'_hover',kind,bright=1.25)
    # Keep legacy outer padding when these resources are used by existing production scenes.
    for folder in ['console','shop_preview']:
        for src in (P/'assets/ui'/folder).glob('*.tres'):
            s=src.read_text(encoding='utf-8')
            if 'StyleBox' not in s:continue
            stem=src.stem
            if stem=='bare':continue
            state=stem.rsplit('_',1)[-1]
            kind='panel' if any(x in stem for x in ['panel','invoice','shelf','well']) else 'standby' if any(x in stem for x in ['card','cartridge','offer']) else 'chip' if stem=='stat' else 'fire' if any(x in stem for x in ['primary','buy_']) else 'slate'
            if state in ['selected']:kind='active'
            if state=='disabled':kind='disabled'
            margin=[]
            for side in ['left','top','right','bottom']:
                found=re.search(r'^content_margin_'+side+r' = ([\d.-]+)',s,re.M)
                margin.append(float(found[1]) if found else 0)
            box(folder+'_'+stem,kind,margin,1.25 if state=='hover' else 1)
    hud=P/'redesign/samples/hud'
    for filename in ['combat_hud.tscn','combat_menu.tscn','combat_detail.tscn','journey_flow.tscn','journey_route.tscn']:
        path=hud/filename;s=path.read_text(encoding='utf-8')
        if 'id="line_frame"' in s:
            line='[ext_resource type="Script" path="res://redesign/line_frame.gd" id="line_frame"]'
            s=s.replace(line+'\n','');s=s.replace('[node ',line+'\n\n[node ',1)
            write(path,s)
            continue
        for old,new in [('modal','panel'),('standby','standby'),('cool','slate'),('fire','fire'),('reload','reload'),('heat','heat')]:
            s=s.replace('res://assets/ui/prototype_20261101/kit_'+old+'.png',AS+'px_'+new+'.png')
        split=s.index('[node ')
        head=s[:split]+'[ext_resource type="Script" path="res://redesign/line_frame.gd" id="line_frame"]\n'
        blocks=re.split(r'(?=\[node )',s[split:])
        for i,b in enumerate(blocks):
            if not b.strip():continue
            name=re.search(r'name="([^"]+)"',b)[1]
            if 'type="NinePatchRect"' in b.split('\n')[0]:
                kind='panel' if 'ExtResource("modal")' in b else 'heat' if 'ExtResource("heat")' in b else 'standby' if 'ExtResource("standby")' in b else 'slate'
                if name=='CoolArt':kind='cool'
                if name=='ReloadArt':kind='reload'
                if name in ['FireArt','JourneyConfirmFrame']:kind='fire'
                if name.startswith(('RewardPick','RouteStop')):kind='standby'
                for key,value in [('anchor_right','1.0'),('anchor_bottom','1.0'),('scale','Vector2(1,1)'),('axis_stretch_horizontal','1'),('axis_stretch_vertical','1')]:b=prop(b,key,value)
                for side in ['left','top','right','bottom']:b=prop(b,'patch_margin_'+side,'8' if kind=='heat' else '12')
                # Script changes only texture and tint on native Button redraw, never input/layout.
                if not name.startswith('RoundArt'):
                    b=prop(b,'script','ExtResource("line_frame")');b=prop(b,'kind','"'+kind+'"')
            if 'theme_override_font_sizes/font_size' in b:
                old=int(re.search(r'font_size = (\d+)',b)[1])
                sz=12 if any(name.startswith(x) for x in ['Cost','Index','RewardTag','RouteType','RouteState']) or name.endswith('Cost') or name in ['JourneyEyebrow'] else 24 if name.startswith('Value') or name in ['FireName','RewardDetailName'] or name.startswith('RewardName') else 32 if name in ['JourneyTitle','MenuTitle','DetailTitle'] else 16
                b=re.sub(r'font_size = \d+',f'font_size = {sz}',b)
                if sz>=24 or name in ['Title','RoutePlace']:
                    b=prop(b,'theme_override_colors/font_shadow_color','Color(0.00392,0.03137,0.03922,1)')
                    b=prop(b,'theme_override_constants/shadow_offset_x','0');b=prop(b,'theme_override_constants/shadow_offset_y','2')
            # Release decorative clamp padding inside the same button rectangle.
            if name in ['FireName','FireCost','CoolName','CoolCost','ReloadName','ReloadCost']:
                b=prop(b,'offset_left','12');b=prop(b,'offset_right','-12')
                if name=='FireName':b=prop(b,'offset_top','0');b=prop(b,'offset_bottom','28')
                if name=='FireCost':b=prop(b,'offset_top','28')
            if name=='Background':b=prop(b,'color','Color(0.01176,0.07843,0.10196,1)')
            if name in ['JourneyPanel','MenuLayer','Detail']:b=prop(b,'color','Color(0.00392,0.03922,0.05098,0.74)')
            if name=='Title':b=prop(b,'theme_override_colors/font_color','Color(0.36078,0.86667,0.86275,1)')
            if name.startswith('Cost') or name in ['HeatLabel']:b=prop(b,'theme_override_colors/font_color','Color(1,0.60392,0.41569,1)')
            blocks[i]=b
        write(path,head+''.join(blocks))
    # Preserve simulation/save/entry files and original node geometry for the audit.
    for file in ['model.gd','campaign.gd','magazine_journey.gd','forecast.gd','samples/combat_magazine_journey.gd','samples/combat_weapon_magazine.gd','samples/hud/combat_journey_hud.gd']:
        backup(P/'redesign'/file)
    backup(P/'project.godot')
    print('Line frame resources and authored HUD appearances prepared')

if __name__=="__main__":main()
