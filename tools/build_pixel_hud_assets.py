"""Native LibreSprite exports for the approved combat pixel study.

Python writes metadata/scripts only. The pixel editor writes every bitmap.
"""
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'art_source/ui/combat_pixel_study_20261101'
OUT=ROOT/'새-게임-프로젝트/assets/ui/combat_pixel_20261101'
QA=ROOT/'qa_runtime/pixel_hud_20261101'
OUT.mkdir(parents=True,exist_ok=True);QA.mkdir(parents=True,exist_ok=True)
palette={k:v['rgb'] for k,v in json.loads((SOURCE/'palette.json').read_text(encoding='utf-8')).items()}
shutil.copy2(SOURCE/'fonts/OFL.md',OUT/'OFL.md')
shutil.copy2(SOURCE/'palette.json',OUT/'palette.json')

def render(name,script,input_path=None):
    path=QA/(name+'.js');path.write_text(script,encoding='utf-8')
    p=subprocess.run([sys.executable,str(ROOT/'tools/pixel_editor.py'),'-b',str(input_path or ROOT/'docs/art/combat-pixel-study-20261101/partial_native.png'),'--script',str(path)],capture_output=True)
    log=p.stdout.decode('utf-8',errors='replace')+p.stderr.decode('utf-8',errors='replace')
    (QA/(name+'.log')).write_text(log,encoding='utf-8')
    if p.returncode or 'EXPORT COMPLETE' not in log:raise RuntimeError(log)

