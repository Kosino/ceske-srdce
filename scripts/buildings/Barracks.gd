extends Building
class_name Barracks

signal queue_changed
signal unit_spawned(unit: Node2D)

const SOLDIER_SCENE := preload("res://scenes/units/Soldier.tscn")
const SPEARMAN_SCENE := preload("res://scenes/units/Spearman.tscn")
const MAX_QUEUE := 5

## DESIGN: Kasárna trénuje jen Zbrojnoše a Kopiníka (Lučištník → Střelnice).
const UNIT_DEFS := {
	"soldier": {"cost": {"food": 60, "gold": 20}, "time": 21.0, "label": "zbrojnoš"},
	"spearman": {"cost": {"food": 35, "wood": 25}, "time": 22.0, "label": "kopiník"},
}

var queue: Array[String] = []
var train_remaining: float = 0.0
var spawn_parent: Node2D


func _ready() -> void:
	building_id = "barracks"
	display_name = "Kasárna"
	footprint = Vector2(80, 80)
	max_hp = 1200.0
	build_time = 50.0
	super._ready()
	add_to_group("barracks")


func _process(delta: float) -> void:
	super._process(delta)
	if not is_complete:
		return
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
	NotificationManager.show_message("Lučištník se trénuje na Střelnici.")
	return false


func enqueue_unit(unit_id: String) -> bool:
	if not is_complete:
		NotificationManager.show_message("Kasárna ještě není dokončená.")
		return false
	if unit_id == "archer":
		NotificationManager.show_message("Lučištník se trénuje na Střelnici.")
		return false
	if unit_id not in UNIT_DEFS:
		return false
	if not GameManager.is_unit_unlocked(unit_id):
		NotificationManager.show_message(
			"Zamčeno do věku %s." % AgeData.age_name(AgeData.unit_unlock_age(unit_id))
		)
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
	_push_queue(unit_id, float(def["time"]))
	print("[PROD] queued %s (queue=%d)" % [unit_id, queue.size()])
	return true


## AI training — caller already paid from AI stockpile (no GameManager).
func ai_enqueue_unit(unit_id: String) -> bool:
	if not is_complete or unit_id not in UNIT_DEFS:
		return false
	if queue.size() >= MAX_QUEUE:
		return false
	var def: Dictionary = UNIT_DEFS[unit_id]
	var t := 1.2 if DisplayServer.get_name() == "headless" else float(def["time"])
	_push_queue(unit_id, t)
	print("[AI-PROD] queued %s (queue=%d t=%.1f)" % [unit_id, queue.size(), t])
	return true


func _push_queue(unit_id: String, train_time: float) -> void:
	queue.append(unit_id)
	if queue.size() == 1:
		train_remaining = train_time
	queue_changed.emit()


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
	_apply_rally(unit)
	unit_spawned.emit(unit)
	var label := str(UNIT_DEFS.get(unit_id, {}).get("label", unit_id))
	print("[PROD] spawned %s at %s" % [unit_id, str(unit.position)])
	NotificationManager.show_message("Vycvičen %s." % label)
	queue_changed.emit()
	if not queue.is_empty():
		var next_id: String = queue[0]
		if team != 0 and DisplayServer.get_name() == "headless":
			train_remaining = 1.2
		else:
			train_remaining = float(UNIT_DEFS[next_id]["time"])


func _apply_rally(unit: Node) -> void:
	var rally := get_node_or_null("RallyPoint")
	if rally != null and rally.has_method("apply_to_unit"):
		rally.call("apply_to_unit", unit)


func _instantiate_unit(unit_id: String) -> Node2D:
	match unit_id:
		"soldier":
			return SOLDIER_SCENE.instantiate()
		"spearman":
			return SPEARMAN_SCENE.instantiate()
		_:
			return null