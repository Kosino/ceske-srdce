extends PanelContainer
class_name SelectionInfo
## Bottom-center selection summary (AoE-like HUD).


@onready var label: Label = %SelectionInfoLabel


func _ready() -> void:
	add_to_group("hud_selection_info")
	SelectionManager.selection_changed.connect(_on_selection_changed)
	SelectionManager.formation_changed.connect(_on_formation_changed)
	_on_selection_changed(SelectionManager.selected_units)


func _on_formation_changed(_kind: String) -> void:
	_on_selection_changed(SelectionManager.selected_units)


func _on_selection_changed(units: Array) -> void:
	if label == null:
		return
	if units.is_empty():
		label.text = "Výběr: nic\nLMB výběr / box · RMB pohyb/útok"
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
	label.text = "Výběr: %s\nFormace: %s" % [
		", ".join(parts), FormationData.display_name(SelectionManager.formation)
	]
