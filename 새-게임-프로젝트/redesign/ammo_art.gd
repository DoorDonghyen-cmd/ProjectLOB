extends RefCounted
## Shared cartridge art; unmapped families retain their existing functional silhouette.
const Content = preload("res://redesign/content.gd")
const Visual = preload("res://redesign/ammo_visual.gd")
const Sheet = preload("res://assets/art/ammo_recast_20261017/cartridges_v4.png")
const SpecialSheet = preload("res://assets/art/ammo_recast_20261018/special_rounds_v1.png")
const SpecialRegions := {
	"push":Rect2(150,53,222,280), "bore":Rect2(514,29,162,304),
	"shatter":Rect2(869,28,149,305), "detonate":Rect2(1206,48,153,285),
	"chase":Rect2(165,361,163,286), "bypass":Rect2(511,378,162,269),
	"thermal":Rect2(846,378,189,269), "vent":Rect2(1174,400,228,247),
	"spread":Rect2(135,723,214,258), "charge_heat":Rect2(497,686,194,295),
	"charge_hot":Rect2(858,686,170,295), "sequence":Rect2(1215,693,170,288)
}
const Regions := {
	"basic": Rect2(171,151,209,361), "pierce": Rect2(682,68,174,444),
	"precise": Rect2(1114,188,301,324), "charge": Rect2(163,548,216,408),
	"cool": Rect2(659,578,219,378), "arc": Rect2(1141,580,247,376)
}

static func draw(c: CanvasItem, id: String, rect: Rect2, alpha: float = 1.0) -> void:
	var source := Content.source_id(id)
	if not Regions.has(source) and not SpecialRegions.has(source):
		preload("res://redesign/pixel_art.gd").round_icon(c,rect.get_center(),source,Visual.COLORS.get(id,Visual.COLORS.basic),minf(rect.size.x/30.0,rect.size.y/86.0),Content.is_compressed(id),Content.is_temporary(id))
		return
	var region: Rect2=Regions.get(source,SpecialRegions.get(source,Rect2()))
	var sheet: Texture2D=Sheet if Regions.has(source) else SpecialSheet
	var scale := minf(rect.size.x/region.size.x,rect.size.y/region.size.y)
	var extent := (region.size*scale).floor()
	c.draw_texture_rect_region(sheet,Rect2((rect.get_center()-extent*0.5).round(),extent),region,Color(1,1,1,alpha))
