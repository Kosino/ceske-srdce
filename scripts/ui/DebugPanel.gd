extends CanvasLayer

@onready var stats_label: Label = $Panel/Margin/VBox/StatsLabel
@onready var fps_label: Label = $Panel/Margin/VBox/FpsLabel
@onready var build_label: Label = $Panel/Margin/VBox/BuildLabel

var _fps_accum: float = 0.0


func _ready() -> void:
	# Fáze 3: debug is F3-only — never cover the map on start.
	visible = false
	GameManager.resources_changed.connect(_refresh_stats)
	GameManager.population_changed.connect(_refresh_stats)
	GameManager.age_changed.connect(_refresh_stats)
	_refresh_stats()
	_refresh_fps()
	_refresh_build_cost_labels()


func _process(delta: float) -> void:
	if not visible:
		return
	_fps_accum += delta
	if _fps_accum >= 0.25:
		_fps_accum = 0.0
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
	stats_label.text = "Food: %d\nWood: %d\nGold: %d\nStone: %d\nPop: %d / %d\nAge: %d\nCiv: %s" % [
		GameManager.food,
		GameManager.wood,
		GameManager.gold,
		GameManager.stone,
		GameManager.population,
		GameManager.population_max,
		GameManager.current_age,
		GameManager.get_civ_name(0),
	]


func _refresh_fps() -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()


func _refresh_build_status() -> void:
	if build_label == null:
		return
	var lines: PackedStringArray = []
	var barracks := get_tree().get_first_node_in_group("barracks") as Barracks
	lines.append("Kasárna: %s" % (barracks.get_queue_summary() if barracks else "žádná"))
	var archery := get_tree().get_first_node_in_group("archery_ranges") as ArcheryRange
	lines.append("Střelnice: %s" % (archery.get_queue_summary() if archery else "žádná"))
	var hall := get_tree().get_first_node_in_group("player_town_hall") as DropOff
	lines.append("Radnice: %s" % (hall.get_queue_summary() if hall else "žádná"))
	build_label.text = "\n".join(lines)


func _on_add_food_pressed() -> void:
	GameManager.add_resource("food", 50)


func _on_add_wood_pressed() -> void:
	GameManager.add_resource("wood", 50)


func _on_advance_age_pressed() -> void:
	## Debug cheat: instant age advance (skips Radnice research).
	if GameManager.current_age >= AgeData.MAX_AGE:
		NotificationManager.show_message("Už jsi v posledním věku.")
		return
	GameManager.advance_age()


func _on_place_house_pressed() -> void:
	_begin("house")


func _on_place_barracks_pressed() -> void:
	_begin("barracks")


func _on_place_archery_pressed() -> void:
	_begin("archery_range")


func _on_place_blacksmith_pressed() -> void:
	_begin("blacksmith")


func _on_place_lumber_pressed() -> void:
	_begin("lumber_camp")


func _on_place_mill_pressed() -> void:
	_begin("mill")


func _on_train_soldier_pressed() -> void:
	_barracks_enqueue("soldier")


func _on_train_spearman_pressed() -> void:
	_barracks_enqueue("spearman")


func _on_train_archer_pressed() -> void:
	var range_b := get_tree().get_first_node_in_group("archery_ranges") as ArcheryRange
	if range_b == null:
		NotificationManager.show_message("Nejdřív postav Střelnici.")
		return
	range_b.enqueue_unit("archer")


func _on_train_villager_pressed() -> void:
	var hall := get_tree().get_first_node_in_group("player_town_hall") as DropOff
	if hall == null:
		NotificationManager.show_message("Nemáš radnici.")
		return
	hall.enqueue_villager()


func _begin(building_type: String) -> void:
	var placer := _placer()
	if placer:
		placer.begin_place(building_type)


func _barracks_enqueue(unit_id: String) -> void:
	var barracks := get_tree().get_first_node_in_group("barracks") as Barracks
	if barracks == null:
		NotificationManager.show_message("Nejdřív postav Kasárnu.")
		return
	barracks.enqueue_unit(unit_id)


func _placer() -> BuildingPlacer:
	return get_tree().get_first_node_in_group("building_placer") as BuildingPlacer


## Button text/tooltip show civ-discounted wood costs via adjust_building_cost.
func _refresh_build_cost_labels() -> void:
	var mapping := {
		"PlaceHouse": ["Dům", "house"],
		"PlaceBarracks": ["Kasárna", "barracks"],
		"PlaceLumber": ["Pila", "lumber_camp"],
		"PlaceMining": ["Důlní tábor", "mining_camp"],
		"PlaceMill": ["Mlýn", "mill"],
		"PlaceFarm": ["Farma", "farm"],
		"PlaceArchery": ["Střelnice", "archery_range"],
		"PlaceBlacksmith": ["Kovárna", "blacksmith"],
		"PlaceStable": ["Stáj", "stable"],
		"PlaceCastle": ["Hrad", "castle"],
	}
	var row := get_node_or_null("Panel/Margin/VBox/BuildButtons")
	if row == null:
		return
	for child_name in mapping.keys():
		var btn := row.get_node_or_null(child_name) as Button
		if btn == null:
			continue
		var label: String = mapping[child_name][0]
		var btype: String = mapping[child_name][1]
		var base: Dictionary = BuildingPlacer.COSTS.get(btype, {})
		var cost := GameManager.adjust_building_cost(base, 0)
		var cost_txt := CivData.format_cost(cost)
		btn.text = "%s %s" % [label, cost_txt]
		btn.tooltip_text = "Cena (civ): %s" % cost_txt