extends Button
class_name IdleVillagerButton
## Small HUD control: idle villager count + click = next idle (same as `.` hotkey).
## T-36: count / cycle exclude garrisoned villagers (via SelectionManager.is_villager_idle).


var _poll_accum: float = 0.0
var _last_count: int = -1


func _ready() -> void:
	add_to_group("idle_villager_button")
	pressed.connect(_on_pressed)
	SelectionManager.idle_villager_count_changed.connect(_on_count)
	_on_count(_idle_count())


func _process(delta: float) -> void:
	_poll_accum += delta
	if _poll_accum < 0.35:
		return
	_poll_accum = 0.0
	var n := _idle_count()
	if n != _last_count:
		_last_count = n
		SelectionManager.idle_villager_count_changed.emit(n)


func _on_pressed() -> void:
	SelectionManager.select_next_idle_villager()


func _on_count(count: int) -> void:
	_last_count = count
	text = "Nečinní %d" % count
	disabled = count <= 0
	tooltip_text = "Vybrat dalšího nečinného vesničana (.) — bez posádky"


## Idle count used by the HUD — garrisoned villagers must not appear as Nečinní.
func _idle_count() -> int:
	return SelectionManager.count_idle_villagers()
