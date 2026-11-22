extends Node
class_name VictoryController
## Win: enemy Radnice down + no enemy units. Loss: player Radnice down + no player units.

signal match_ended(player_won: bool)

var ended: bool = false
var player_won: bool = false
var _enemy_hall_down: bool = false
var _player_hall_down: bool = false
var _match_start_msec: int = 0
var _overlay: CanvasLayer
var _title_label: Label
var _time_label: Label


func _ready() -> void:
	add_to_group("victory_controller")
	_match_start_msec = Time.get_ticks_msec()
	process_mode = Node.PROCESS_MODE_ALWAYS
	call_deferred("_connect_halls")


func _process(_delta: float) -> void:
	if ended:
		return
	if _enemy_hall_down and _no_units_in_group("enemy_units"):
		_end_match(true)
	elif _player_hall_down and _no_units_in_group("player_units"):
		_end_match(false)


func _connect_halls() -> void:
	for hall in get_tree().get_nodes_in_group("town_halls"):
		_watch_hall(hall)


func watch_new_hall(hall: DropOff) -> void:
	_watch_hall(hall)


func _watch_hall(hall: Variant) -> void:
	if hall == null or not is_instance_valid(hall):
		return
	if hall is DropOff and not (hall as DropOff).destroyed.is_connected(_on_hall_destroyed):
		(hall as DropOff).destroyed.connect(_on_hall_destroyed)


func _on_hall_destroyed(hall: DropOff) -> void:
	if hall.team != 0:
		_enemy_hall_down = true
		print("[VICTORY] enemy Radnice destroyed — waiting for remaining units")
	else:
		_player_hall_down = true
		print("[DEFEAT] player Radnice destroyed — waiting for remaining units")


func _no_units_in_group(group: String) -> bool:
	for n in get_tree().get_nodes_in_group(group):
		if is_instance_valid(n):
			return false
	return true


func match_elapsed_sec() -> float:
	return float(Time.get_ticks_msec() - _match_start_msec) / 1000.0


func force_check() -> void:
	## Headless / screenshot helper.
	_process(0.0)


func _end_match(won: bool) -> void:
	if ended:
		return
	ended = true
	player_won = won
	var secs := match_elapsed_sec()
	if won:
		print("[VICTORY] player wins after %.1fs" % secs)
		NotificationManager.show_message("Vítězství!")
	else:
		print("[DEFEAT] player loses after %.1fs" % secs)
		NotificationManager.show_message("Porážka!")
	_show_overlay(won, secs)
	get_tree().paused = true
	match_ended.emit(won)


func _show_overlay(won: bool, secs: float) -> void:
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = CanvasLayer.new()
	_overlay.name = "MatchEndOverlay"
	_overlay.layer = 100
	_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	var root := get_tree().current_scene
	if root:
		root.add_child(_overlay)
	else:
		add_child(_overlay)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -220.0
	panel.offset_top = -130.0
	panel.offset_right = 220.0
	panel.offset_bottom = 130.0
	_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	margin.add_child(vbox)

	_title_label = Label.new()
	_title_label.name = "EndTitle"
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title_label.text = "Vítězství!" if won else "Porážka"
	_title_label.add_theme_font_size_override("font_size", 28)
	vbox.add_child(_title_label)

	_time_label = Label.new()
	_time_label.name = "EndTime"
	_time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_time_label.text = "Čas: %s" % _format_time(secs)
	vbox.add_child(_time_label)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(row)

	var again := Button.new()
	again.name = "AgainButton"
	again.text = "Znovu"
	again.custom_minimum_size = Vector2(140, 36)
	again.pressed.connect(_on_again_pressed)
	row.add_child(again)

	var menu := Button.new()
	menu.name = "MenuButton"
	menu.text = "Hlavní menu"
	menu.custom_minimum_size = Vector2(140, 36)
	menu.pressed.connect(_on_menu_pressed)
	row.add_child(menu)


func _format_time(secs: float) -> String:
	var total := int(floor(secs))
	var m := total / 60
	var s := total % 60
	return "%d:%02d" % [m, s]


func _on_again_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/map/Map.tscn")


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")


func get_overlay() -> CanvasLayer:
	return _overlay


func reset_for_test() -> void:
	ended = false
	player_won = false
	_enemy_hall_down = false
	_player_hall_down = false
	_match_start_msec = Time.get_ticks_msec()
	if get_tree():
		get_tree().paused = false
	if _overlay and is_instance_valid(_overlay):
		_overlay.queue_free()
	_overlay = null
	_title_label = null
	_time_label = null
	call_deferred("_connect_halls")
