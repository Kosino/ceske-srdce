extends Node
class_name VictoryController

signal match_ended(player_won: bool)

var ended: bool = false


func _ready() -> void:
	add_to_group("victory_controller")
	call_deferred("_connect_halls")


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
	if ended:
		return
	ended = true
	var player_won := hall.team != 0
	if player_won:
		print("[VICTORY] enemy Radnice destroyed — player wins")
		NotificationManager.show_message("Vítězství! Nepřátelská radnice padla.")
	else:
		print("[DEFEAT] player Radnice destroyed — player loses")
		NotificationManager.show_message("Porážka! Tvá radnice byla zničena.")
	match_ended.emit(player_won)
