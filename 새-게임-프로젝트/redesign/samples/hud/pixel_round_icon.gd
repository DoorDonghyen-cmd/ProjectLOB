@tool
extends Control
const Content=preload("res://redesign/content.gd")
const KINDS=["basic","pierce","precise","charge","cool","arc","push","bore","shatter","detonate","chase","bypass","thermal","vent","spread","charge_heat","charge_hot","sequence","prepare","disrupt"]
const Textures={"basic":preload("res://assets/ui/combat_pixel_20261101/ammo_basic.png"),"pierce":preload("res://assets/ui/combat_pixel_20261101/ammo_pierce.png"),"precise":preload("res://assets/ui/combat_pixel_20261101/ammo_precise.png"),"charge":preload("res://assets/ui/combat_pixel_20261101/ammo_charge.png"),"cool":preload("res://assets/ui/combat_pixel_20261101/ammo_cool.png"),"arc":preload("res://assets/ui/combat_pixel_20261101/ammo_arc.png"),"push":preload("res://assets/ui/combat_pixel_20261101/ammo_push.png"),"bore":preload("res://assets/ui/combat_pixel_20261101/ammo_bore.png"),"shatter":preload("res://assets/ui/combat_pixel_20261101/ammo_shatter.png"),"detonate":preload("res://assets/ui/combat_pixel_20261101/ammo_detonate.png"),"chase":preload("res://assets/ui/combat_pixel_20261101/ammo_chase.png"),"bypass":preload("res://assets/ui/combat_pixel_20261101/ammo_bypass.png"),"thermal":preload("res://assets/ui/combat_pixel_20261101/ammo_thermal.png"),"vent":preload("res://assets/ui/combat_pixel_20261101/ammo_vent.png"),"spread":preload("res://assets/ui/combat_pixel_20261101/ammo_spread.png"),"charge_heat":preload("res://assets/ui/combat_pixel_20261101/ammo_charge_heat.png"),"charge_hot":preload("res://assets/ui/combat_pixel_20261101/ammo_charge_hot.png"),"sequence":preload("res://assets/ui/combat_pixel_20261101/ammo_sequence.png"),"prepare":preload("res://assets/ui/combat_pixel_20261101/ammo_prepare.png"),"disrupt":preload("res://assets/ui/combat_pixel_20261101/ammo_disrupt.png")}
@export var item_id: String="basic_p3":
 set(value):item_id=value;queue_redraw()
func _ready()->void:resized.connect(queue_redraw)
func _draw()->void:
 var source: String=Content.source_id(item_id)
 var texture: Texture2D=Textures.get(source,Textures.basic)
 var factor: int=maxi(1,floori(minf(size.x/14.0,size.y/22.0)))
 var extent:=Vector2(14,22)*factor
 draw_texture_rect(texture,Rect2(((size-extent)*0.5).floor(),extent),false)
