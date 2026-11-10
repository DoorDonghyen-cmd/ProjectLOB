extends RefCounted
## Run-local acquisition support. Existing saves have no economy marker.
const VERSION:=1
const MODULE_PRICE:=18
const BAG_PRICE:=18
const Choices=preload("res://redesign/build_choices.gd")
const Ammo=preload("res://redesign/content.gd")
static func enabled(state: Dictionary)->bool:return int(state.get("economy_version",0))==VERSION
static func valid(state: Dictionary)->bool:
	var version: Variant=state.get("economy_version",0)
	if not Ammo.Roles.whole(version,0,VERSION):return false
	if not enabled(state):return not state.has("intro_part_bought") and not state.has("gate_bag_used") and not state.has("gate_ammo_used")
	return Ammo.Roles.builds(state) and state.get("intro_part_bought") is bool and state.get("gate_bag_used") is bool and state.get("gate_ammo_used",false) is bool
static func stock(state: Dictionary,combat: Dictionary,offers: Array)->void:
	if not enabled(state) or state.intro_part_bought or offers.size()<2:return
	var offer: Dictionary=offers[1]
	if offer.type!="part" or Choices.modules([offer.id],combat).is_empty():return
	offer.price=MODULE_PRICE;offer.intro_discount=true
static func valid_price(state: Dictionary,offer: Dictionary,index: int)->bool:
	if not offer.get("intro_discount",false) is bool:return false
	if not offer.get("intro_discount",false):return int(offer.price)==30
	return enabled(state) and index==1 and not Ammo.is_core_part(str(offer.id)) and int(offer.price)==MODULE_PRICE and (bool(offer.sold)==bool(state.intro_part_bought))
