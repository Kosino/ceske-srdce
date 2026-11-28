extends Button
class_name IdleVillagerButton
## Small HUD control: idle villager count + click = next idle (same as `.` hotkey).


func _ready() -> void:
	add_to_group("idle_villager_button")
	pressed.connect(_on_pressed)
	SelectionManager.idle_villager_count_changed.connect(_on_count)
	_on_count(SelectionManager.count_idle_villagers())


func _on_pressed() -> void:
	SelectionManager.select_next_idle_villager()


func _on_count(count: int) -> void:
	text = "Nečinní %d" % count
	disabled = count <= 0
	tooltip_text = "Vybrat dalšího nečinného vesničana (.)"
