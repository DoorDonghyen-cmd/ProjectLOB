extends Button

const Data = preload("res://redesign/content.gd")
const LABEL := Color("ede0c6")
const DIM := Color("b1a391")
const BRASS := Color("f4c282")
const SHORT := Color("d89b82")

static func item_name(id: String, state: Dictionary) -> String:
	if Data.AMMO.has(id):
		# Compressed rounds already carry their + mark (content.gd _marked, 2026-11-12).
		return str(Data.AMMO[id].name)
	return str(Data.part_spec(id, state).name)

func show_offer(offer: Dictionary, state: Dictionary, credits: int, chosen: bool) -> void:
	var id := str(offer.id)
	var ammo: bool = offer.type == "ammo"
	var sold: bool = offer.sold
	var title := item_name(id, state)
	var price := "%d Cr" % int(offer.price)
	if sold:
		price = "판매 완료"
	elif offer.get("intro_discount", false):
		price = "30 → %d Cr" % int(offer.price)
	$Tag/Name.text = title
	$Selection.visible = chosen
	$Tag/Name.add_theme_color_override("font_color", DIM if sold else LABEL)
	$Tag/Price.text = price
	var color := BRASS
	if sold:
		color = DIM
	elif credits < int(offer.price):
		color = SHORT
	$Tag/Price.add_theme_color_override("font_color", color)
	$Icon.is_part = not ammo
	$Icon.item_id = id
	$Icon.visible = not sold
	$Rest.visible = not sold
	tooltip_text = "%s · %s" % [title, price]

