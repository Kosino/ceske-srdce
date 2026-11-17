extends PanelContainer
class_name CommandPanel

@onready var summary_label: Label = %CommandSummary


func _ready() -> void:
	SelectionManager.selection_changed.connect(_on_selection_changed)
	_on_selection_changed(SelectionManager.selected_units)


func _on_selection_changed(units: Array) -> void:
	if units.is_empty():
		summary_label.text = "Výběr: nic\nLMB výběr / box, RMB pohyb/útok"
		return
	var soldiers := 0
	var villagers := 0
	var other := 0
	for u in units:
		if u is Soldier:
			soldiers += 1
		elif u is Villager:
			villagers += 1
		else:
			other += 1
	var parts: PackedStringArray = []
	if soldiers > 0:
		parts.append("%d voják" % soldiers)
	if villagers > 0:
		parts.append("%d vesničan" % villagers)
	if other > 0:
		parts.append("%d jiní" % other)
	summary_label.text = "Výběr: %s\nStop zruší útok/pohyb" % ", ".join(parts)


func _on_stop_pressed() -> void:
	SelectionManager.issue_stop()
	NotificationManager.show_message("Stop")
