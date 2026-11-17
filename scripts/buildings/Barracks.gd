extends Building
class_name Barracks

signal queue_changed
signal unit_spawned(unit: Node2D)

const SOLDIER_SCENE := preload("res://scenes/units/Soldier.tscn")
const SOLDIER_COST := {"food": 50, "gold": 20}
const TRAIN_TIME := 2.5
const MAX_QUEUE := 5

var queue: Array[String] = []
var train_remaining: float = 0.0
var spawn_parent: Node2D


func _ready() -> void:
	building_id = "barracks"
	display_name = "Kasárna"
	footprint = Vector2(80, 80)
	max_hp = 600.0
	super._ready()
	add_to_group("barracks")


func _process(delta: float) -> void:
	if queue.is_empty():
		return
	train_remaining -= delta
	if train_remaining <= 0.0:
		_complete_training()


func enqueue_soldier() -> bool:
	if queue.size() >= MAX_QUEUE:
		NotificationManager.show_message("Fronta kasáren je plná.")
		return false
	if not GameManager.has_population_space():
		NotificationManager.show_message("Nedostatek populace (postav Dům).")
		return false
	if not GameManager.spend(SOLDIER_COST):
		NotificationManager.show_message("Nedostatek surovin na vojáka.")
		return false
	# Reserve population slot until spawn/death.
	GameManager.change_population(1)
	queue.append("soldier")
	if queue.size() == 1:
		train_remaining = TRAIN_TIME
	queue_changed.emit()
	print("[PROD] queued soldier (queue=%d)" % queue.size())
	return true


func get_queue_summary() -> String:
	if queue.is_empty():
		return "fronta prázdná"
	return "fronta %d | %.1fs" % [queue.size(), maxf(train_remaining, 0.0)]


func _complete_training() -> void:
	if queue.is_empty():
		return
	queue.pop_front()
	var soldier: Node2D = SOLDIER_SCENE.instantiate()
	var parent := spawn_parent if spawn_parent else get_parent()
	soldier.position = global_position + Vector2(0, footprint.y * 0.5 + 24.0)
	parent.add_child(soldier)
	unit_spawned.emit(soldier)
	print("[PROD] spawned soldier at %s" % str(soldier.position))
	NotificationManager.show_message("Vycvičen voják.")
	queue_changed.emit()
	if not queue.is_empty():
		train_remaining = TRAIN_TIME