for name,native,baseline in [('Galmuri11',12,11),('Galmuri9',10,9)]:
    glyphs=[];rows=[];pages=[[]];page_heights=[];cx=1;cy=1;row_height=0
    for block in (SOURCE/'fonts'/(name+'.bdf')).read_text(encoding='utf-8').split('STARTCHAR ')[1:]:
        code=int(re.search(r'^ENCODING (-?\d+)',block,re.M)[1])
        if code<0:continue
        advance=int(re.search(r'^DWIDTH (\d+)',block,re.M)[1])
        w,h,x,y=map(int,re.search(r'^BBX ([\d -]+)',block,re.M)[1].split())
        bitmap=block.split('BITMAP\n',1)[1].split('ENDCHAR',1)[0].strip().splitlines()
        if cx+w+1>1024:cx=1;cy+=row_height;row_height=0
        if cy+h+1>2048:
            page_heights.append(2048);pages.append([]);cx=1;cy=1;row_height=0
        gx,gy=cx,cy;page=len(pages)-1;cx+=max(1,w)+2;row_height=max(row_height,h+2)
        glyph=dict(x=gx,y=gy,w=w,h=h,bits=((w+7)//8)*8,rows=[int(b,16) for b in bitmap if b])
        glyphs.append(glyph);pages[page].append(glyph)
        rows.append(f'char id={code} x={gx} y={gy} width={w} height={h} xoffset={x} yoffset={baseline-y-h} xadvance={advance} page={page} chnl=15')
    page_heights.append(2048)
    page_names=[name+('' if i==0 else '_'+str(i))+'.png' for i in range(len(pages))]
    fnt=f'info face="{name}" size={native} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0\ncommon lineHeight={native+2} base={baseline} scaleW=1024 scaleH=2048 pages={len(pages)} packed=0\n'+''.join(f'page id={i} file="{filename}"\n' for i,filename in enumerate(page_names))+f'chars count={len(glyphs)}\n'+'\n'.join(rows)+'\n'
    (OUT/(name+'.fnt')).write_text(fnt+'kernings count=0\n',encoding='utf-8')
    for index,page_glyphs in enumerate(pages):
        page_path=OUT/page_names[index]
        script='var G='+json.dumps(page_glyphs)+';\n'+f'var s=app.activeSprite;var im=s.layer(0).cel(0).image;im.clear(0);var white=app.pixelColor.rgba(255,255,255,255);\n'+'''for(var i=0;i<G.length;i++){var g=G[i];for(var y=0;y<g.rows.length;y++)for(var x=0;x<g.w;x++)if(g.rows[y]&(1<<(g.bits-1-x)))im.putPixel(g.x+x,g.y+y,white);}\n'''+f's.saveAs({json.dumps(page_path.as_posix())},true);console.log("EXPORT COMPLETE");'
        # Reopen the enlarged canvas so the cel covers every glyph coordinate.
        seed=f'var s=app.activeSprite;s.resize(1024,2048);s.saveAs({json.dumps(page_path.as_posix())},true);console.log("EXPORT COMPLETE");'
        render(name+str(index)+'_canvas',seed)
        render(name+str(index),script,page_path)
    # Godot bitmap importer permits integer scaling; small=20, large=24.
    if not (OUT/(name+'.fnt.import')).exists():
        (OUT/(name+'.fnt.import')).write_text('[remap]\nimporter="font_data_bmfont"\ntype="FontFile"\n\n[deps]\n\n[params]\nscaling_mode=2\nfallbacks=[]\n',encoding='utf-8')
    print(name,len(glyphs),'glyphs in',len(pages),'pages (max 1024x2048)')

script='var P='+json.dumps(palette)+';var OUT='+json.dumps(OUT.as_posix())+';\n'+'''
var s=app.activeSprite;var im;var C={};for(var k in P)C[k]=app.pixelColor.rgba(P[k][0],P[k][1],P[k][2],255);
function start(w,h){s.resize(w,h);s.commit();im=s.layer(0).cel(0).image;im.clear(0);}
function r(x,y,w,h,c){for(var yy=y;yy<y+h;yy++)for(var xx=x;xx<x+w;xx++)im.putPixel(xx,yy,c);}
function plate(fill,edge){r(1,0,30,32,fill);r(0,1,32,30,fill);r(2,0,28,1,edge);r(1,1,1,30,edge);r(30,1,1,30,edge);r(2,31,28,1,C.shadow);}
function save(name){s.saveAs(OUT+'/'+name+'.png',true);}
var specs=[['active','panelRaised','amber'],['standby','panel','edge'],['removed','panel','rust'],['empty','socket','rim'],['fire','fire','edge'],['cool','panelRaised','edge'],['reload','panelRaised','edge'],['remove','panelRaised','amber'],['disabled','panel','rim'],['modal','panel','edge']];
for(var i=0;i<specs.length;i++){var a=specs[i];start(32,32);plate(C[a[1]],C[a[2]]);if(['fire','cool','reload','remove'].indexOf(a[0])>=0){r(4,1,24,1,C[a[0]=='cool'?'blueLight':a[0]=='reload'?'brass':'amber']);r(4,29,24,1,C.shadow);}save(a[0]);}
var kinds=['basic','pierce','precise','charge','cool','arc','push','bore','shatter','detonate','chase','bypass','thermal','vent','spread','charge_heat','charge_hot','sequence','prepare','disrupt'];
for(var i=0;i<kinds.length;i++){
 var k=kinds[i];start(14,22);
 if(k=='cool'||k=='vent'){r(3,7,8,12,C.shadow);r(4,6,6,12,C.blue);r(5,7,2,9,C.blueLight);r(3,17,8,3,C.brass);r(5,4,4,3,C.warmLight);if(k=='vent')r(2,10,10,2,C.blueLight);}
 else if(k.indexOf('charge')==0){r(4,1,6,19,C.shadow);r(5,2,4,17,C.brass);var band=k=='charge'?C.blue:k=='charge_heat'?C.rust:C.amber;r(3,4,8,3,band);r(3,12,8,3,band);r(5,18,4,2,C.warmLight);}
 else{r(4,6,6,14,C.shadow);r(5,7,4,12,C.brass);r(5,1,3,7,C.rust);r(6,0,1,3,C.warmLight);r(5,9,1,8,C.warmLight);r(3,19,8,2,C.brass);r(4,18,6,1,C.warmLight);
  if(k=='pierce'||k=='bore'){r(5,1,3,9,C.edge);r(6,0,1,11,C.blueLight);if(k=='bore')r(4,5,6,2,C.rust);}
  if(k=='precise'||k=='chase'){r(3,8,8,3,C.edge);r(4,9,6,1,C.blueLight);if(k=='chase')r(7,12,4,3,C.amber);}
  if(k=='arc'||k=='disrupt'){r(3,7,8,3,C.blue);r(3,13,8,3,C.blueLight);if(k=='disrupt')r(7,5,3,12,C.edge);}
  if(k=='push'||k=='spread'){r(3,4,8,4,C.rust);r(3,10,8,2,C.brassMuted);if(k=='spread')r(6,4,2,12,C.shadow);}
  if(k=='shatter'||k=='detonate'){r(3,7,8,10,C.rust);r(5,8,2,8,C.amber);if(k=='shatter'){r(2,9,2,5,C.edge);r(10,9,2,5,C.edge);}}
  if(k=='bypass')r(7,3,2,16,C.blue);
  if(k=='thermal'){r(3,7,8,10,C.fire);r(4,8,6,2,C.amber);r(4,13,6,2,C.rust);}
  if(k=='sequence'||k=='prepare'){r(3,9,8,2,C.blueLight);r(3,14,8,2,C.blueLight);if(k=='prepare')r(6,7,2,11,C.edge);}
 }save('ammo_'+k);
}
console.log('EXPORT COMPLETE');
'''
render('frames',script)
print('Native frame/font assets exported.')
