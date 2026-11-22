extends Building
class_name ArcheryRange

signal queue_changed
signal unit_spawned(unit: Node2D)

const ARCHER_SCENE := preload("res://scenes/units/Archer.tscn")
const MAX_QUEUE := 5

## DESIGN: Střelnice 175 D, 50 s, HP 1200. Trénink: Lučištník 25 D + 45 Z / 35 s.
const UNIT_DEFS := {
	"archer": {"cost": {"wood": 25, "gold": 45}, "time": 35.0, "label": "lučištník"},
}

var queue: Array[String] = []
var train_remaining: float = 0.0
var spawn_parent: Node2D


func _ready() -> void:
	building_id = "archery_range"
	display_name = "Střelnice"
	footprint = Vector2(80, 80)
	max_hp = 1200.0
	build_time = 50.0
	super._ready()
	add_to_group("archery_ranges")


func _process(delta: float) -> void:
	super._process(delta)
	if not is_complete:
		return
	if queue.is_empty():
		return
	train_remaining -= delta
	if train_remaining <= 0.0:
		_complete_training()


func enqueue_archer() -> bool:
	return enqueue_unit("archer")


func enqueue_unit(unit_id: String) -> bool:
	if not is_complete:
		NotificationManager.show_message("Střelnice ještě není dokončená.")
		return false
	if unit_id not in UNIT_DEFS:
		NotificationManager.show_message("Střelnice trénuje jen lučištníky.")
		return false
	if not GameManager.is_unit_unlocked(unit_id):
		NotificationManager.show_message(
			"Zamčeno do věku %s." % AgeData.age_name(AgeData.unit_unlock_age(unit_id))
		)
		return false
	if queue.size() >= MAX_QUEUE:
		NotificationManager.show_message("Fronta střelnice je plná.")
		return false
	if not GameManager.can_add_population(1):
		NotificationManager.show_message("Nedostatek populace (postav Dům).")
		return false
	var def: Dictionary = UNIT_DEFS[unit_id]
	if not GameManager.spend(def["cost"]):
		NotificationManager.show_message("Nedostatek surovin na %s." % def["label"])
		return false
	GameManager.change_population(1)
	queue.append(unit_id)
	if queue.size() == 1:
		train_remaining = float(def["time"])
	queue_changed.emit()
	print("[PROD] archery queued %s (queue=%d)" % [unit_id, queue.size()])
	return true


## AI — caller already paid from AI stockpile.
func ai_enqueue_unit(unit_id: String) -> bool:
	if not is_complete or unit_id not in UNIT_DEFS:
		return false
	if queue.size() >= MAX_QUEUE:
		return false
	var def: Dictionary = UNIT_DEFS[unit_id]
	var t := 1.2 if DisplayServer.get_name() == "headless" else float(def["time"])
	queue.append(unit_id)
	if queue.size() == 1:
		train_remaining = t
	queue_changed.emit()
	print("[AI-PROD] archery queued %s (queue=%d)" % [unit_id, queue.size()])
	return true


func get_queue_summary() -> String:
	if queue.is_empty():
		return "fronta prázdná"
	return "fronta %d | %.1fs" % [queue.size(), maxf(train_remaining, 0.0)]


func _complete_training() -> void:
	if queue.is_empty():
		return
	var unit_id: String = queue.pop_front()
	var unit := ARCHER_SCENE.instantiate()
	if unit is Unit:
		(unit as Unit).contribute_population = false
		(unit as Unit).team = team
	var parent := spawn_parent if spawn_parent else get_parent()
	unit.position = global_position + Vector2(0, footprint.y * 0.5 + 24.0)
	parent.add_child(unit)
	if unit is Unit and (unit as Unit).team == 0 and not unit.is_in_group("player_units"):
		unit.add_to_group("player_units")
	unit_spawned.emit(unit)
	print("[PROD] spawned archer at %s" % str(unit.position))
	NotificationManager.show_message("Vycvičen lučištník.")
	queue_changed.emit()
	if not queue.is_empty():
		var next_id: String = queue[0]
		train_remaining = float(UNIT_DEFS[next_id]["time"])