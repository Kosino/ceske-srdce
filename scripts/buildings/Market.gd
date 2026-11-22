extends Building
class_name Market
## Tržiště — NÁVRH: 175 D, 60 s, 2100 HP, 80×80, věk 3. Základní obchod.


func _ready() -> void:
	building_id = "market"
	display_name = "Tržiště"
	footprint = Vector2(80, 80)
	max_hp = 2100.0
	build_time = 60.0
	super._ready()
	add_to_group("markets")


## Simple AoE-like sell wood→gold (prototype). Returns false if cannot.
func trade_wood_for_gold(wood_amount: int = 100) -> bool:
	if not is_complete or team != 0:
		return false
	if wood_amount <= 0 or GameManager.wood < wood_amount:
		NotificationManager.show_message("Nedostatek dřeva na obchod.")
		return false
	GameManager.spend({"wood": wood_amount})
	var gold_gain := int(round(float(wood_amount) * 0.7)) # rough AoE tax
	GameManager.add_resource("gold", maxi(gold_gain, 1))
	NotificationManager.show_message("Obchod: −%d Dřevo / +%d Zlato" % [wood_amount, gold_gain])
	return true
