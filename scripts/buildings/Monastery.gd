extends Building
class_name Monastery
## Klášter — NÁVRH: 175 D, 40 s, 2100 HP, 80×80, věk 3. Trénuje Mnicha.

signal queue_changed
signal unit_spawned(unit: Node2D)

const MONK_SCENE := preload("res://scenes/units/Monk.tscn")
const MAX_QUEUE := 5
const MONK_COST := {"gold": 100}
const MONK_TIME := 51.0

var queue: Array[String] = []
var train_remaining: float = 0.0
var spawn_parent: Node2D


func _ready() -> void:
	building_id = "monastery"
	display_name = "Klášter"
	footprint = Vector2(80, 80)
	max_hp = 2100.0
	build_time = 40.0
	super._ready()
	add_to_group("monasteries")


func _process(delta: float) -> void:
	super._process(delta)
	if not is_complete or queue.is_empty():
		return
	train_remaining -= delta
	if train_remaining <= 0.0:
		_complete_training()


func enqueue_monk() -> bool:
	return enqueue_unit("monk")


func enqueue_unit(unit_id: String) -> bool:
	if unit_id != "monk":
		return false
	if not is_complete:
		NotificationManager.show_message("Klášter ještě není dokončený.")
		return false
	if not GameManager.is_unit_unlocked("monk"):
		NotificationManager.show_message(
			"Zamčeno do věku %s." % AgeData.age_name(AgeData.unit_unlock_age("monk"))
		)
		return false
	if queue.size() >= MAX_QUEUE:
		NotificationManager.show_message("Fronta kláštera je plná.")
		return false
	if not GameManager.can_add_population(1):
		NotificationManager.show_message("Nedostatek populace (postav Dům).")
		return false
	if not GameManager.spend(MONK_COST):
		NotificationManager.show_message("Nedostatek zlata na mnicha.")
		return false
	GameManager.change_population(1)
	queue.append("monk")
	if queue.size() == 1:
		train_remaining = MONK_TIME
		if DisplayServer.get_name() == "headless":
			train_remaining = minf(train_remaining, 1.2)
	queue_changed.emit()
	print("[PROD] monastery queued monk (queue=%d)" % queue.size())
	return true


## AI — caller already paid from AI stockpile.
func ai_enqueue_unit(unit_id: String) -> bool:
	if unit_id != "monk" or not is_complete:
		return false
	if queue.size() >= MAX_QUEUE:
		return false
	queue.append("monk")
	if queue.size() == 1:
		train_remaining = 1.2 if DisplayServer.get_name() == "headless" else MONK_TIME
	queue_changed.emit()
	print("[AI-PROD] monastery queued monk (queue=%d)" % queue.size())
	return true


func get_queue_summary() -> String:
	if queue.is_empty():
		return "fronta prázdná"
	return "fronta %d | %.1fs" % [queue.size(), maxf(train_remaining, 0.0)]


func _complete_training() -> void:
	if queue.is_empty():
		return
	queue.pop_front()
	var unit: Monk = MONK_SCENE.instantiate() as Monk
	if unit == null:
		queue_changed.emit()
		return
	unit.contribute_population = false
	unit.team = team
	var parent := spawn_parent if spawn_parent else get_parent()
	unit.position = global_position + Vector2(0, footprint.y * 0.5 + 24.0)
	parent.add_child(unit)
	unit_spawned.emit(unit)
	NotificationManager.show_message("Vycvičen Mnich.")
	print("[PROD] spawned monk at %s" % str(unit.position))
	queue_changed.emit()
	if not queue.is_empty():
		train_remaining = 1.2 if DisplayServer.get_name() == "headless" else MONK_TIME
