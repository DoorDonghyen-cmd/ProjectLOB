extends RefCounted
## Shared line + dot surfaces. No commands, input, scene layout or persistent state.
const FONT=preload("res://redesign/combat_pixel_font.tres")
const INK=Color("e4f2ee")
const MUTED=Color("8fb0b0")
const DIM=Color("56777a")
const ACCENT=Color("5cdddc")
const GOLD=Color("f3cf73")
const DANGER=Color("ff6f61")
const ROOT="res://assets/ui/line_theme_20261101/"
static var cache: Dictionary={}
static func texture(kind: String)->Texture2D:
 var key: String="px_"+kind+".png"
 if not cache.has(key):cache[key]=load(ROOT+key)
 return cache[key]
static func box(kind: String="panel",state: String="normal")->StyleBoxTexture:
 return surface(kind,state).duplicate() as StyleBoxTexture
static func surface(kind: String="panel",state: String="normal")->StyleBoxTexture:
 var face: String="disabled" if state=="disabled" else "active" if state in ["selected","hover_pressed"] else kind
 var key: String=face+("_hover" if state=="hover" else "")+".tres"
 if not cache.has(key):cache[key]=load(ROOT+key)
 return cache[key]
static func font_step(value: int)->int:
 return 12 if value<14 else 16 if value<22 else 24 if value<28 else 32
