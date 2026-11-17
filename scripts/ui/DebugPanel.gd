extends CanvasLayer

@onready var stats_label: Label = $Panel/Margin/VBox/StatsLabel
@onready var fps_label: Label = $Panel/Margin/VBox/FpsLabel
@onready var build_label: Label = $Panel/Margin/VBox/BuildLabel


func _ready() -> void:
	GameManager.resources_changed.connect(_refresh_stats)
	GameManager.population_changed.connect(_refresh_stats)
	GameManager.age_changed.connect(_refresh_stats)
	_refresh_stats()
	_refresh_fps()


func _process(_delta: float) -> void:
	if visible:
		_refresh_fps()
		_refresh_build_status()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("debug_toggle"):
		return
	visible = not visible
	if visible:
		_refresh_stats()
		_refresh_fps()
	get_viewport().set_input_as_handled()


func _refresh_stats() -> void:
	stats_label.text = "Food: %d\nWood: %d\nGold: %d\nStone: %d\nPop: %d / %d\nAge: %d" % [
		GameManager.food,
		GameManager.wood,
		GameManager.gold,
		GameManager.stone,
		GameManager.population,
		GameManager.population_max,
		GameManager.current_age,
	]


func _refresh_fps() -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


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
	if GameManager.current_age >= 4:
		NotificationManager.show_message("Už jsi v posledním věku.")
		return
	GameManager.advance_age()


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