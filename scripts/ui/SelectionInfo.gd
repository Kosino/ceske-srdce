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
		label.text = "Výběr: %s\n%s" % [name, _building_info_line(b)]
		return
	var units: Array = SelectionManager.selected_units
	if units.is_empty():
		label.text = "Výběr: nic\nLMB výběr / box · RMB pohyb/útok"
		return
	var counts := {
		"soldier": 0, "spearman": 0, "archer": 0, "villager": 0,
		"monk": 0, "fishing_boat": 0, "other": 0
	}
	for u in units:
		if u is Soldier:
			counts["soldier"] += 1
		elif u is Spearman:
			counts["spearman"] += 1
		elif u is Archer:
			counts["archer"] += 1
		elif u is Villager:
			counts["villager"] += 1
		elif u is Monk:
			counts["monk"] += 1
		elif u is FishingBoat:
			counts["fishing_boat"] += 1
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
	if counts["monk"] > 0:
		parts.append("%d mnich" % counts["monk"])
	if counts["fishing_boat"] > 0:
		parts.append("%d rybářská loď" % counts["fishing_boat"])
	if counts["other"] > 0:
		parts.append("%d jiní" % counts["other"])
	label.text = "Výběr: %s\nFormace: %s" % [
		", ".join(parts), FormationData.display_name(SelectionManager.formation)
	]


## T-33: info text by building type (farm → stock + sow state, not generic training).
func _building_info_line(b: Node) -> String:
	if b == null or not is_instance_valid(b):
		return "Budova"
	if b is Farm:
		return _farm_info_line(b as Farm)
	if b is Blacksmith:
		var smith := b as Blacksmith
		var prog := smith.research_progress_line()
		return prog if prog != "" else "Výzkum technologií"
	if b is University:
		var uni := b as University
		var uprog := uni.research_progress_line()
		return uprog if uprog != "" else "Výzkum (Univerzita)"
	if b is DropOff:
		return (b as DropOff).get_queue_summary()
	if b is Barracks:
		return (b as Barracks).get_queue_summary()
	if b is ArcheryRange:
		return (b as ArcheryRange).get_queue_summary()
	if b is Monastery:
		return (b as Monastery).get_queue_summary()
	if b is Stable:
		return (b as Stable).get_queue_summary()
	if b is SiegeWorkshop:
		return (b as SiegeWorkshop).get_queue_summary()
	if b is Castle:
		return (b as Castle).get_queue_summary()
	if b is Market:
		return "Obchod / směna"
	if b is Mill:
		return "Sklad jídla"
	if b is Dock:
		return (b as Dock).get_queue_summary()
	if b is LumberCamp:
		return "Sklad dřeva"
	if b is MiningCamp:
		return "Sklad zlata / kamene"
	if b is House:
		return "Obydlí"
	if b is WatchTower:
		var tg := GarrisonController.of(b)
		return tg.summary_line() if tg else "Obrana"
	if b is Gate or b is WallSegment:
		return "Obrana"
	return "Budova"


func _farm_info_line(farm: Farm) -> String:
	var state_cz := "—"
	match farm.farm_state:
		"sown":
			state_cz = "osetá"
		"ripe":
			state_cz = "zralá"
		"empty":
			state_cz = "prázdná"
		_:
			state_cz = farm.farm_state
	var stock := maxi(farm.amount_remaining, 0)
	return "Zásoba: %d J · stav: %s" % [stock, state_cz]
