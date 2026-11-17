extends Building
class_name Barracks

signal queue_changed
signal unit_spawned(unit: Node2D)

const SOLDIER_SCENE := preload("res://scenes/units/Soldier.tscn")
const SPEARMAN_SCENE := preload("res://scenes/units/Spearman.tscn")
const ARCHER_SCENE := preload("res://scenes/units/Archer.tscn")
const MAX_QUEUE := 5

## DESIGN unit defs: id -> {cost, time, scene, label}
const UNIT_DEFS := {
	"soldier": {"cost": {"food": 60, "gold": 20}, "time": 21.0, "label": "zbrojnoš"},
	"spearman": {"cost": {"food": 35, "wood": 25}, "time": 22.0, "label": "kopiník"},
	"archer": {"cost": {"wood": 25, "gold": 45}, "time": 35.0, "label": "lučištník"},
}

var queue: Array[String] = []
var train_remaining: float = 0.0
var spawn_parent: Node2D


func _ready() -> void:
	building_id = "barracks"
	display_name = "Kasárna"
	footprint = Vector2(80, 80)
	max_hp = 1200.0
	super._ready()
	add_to_group("barracks")


func _process(delta: float) -> void:
	if queue.is_empty():
		return
	train_remaining -= delta
	if train_remaining <= 0.0:
		_complete_training()


func enqueue_soldier() -> bool:
	return enqueue_unit("soldier")


func enqueue_spearman() -> bool:
	return enqueue_unit("spearman")


func enqueue_archer() -> bool:
	return enqueue_unit("archer")


func enqueue_unit(unit_id: String) -> bool:
	if unit_id not in UNIT_DEFS:
		return false
	if queue.size() >= MAX_QUEUE:
		NotificationManager.show_message("Fronta kasáren je plná.")
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
	print("[PROD] queued %s (queue=%d)" % [unit_id, queue.size()])
	return true


func get_queue_summary() -> String:
	if queue.is_empty():
		return "fronta prázdná"
	return "fronta %d | %.1fs" % [queue.size(), maxf(train_remaining, 0.0)]


func _complete_training() -> void:
	if queue.is_empty():
		return
	var unit_id: String = queue.pop_front()
	var unit := _instantiate_unit(unit_id)
	if unit == null:
		queue_changed.emit()
		return
	if unit is Unit:
		(unit as Unit).contribute_population = false
		(unit as Unit).team = team
	var parent := spawn_parent if spawn_parent else get_parent()
	unit.position = global_position + Vector2(0, footprint.y * 0.5 + 24.0)
	parent.add_child(unit)
	if unit is Unit and (unit as Unit).team == 0 and not unit.is_in_group("player_units"):
		unit.add_to_group("player_units")
	unit_spawned.emit(unit)
	var label := str(UNIT_DEFS.get(unit_id, {}).get("label", unit_id))
	print("[PROD] spawned %s at %s" % [unit_id, str(unit.position)])
	NotificationManager.show_message("Vycvičen %s." % label)
	queue_changed.emit()
	if not queue.is_empty():
		var next_id: String = queue[0]
		train_remaining = float(UNIT_DEFS[next_id]["time"])


func _instantiate_unit(unit_id: String) -> Node2D:
	match unit_id:
		"soldier":
			return SOLDIER_SCENE.instantiate()
		"spearman":
			return SPEARMAN_SCENE.instantiate()
		"archer":
			return ARCHER_SCENE.instantiate()
		_:
			return null