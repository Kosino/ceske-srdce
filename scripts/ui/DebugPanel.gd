extends PanelContainer

@onready var info_label: Label = %InfoLabel
@onready var build_label: Label = %BuildLabel


func _ready() -> void:
	GameManager.resources_changed.connect(_refresh)
	GameManager.population_changed.connect(_refresh)
	GameManager.age_changed.connect(_refresh)
	_refresh()


func _process(_delta: float) -> void:
	_refresh_build_status()


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


func _refresh_build_status() -> void:
	if build_label == null:
		return
	var barracks := get_tree().get_first_node_in_group("barracks") as Barracks
	if barracks:
		build_label.text = "Kasárna: %s" % barracks.get_queue_summary()
	else:
		build_label.text = "Kasárna: žádná"


func _on_add_food_pressed() -> void:
	GameManager.add_resource("food", 50)


func _on_add_wood_pressed() -> void:
	GameManager.add_resource("wood", 50)


func _on_advance_age_pressed() -> void:
	if not GameManager.advance_age():
		NotificationManager.show_message("Už jsi v posledním věku.")


func _on_place_house_pressed() -> void:
	var placer := _placer()
	if placer:
		placer.begin_place("house")


func _on_place_barracks_pressed() -> void:
	var placer := _placer()
	if placer:
		placer.begin_place("barracks")


func _on_train_soldier_pressed() -> void:
	var barracks := get_tree().get_first_node_in_group("barracks") as Barracks
	if barracks == null:
		NotificationManager.show_message("Nejdřív postav Kasárnu.")
		return
	barracks.enqueue_soldier()


func _placer() -> BuildingPlacer:
	return get_tree().get_first_node_in_group("building_placer") as BuildingPlacer
