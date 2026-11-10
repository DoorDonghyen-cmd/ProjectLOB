// Native LibreSprite 1.3 pixel authoring. DATA is prefixed by prepare.py.
// All new UI pixels are written on the native image grid; no vector rasterizer.
var sprite=app.activeSprite;
if(!sprite)throw new Error('Open a source screenshot before this script');
var image=sprite.layer(0).cel(0).image;
var W=image.width,H=image.height;
var pc=app.pixelColor;
var C={};
for(var key in DATA.palette){var rgb=DATA.palette[key];C[key]=pc.rgba(rgb[0],rgb[1],rgb[2],255);}
var P=DATA.state;
var metrics={width:W,height:H,labels:[],cards:[],heat_cells:[],overflows:[]};
function px(x,y,c){if(x>=0&&y>=0&&x<W&&y<H)image.putPixel(x,y,c);}
function rect(x,y,w,h,c){for(var yy=y;yy<y+h;yy++)for(var xx=x;xx<x+w;xx++)px(xx,yy,c);}
function box(x,y,w,h,c){rect(x,y,w,1,c);rect(x,y+h-1,w,1,c);rect(x,y,1,h,c);rect(x+w-1,y,1,h,c);}
function plate(x,y,w,h,fill,edge){rect(x+1,y,w-2,h,fill);rect(x,y+1,w,h-2,fill);rect(x+2,y,w-4,1,edge);rect(x+1,y+1,1,h-2,edge);rect(x+w-2,y+1,1,h-2,edge);rect(x+2,y+h-1,w-4,1,C.shadow);}
function textWidth(s,font){var n=0;for(var i=0;i<s.length;i++){var g=DATA.fonts[font][s.charCodeAt(i)];if(!g)throw new Error('Missing glyph '+s.charCodeAt(i));n+=g.advance;}return n;}
function text(s,x,y,c,font,maxWidth){
 font=font||'small';var width=textWidth(s,font);var baseline=y+(font==='large'?11:9);
 metrics.labels.push({text:s,x:x,y:y,width:width,font:font});
 if(maxWidth!==undefined&&width>maxWidth)metrics.overflows.push({text:s,width:width,available:maxWidth});
 for(var i=0;i<s.length;i++){
  var g=DATA.fonts[font][s.charCodeAt(i)];
  for(var row=0;row<g.rows.length;row++)for(var col=0;col<g.w;col++)if(g.rows[row]&(1<<(g.bits-1-col)))px(x+g.x+col,baseline-g.y-g.h+row,c);
  x+=g.advance;
 }
 return width;
}
function centered(s,x,y,w,c,font){font=font||'small';text(s,x+Math.floor((w-textWidth(s,font))/2),y,c,font,w-8);}
function bullet(x,y,kind,quiet){
 var metal=quiet?C.brassMuted:C.brass,lit=quiet?C.rim:C.warmLight;
 if(kind.indexOf('cool')>=0){
  rect(x+1,y+5,8,12,C.shadow);rect(x+2,y+4,6,12,C.blue);rect(x+3,y+5,2,9,C.blueLight);rect(x+1,y+15,8,3,metal);rect(x+3,y+2,4,3,lit);
 }else if(kind==='charge'){
  rect(x+1,y+1,6,19,C.shadow);rect(x+2,y+2,4,17,metal);rect(x,y+4,8,3,C.blue);rect(x,y+12,8,3,C.blue);rect(x+2,y+18,4,2,lit);
 }else{
  rect(x+2,y+6,6,14,C.shadow);rect(x+3,y+7,4,12,metal);rect(x+3,y+1,3,7,C.rust);rect(x+4,y,1,3,C.warmLight);rect(x+3,y+9,1,8,lit);rect(x+1,y+19,8,2,metal);rect(x+2,y+18,6,1,lit);
 }
}
function button(x,y,w,h,kind,item){
 var muted=item.disabled;var fire=kind==='fire';var remove=kind==='remove';
 var fill=muted?C.panel:fire?C.fire:C.panelRaised;
 var accent=muted?C.rim:fire||remove?C.amber:kind==='cool'?C.blueLight:C.brass;
 plate(x,y,w,h,fill,muted?C.rim:C.edge);
 rect(x+4,y+1,w-8,1,accent);rect(x+4,y+h-3,w-8,1,C.shadow);
 centered(item.name,x,y+5,w,muted?C.muted:C.text,'large');
 centered(item.cost,x,y+21,w,muted?C.muted:kind==='fire'&&P.danger?C.warning:C.secondary,'small');
}

// Source battlefield pixels (y=44..233) remain the captured scene at half size.
rect(0,0,W,44,C.page);
text(DATA.title,12,15,C.text,'large',270);
text(P.weapon,367,16,C.secondary,'small',60);
text(P.bag,430,16,C.secondary,'small',70);
text(P.parts,503,16,C.secondary,'small',95);
text('메뉴',604,16,C.secondary,'small',30);

