extends RefCounted
## Shared industrial cartridge family. Originals are preserved; atlas UVs select only the authored sprites.
const Content = preload("res://redesign/content.gd")
const Visual = preload("res://redesign/ammo_visual.gd")
const Sheet = preload("res://assets/art/ammo_quiet_20261031/rounds.png")
const SpecialSheet = preload("res://assets/art/ammo_quiet_20261031/rounds.png")
const SpecialRegions := {
	"push": Rect2(452,314,125,177),
	"bore": Rect2(709,287,118,204),
	"shatter": Rect2(976,300,109,192),
	"detonate": Rect2(1224,314,120,177),
	"chase": Rect2(185,519,129,203),
	"bypass": Rect2(457,519,145,206),
	"thermal": Rect2(693,536,150,186),
	"vent": Rect2(945,536,161,186),
	"spread": Rect2(1206,530,160,192),
	"charge_heat": Rect2(179,751,160,212),
	"charge_hot": Rect2(459,749,115,211),
	"sequence": Rect2(718,757,111,203)
}
const LegacySheet = preload("res://assets/art/ammo_quiet_20261031/rounds.png")
const LegacyRegions := {
	"prepare": Rect2(952,759,176,204),
	"disrupt": Rect2(1215,769,141,192)
}
const Regions := {
	"basic": Rect2(201,80,99,185),
	"pierce": Rect2(462,55,96,210),
	"precise": Rect2(698,79,141,186),
	"charge": Rect2(963,46,112,219),
	"cool": Rect2(1201,95,166,171),
	"arc": Rect2(179,315,144,177)
}

static func draw(c: CanvasItem, id: String, rect: Rect2, alpha: float = 1.0) -> void:
	var source := Content.source_id(id)
	if not Regions.has(source) and not SpecialRegions.has(source) and not LegacyRegions.has(source):
		preload("res://redesign/pixel_art.gd").round_icon(c,rect.get_center(),source,Visual.COLORS.get(id,Visual.COLORS.basic),minf(rect.size.x/30.0,rect.size.y/86.0),Content.is_compressed(id),Content.is_temporary(id))
		return
	var region: Rect2=Regions.get(source,SpecialRegions.get(source,LegacyRegions.get(source,Rect2())))
	var sheet: Texture2D=Sheet if Regions.has(source) else SpecialSheet if SpecialRegions.has(source) else LegacySheet
	var scale := minf(rect.size.x/region.size.x,rect.size.y/region.size.y)
	var extent := (region.size*scale).floor()
	c.draw_texture_rect_region(sheet,Rect2((rect.get_center()-extent*0.5).round(),extent),region,Color(1,1,1,alpha))
