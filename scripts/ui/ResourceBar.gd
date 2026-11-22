extends PanelContainer
class_name ResourceBar
## Top-of-screen resource strip (AoE-like HUD).


@onready var label: Label = %ResourceLabel


func _ready() -> void:
	add_to_group("hud_resource_bar")
	GameManager.resources_changed.connect(_refresh)
	GameManager.population_changed.connect(_refresh)
	GameManager.age_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if label == null:
		return
	label.text = "Jídlo %d   Dřevo %d   Zlato %d   Kámen %d   Pop %d/%d   · %s" % [
		GameManager.food,
		GameManager.wood,
		GameManager.gold,
		GameManager.stone,
		GameManager.population,
		GameManager.population_max,
		GameManager.get_civ_name(0),
	]
