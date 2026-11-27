extends Building
class_name SiegeWorkshop
## Obléhací dílna — 200 D, 60 s, 2100 HP, 80×80, věk 4 (vyžaduje Univerzitu).

signal queue_changed
signal unit_spawned(unit: Node2D)

const RAM_SCENE := preload("res://scenes/units/Ram.tscn")
const TREBUCHET_SCENE := preload("res://scenes/units/Trebuchet.tscn")
const MAX_QUEUE := 5

const UNIT_DEFS := {
	"ram": {"cost": {"wood": 160, "gold": 75}, "time": 36.0, "label": "beranidlo"},
	"trebuchet": {"cost": {"wood": 200, "gold": 200}, "time": 50.0, "label": "trebuchet"},
}

var queue: Array[String] = []
var train_remaining: float = 0.0
var spawn_parent: Node2D


func _ready() -> void:
	building_id = "siege_workshop"
	display_name = "Obléhací dílna"
	footprint = Vector2(80, 80)
	max_hp = 2100.0
	build_time = 60.0
	super._ready()
	add_to_group("siege_workshops")


func _process(delta: float) -> void:
	super._process(delta)
	if not is_complete:
		return
	if queue.is_empty():
		return
	train_remaining -= delta
	if train_remaining <= 0.0:
		_complete_training()


func enqueue_unit(unit_id: String) -> bool:
	if not is_complete:
		NotificationManager.show_message("Dílna ještě není dokončená.")
		return false
	if unit_id not in UNIT_DEFS:
		return false
	if not GameManager.is_unit_unlocked(unit_id):
		NotificationManager.show_message(
			"Zamčeno do věku %s." % AgeData.age_name(AgeData.unit_unlock_age(unit_id))
		)
		return false
	if queue.size() >= MAX_QUEUE:
		NotificationManager.show_message("Fronta dílny je plná.")
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
		if DisplayServer.get_name() == "headless":
			train_remaining = minf(train_remaining, 1.2)
	queue_changed.emit()
	print("[PROD] siege_workshop queued %s (queue=%d)" % [unit_id, queue.size()])
	return true


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
	print("[AI-PROD] siege_workshop queued %s" % unit_id)
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
	unit_spawned.emit(unit)
	BalanceSim.record_unit_trained(team, unit_id)
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


func _instantiate_unit(unit_id: String) -> Node2D:
	match unit_id:
		"ram":
			return RAM_SCENE.instantiate()
		"trebuchet":
			return TREBUCHET_SCENE.instantiate()
		_:
			return null
