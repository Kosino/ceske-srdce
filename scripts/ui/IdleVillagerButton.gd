extends Button
class_name IdleVillagerButton
## Small HUD control: idle villager count + click = next idle (same as `.` hotkey).


var _poll_accum: float = 0.0
var _last_count: int = -1


func _ready() -> void:
	add_to_group("idle_villager_button")
	pressed.connect(_on_pressed)
	SelectionManager.idle_villager_count_changed.connect(_on_count)
	_on_count(SelectionManager.count_idle_villagers())


func _process(delta: float) -> void:
	_poll_accum += delta
	if _poll_accum < 0.35:
		return
	_poll_accum = 0.0
	var n := SelectionManager.count_idle_villagers()
	if n != _last_count:
		_last_count = n
		SelectionManager.idle_villager_count_changed.emit(n)


func _on_pressed() -> void:
	SelectionManager.select_next_idle_villager()


func _on_count(count: int) -> void:
	_last_count = count
	text = "Nečinní %d" % count
	disabled = count <= 0
	tooltip_text = "Vybrat dalšího nečinného vesničana (.)"
