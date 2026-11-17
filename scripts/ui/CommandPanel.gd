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
	var counts := {"soldier": 0, "spearman": 0, "archer": 0, "villager": 0, "other": 0}
	for u in units:
		if u is Soldier:
			counts["soldier"] += 1
		elif u is Spearman:
			counts["spearman"] += 1
		elif u is Archer:
			counts["archer"] += 1
		elif u is Villager:
			counts["villager"] += 1
		else:
			counts["other"] += 1
	var parts: PackedStringArray = []
	if counts["soldier"] > 0:
		parts.append("%d zbrojnoš" % counts["soldier"])
	if counts["spearman"] > 0:
		parts.append("%d kopiník" % counts["spearman"])
	if counts["archer"] > 0:
		parts.append("%d lučištník" % counts["archer"])
	if counts["villager"] > 0:
		parts.append("%d vesničan" % counts["villager"])
	if counts["other"] > 0:
		parts.append("%d jiní" % counts["other"])
	summary_label.text = "Výběr: %s" % ", ".join(parts)


func _on_stop_pressed() -> void:
	SelectionManager.issue_stop()
	NotificationManager.show_message("Stop")


func _on_train_soldier_pressed() -> void:
	_barracks_enqueue("soldier")


func _on_train_spearman_pressed() -> void:
	_barracks_enqueue("spearman")


func _on_train_archer_pressed() -> void:
	_barracks_enqueue("archer")


func _on_train_villager_pressed() -> void:
	var hall := get_tree().get_first_node_in_group("player_town_hall") as DropOff
	if hall == null:
		NotificationManager.show_message("Nemáš radnici.")
		return
	hall.enqueue_villager()


func _barracks_enqueue(unit_id: String) -> void:
	var barracks := get_tree().get_first_node_in_group("barracks") as Barracks
	if barracks == null:
		NotificationManager.show_message("Nejdřív postav Kasárnu.")
		return
	barracks.enqueue_unit(unit_id)