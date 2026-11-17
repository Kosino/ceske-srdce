extends PanelContainer

@onready var info_label: Label = %InfoLabel


func _ready() -> void:
	GameManager.resources_changed.connect(_refresh)
	GameManager.population_changed.connect(_refresh)
	GameManager.age_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	info_label.text = (
		"Food %d  Wood %d  Gold %d  Stone %d\n"
		+ "Pop %d / %d    Age %d"
	) % [
		GameManager.food,
		GameManager.wood,
		GameManager.gold,
		GameManager.stone,
		GameManager.population,
		GameManager.population_max,
		GameManager.current_age,
	]


func _on_add_food_pressed() -> void:
	GameManager.add_resource("food", 50)


func _on_add_wood_pressed() -> void:
	GameManager.add_resource("wood", 50)


func _on_advance_age_pressed() -> void:
	if not GameManager.advance_age():
		NotificationManager.show_message("Už jsi v posledním věku.")
