"""Original 16-unit pixel symbols supplement NeoDunggeunmo without OS fallback."""
from pathlib import Path
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
ROOT=Path(__file__).resolve().parents[1]
PROJECT=next(p.parent for p in ROOT.glob('*/project.godot'))
PATTERNS={
 '→':[".....#...","......#..","#######..","......#..",".....#..."],
 '←':["..#......",".#.......","#######..",".#.......","..#......"],
 '↔':["..#...#..",".#.....#.","#########",".#.....#.","..#...#.."],
 '−':["........",".######.","........"],
 '›':[".#...","..#..","...#.","..#..",".#..."],
 '‹':["...#.","..#..",".#...","..#..","...#."],
 '⌁':[".##.....","#..#....","....#..#",".....##."],
 '↑':["...#...","..###..",".#.#.#.","...#...","...#...","...#..."],
 '↓':["...#...","...#...","...#...",".#.#.#.","..###..","...#..."],
 '…':["#.#.#"],
}
def build():
 fb=FontBuilder(16,isTTF=True)
 names=['.notdef']+['uni%04X'%ord(c) for c in PATTERNS]
 fb.setupGlyphOrder(names)
 glyphs={};metrics={}
 for c,rows in [('',[])]+list(PATTERNS.items()):
  name='uni%04X'%ord(c) if c else '.notdef'
  pen=TTGlyphPen(None)
  width=max(map(len,rows),default=6)
  top=8 if c not in ['−','…'] else 5 if c=='−' else 2
  for y,row in enumerate(rows):
   for x,pixel in enumerate(row):
    if pixel!='#':continue
    px=x+1;py=top-y
    pen.moveTo((px,py));pen.lineTo((px,py+1));pen.lineTo((px+1,py+1));pen.lineTo((px+1,py));pen.closePath()
  glyphs[name]=pen.glyph();metrics[name]=(width+2,1)
 fb.setupCharacterMap({ord(c):'uni%04X'%ord(c) for c in PATTERNS})
 fb.setupGlyf(glyphs);fb.setupHorizontalMetrics(metrics)
 fb.setupHorizontalHeader(ascent=12,descent=-4)
 fb.setupOS2(sTypoAscender=12,sTypoDescender=-4,usWinAscent=12,usWinDescent=4)
 fb.setupNameTable({'familyName':'ORVASK Pixel Symbols','styleName':'Regular','uniqueFontIdentifier':'ORVASKPixelSymbols-1','fullName':'ORVASK Pixel Symbols','psName':'ORVASKPixelSymbols','version':'Version 1.0'})
 fb.setupPost();fb.setupMaxp()
 fb.save(PROJECT/'assets/fonts/ORVASKPixelSymbols.ttf')
if __name__=='__main__':build()