// A narrow steel seam and short reflected lamp strips connect to the platform.
var top=236;
rect(0,top,W,H-top,C.page);
rect(12,top,W-24,1,C.edge);rect(12,top+1,W-24,2,C.shadow);
rect(12,top+3,W-24,1,C.panelRaised);
rect(34,top,30,1,C.brassMuted);rect(64,top,13,1,C.rim);
rect(12,top+4,W-24,H-top-12,C.panel);
rect(12,top+4,2,H-top-12,C.shadow);rect(W-14,top+4,2,H-top-12,C.shadow);

var heading=P.eject_mode?'선택 '+P.selected.length+' / '+P.ejection_remaining:'탄창 '+P.rounds.length+' / '+P.capacity;
text(heading,20,258,C.text,'large',190);
text('발열 '+P.heat+' / '+P.limit,244,248,C.secondary,'small',160);
if(P.danger)text('과열',482,248,C.warning,'small',55);
var gx=244,gy=264,gw=288,gh=9;
var peak=Math.min(P.limit,Math.max(P.heat,P.forecast.peak_max||P.heat));
for(var i=0;i<P.limit;i++){
 var x=gx+Math.floor(i*gw/P.limit),end=gx+Math.floor((i+1)*gw/P.limit)-2,w=end-x;
 rect(x,gy,w,gh,C.shadow);
 if(i<P.heat){rect(x+1,gy+1,w-2,gh-2,C.brass);rect(x+1,gy+1,w-2,1,C.warmLight);}
 else if(i<peak){box(x,gy,w,gh,P.danger?C.rust:C.edge);for(var d=2;d<w-2;d+=4)rect(x+d,gy+4,2,1,P.danger?C.warning:C.brassMuted);}
 else{rect(x,gy,w,1,C.rim);rect(x,gy+gh-1,w,1,C.rim);}
 metrics.heat_cells.push({x:x,y:gy,w:w,current:i<P.heat,predicted:i>=P.heat&&i<peak});
}
plate(550,247,70,28,C.panelRaised,C.edge);
centered(P.eject_mode?'취소':'빼내기',550,252,70,C.secondary,'small');
if(!P.eject_mode)centered(String(P.ejection_remaining),550,264,70,C.brass,'small');

// Fixed capacity sockets. Empty sockets remain visible after firing/ejection.
var rowX=20,rowY=285,total=600,gap=4,step=(total+gap)/P.capacity;
var ordinal=0;
for(var i=0;i<P.capacity;i++){
 var x=rowX+Math.floor(i*step),right=rowX+Math.floor((i+1)*step)-gap,w=right-x;
 var round=i<P.rounds.length?P.rounds[i]:null;
 var chosen=round&&round.removed,active=round&&round.active&&!chosen;
 var y=rowY-(chosen?3:0),h=64;
 plate(x,rowY,w,64,C.socket,C.rim);
 if(round){
  plate(x+2,y+2,w-4,h-4,active?C.panelRaised:C.panel,chosen?C.rust:active?C.amber:C.edge);
  if(active){ordinal++;text(String(ordinal),x+5,y+6,C.amber,'small');}
  text(round.name,x+(active?17:7),y+7,chosen?C.warning:active?C.text:C.secondary,'small',w-(active?23:14));
  bullet(x+10,y+29,round.id,!active||chosen);
  if(chosen){text('제외',x+27,y+32,C.warning,'small',w-32);rect(x+6,y+55,w-12,1,C.rust);}
  else if(active){text(round.value,x+28,y+27,C.text,'large',w-33);text(round.role,x+28,y+45,C.secondary,'small',w-33);}
  else{rect(x+27,y+49,w-34,1,C.rim);}
 }else{
  rect(x+5,rowY+5,w-10,1,C.shadow);rect(x+5,rowY+57,w-10,2,C.edge);
  rect(x+Math.floor(w/2)-1,rowY+24,2,16,C.rim);
 }
 metrics.cards.push({index:i,x:x,y:y,w:w,h:h,occupied:!!round,selected:!!chosen,active:!!active});
}

button(232,357,104,35,'cool',P.buttons.Cool);
button(344,357,120,35,'reload',P.buttons.Reload);
button(472,357,148,35,P.eject_mode?'remove':'fire',P.buttons[P.eject_mode?'EjectApply':'Fire']);
// Quiet bottom rail; no extra damage sentence or repeated cosmetic modules.
rect(20,384,193,1,C.rim);rect(20,385,193,1,C.shadow);
rect(20,389,60,1,C.edge);rect(20,390,60,1,C.shadow);

if(metrics.overflows.length)throw new Error(JSON.stringify(metrics.overflows));
sprite.saveAs(DATA.output+'.ase',true);
sprite.saveAs(DATA.output+'_native.png',true);
console.log('PIXEL STUDY '+DATA.key+' '+JSON.stringify(metrics));
