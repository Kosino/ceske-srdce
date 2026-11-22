extends PanelContainer
class_name SelectionInfo
## Bottom-center selection summary (AoE-like HUD).


@onready var label: Label = %SelectionInfoLabel


func _ready() -> void:
	add_to_group("hud_selection_info")
	SelectionManager.selection_changed.connect(_refresh)
	SelectionManager.building_selection_changed.connect(_on_building)
	SelectionManager.formation_changed.connect(_on_formation)
	SelectionManager.resource_focus_changed.connect(_on_resource)
	_refresh(SelectionManager.selected_units)


func _on_formation(_kind: String) -> void:
	_refresh(SelectionManager.selected_units)


func _on_building(_b: Node) -> void:
	_refresh(SelectionManager.selected_units)


func _on_resource(_r: ResourceNode) -> void:
	_refresh(SelectionManager.selected_units)


func _refresh(_units: Array = []) -> void:
	if label == null:
		return
	var focus := SelectionManager.focused_resource()
	if focus != null and is_instance_valid(focus):
		label.text = "Zdroj: %s\n(hover / výběr)" % focus.info_line()
		return
	var b := SelectionManager.selected_building
	if b != null and is_instance_valid(b):
		var name := "Budova"
		if b is DropOff:
			name = (b as DropOff).building_name
		elif b is Building:
			name = (b as Building).display_name
		var line2 := "Trénink / produkce"
		if b is Blacksmith:
			var smith := b as Blacksmith
			var prog := smith.research_progress_line()
			line2 = prog if prog != "" else "Výzkum technologií"
		label.text = "Výběr: %s\n%s" % [name, line2]
		return
	var units: Array = SelectionManager.selected_units
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
