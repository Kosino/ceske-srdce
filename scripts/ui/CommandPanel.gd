extends PanelContainer
class_name CommandPanel
## Bottom-left command strip (AoE-like HUD). Context: villager builds / building trains.

const BUILD_BUTTONS := [
	{"id": "house", "name": "Dům"},
	{"id": "lumber_camp", "name": "Pila"},
	{"id": "mining_camp", "name": "Důlní tábor"},
	{"id": "mill", "name": "Mlýn"},
	{"id": "barracks", "name": "Kasárna"},
	{"id": "palisade", "name": "Palisáda"},
	{"id": "stone_wall", "name": "Zeď"},
	{"id": "gate", "name": "Brána"},
	{"id": "watch_tower", "name": "Věž"},
	{"id": "archery_range", "name": "Střelnice"},
	{"id": "blacksmith", "name": "Kovárna"},
	{"id": "stable", "name": "Stáj"},
	{"id": "castle", "name": "Hrad"},
	{"id": "monastery", "name": "Klášter"},
	{"id": "market", "name": "Tržiště"},
	{"id": "university", "name": "Univerzita"},
	{"id": "siege_workshop", "name": "Obléhací dílna"},
]

@onready var age_label: Label = %AgeLabel
@onready var research_button: Button = %ResearchAgeButton
@onready var command_vbox: VBoxContainer = $CommandMargin/CommandVBox
@onready var train_row: HBoxContainer = $CommandMargin/CommandVBox/TrainRow
@onready var train_soldier: Button = $CommandMargin/CommandVBox/TrainRow/TrainSoldier
@onready var train_spearman: Button = $CommandMargin/CommandVBox/TrainRow/TrainSpearman
@onready var train_archer: Button = $CommandMargin/CommandVBox/TrainRow/TrainArcher
@onready var train_villager: Button = $CommandMargin/CommandVBox/TrainRow/TrainVillager

var _formation_buttons: Dictionary = {} # kind -> Button
var _build_buttons: Dictionary = {} # building_id -> Button
var _tech_buttons: Dictionary = {} # tech_id -> Button
var _uni_tech_buttons: Dictionary = {} # tech_id -> Button
var _cavalry_buttons: Dictionary = {} # unit_id -> Button
var _siege_buttons: Dictionary = {} # unit_id -> Button
var _unique_button: Button
var _monk_button: Button
var _market_button: Button
var _build_row: HBoxContainer
var _tech_row: HBoxContainer
var _uni_tech_row: HBoxContainer
var _cavalry_row: HBoxContainer
var _siege_row: HBoxContainer
var _unique_row: HBoxContainer
var _monk_row: HBoxContainer
var _market_row: HBoxContainer
var _research_refresh_accum: float = 0.0
var _smith_connected: Blacksmith = null
var _uni_connected: University = null


func _ready() -> void:
	add_to_group("hud_command_panel")
	SelectionManager.selection_changed.connect(_on_context_changed)
	SelectionManager.building_selection_changed.connect(_on_building_changed)
	SelectionManager.formation_changed.connect(_refresh_formation_buttons)
	GameManager.age_changed.connect(_refresh_age_ui)
	GameManager.tech_researched.connect(_on_tech_researched)
	GameManager.resources_changed.connect(_refresh_all_tech_buttons)
	_ensure_formation_row()
	_ensure_build_row()
	_ensure_tech_row()
	_ensure_uni_tech_row()
	_refresh_age_ui()
	_refresh_formation_buttons(SelectionManager.formation)
	_refresh_context_ui()


func _process(delta: float) -> void:
	_research_refresh_accum += delta
	if _research_refresh_accum < 0.2:
		return
	_research_refresh_accum = 0.0
	_refresh_research_button()
	_refresh_build_costs()
	_refresh_all_tech_buttons()
	# Keep SelectionInfo research timer fresh while research building selected.
	var sel := SelectionManager.selected_building
	if sel is Blacksmith or sel is University:
		SelectionManager.building_selection_changed.emit(sel)


func _on_context_changed(_units: Array) -> void:
	_refresh_context_ui()


func _on_building_changed(_building: Node) -> void:
	_connect_smith_signal(_building as Blacksmith)
	_connect_uni_signal(_building as University)
	_refresh_context_ui()


func _on_tech_researched(_team: int, _tech_id: String) -> void:
	_refresh_all_tech_buttons()


func _refresh_all_tech_buttons(_a = null, _b = null) -> void:
	_refresh_tech_buttons()
	_refresh_uni_tech_buttons()


func _ensure_formation_row() -> void:
	if command_vbox == null or command_vbox.has_node("FormationRow"):
		return
	var row := HBoxContainer.new()
	row.name = "FormationRow"
	row.add_theme_constant_override("separation", 6)
	var stop_i := command_vbox.get_node_or_null("StopButton")
	var insert_at := stop_i.get_index() + 1 if stop_i else command_vbox.get_child_count()
	command_vbox.add_child(row)
	command_vbox.move_child(row, insert_at)
	for kind in [FormationData.LINE, FormationData.SCATTERED, FormationData.BOX]:
		var btn := Button.new()
		btn.name = "Formation_%s" % kind
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.text = FormationData.display_name(kind)
		btn.pressed.connect(_on_formation_pressed.bind(kind))
		row.add_child(btn)
		_formation_buttons[kind] = btn


func _ensure_build_row() -> void:
	if command_vbox == null or command_vbox.has_node("BuildRow"):
		_build_row = command_vbox.get_node_or_null("BuildRow") as HBoxContainer
		return
	_build_row = HBoxContainer.new()
	_build_row.name = "BuildRow"
	_build_row.add_theme_constant_override("separation", 4)
	_build_row.visible = false
	# Insert before TrainRow.
	var train_i := train_row.get_index() if train_row else command_vbox.get_child_count()
	command_vbox.add_child(_build_row)
	command_vbox.move_child(_build_row, train_i)
	for def in BUILD_BUTTONS:
		var bid: String = def["id"]
		var btn := Button.new()
		btn.name = "Build_%s" % bid
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_build_pressed.bind(bid))
		_build_row.add_child(btn)
		_build_buttons[bid] = btn
	_refresh_build_costs()


func _refresh_context_ui() -> void:
	var villager_sel := SelectionManager.has_selected_villager()
	if _build_row:
		_build_row.visible = villager_sel
	if villager_sel:
		_refresh_build_costs()

	var b := SelectionManager.selected_building
	var is_smith := b is Blacksmith and (b as Blacksmith).is_complete
	var is_university := b is University and (b as University).is_complete
	var is_stable := b is Stable and (b as Stable).is_complete
	var is_siege := b is SiegeWorkshop and (b as SiegeWorkshop).is_complete
	var is_castle := b is Castle and (b as Castle).is_complete
	if _tech_row:
		_tech_row.visible = is_smith
	if is_smith:
		_refresh_tech_buttons()
	_ensure_uni_tech_row()
	if _uni_tech_row:
		_uni_tech_row.visible = is_university
	if is_university:
		_refresh_uni_tech_buttons()
	_ensure_cavalry_row()
	if _cavalry_row:
		_cavalry_row.visible = is_stable
	if is_stable:
		_refresh_cavalry_buttons()
	_ensure_siege_row()
	if _siege_row:
		_siege_row.visible = is_siege
	if is_siege:
		_refresh_siege_buttons()
	_ensure_unique_row()
	if _unique_row:
		_unique_row.visible = is_castle
	if is_castle:
		_refresh_unique_button()
	var is_monastery := b is Monastery and (b as Monastery).is_complete
	_ensure_monk_row()
	if _monk_row:
		_monk_row.visible = is_monastery
	if is_monastery:
		_refresh_monk_button()
	var is_market := b is Market and (b as Market).is_complete
	_ensure_market_row()
	if _market_row:
		_market_row.visible = is_market

	var show_train := b != null and is_instance_valid(b) and not is_smith and not is_university
	if train_row:
		train_row.visible = show_train
	if not show_train:
		return
	var is_hall := b is DropOff or b.is_in_group("player_town_hall")
	var is_barracks := b is Barracks
	var is_archery := b is ArcheryRange
	if train_villager:
		train_villager.visible = is_hall
	if train_soldier:
		train_soldier.visible = is_barracks
	if train_spearman:
		train_spearman.visible = is_barracks
	if train_archer:
		train_archer.visible = is_archery
	# Hide generic train buttons when Stable/Siege/Castle/Monastery/Market selected.
	if is_stable or is_siege or is_castle or is_monastery or is_market:
		if train_villager:
			train_villager.visible = false
		if train_soldier:
			train_soldier.visible = false
		if train_spearman:
			train_spearman.visible = false
		if train_archer:
			train_archer.visible = false


func _refresh_build_costs() -> void:
	for def in BUILD_BUTTONS:
		var bid: String = def["id"]
		var btn: Button = _build_buttons.get(bid)
		if btn == null:
			continue
		var base: Dictionary = BuildingPlacer.COSTS.get(bid, {})
		var cost := GameManager.adjust_building_cost(base, 0)
		var cost_txt := CivData.format_cost(cost)
		btn.text = "%s\n%s" % [def["name"], cost_txt]
		var unlocked := GameManager.is_building_unlocked(bid)
		var prereq_ok := true
		if bid == "stable" or bid == "siege_workshop":
			var placer := get_tree().get_first_node_in_group("building_placer") as BuildingPlacer
			prereq_ok = placer != null and placer._prereq_met(bid)
		btn.disabled = not unlocked or not prereq_ok
		if not unlocked:
			var need_age := AgeData.building_unlock_age(bid)
			btn.tooltip_text = "Zamčeno do věku %s (%d)" % [AgeData.age_name(need_age), need_age]
		elif not prereq_ok:
			btn.tooltip_text = (
				"Vyžaduje dokončenou Univerzitu" if bid == "siege_workshop"
				else "Vyžaduje dokončenou Kasárnu"
			)
		else:
			btn.tooltip_text = "Cena (civ): %s" % cost_txt


func _on_build_pressed(building_id: String) -> void:
	if not SelectionManager.has_selected_villager():
		NotificationManager.show_message("Vyber vesničana ke stavbě.")
		return
	var placer := get_tree().get_first_node_in_group("building_placer") as BuildingPlacer
	if placer:
		placer.begin_place(building_id)


func _on_formation_pressed(kind: String) -> void:
	SelectionManager.set_formation(kind)
	NotificationManager.show_message("Formace: %s" % FormationData.display_name(kind))
	_refresh_formation_buttons(kind)


func _refresh_formation_buttons(_kind: String = "") -> void:
	var current := SelectionManager.formation
	for kind in _formation_buttons.keys():
		var btn: Button = _formation_buttons[kind]
		btn.modulate = Color(0.75, 1.0, 0.75) if kind == current else Color.WHITE


func _refresh_age_ui() -> void:
	if age_label:
		age_label.text = "Věk: %s (%d)" % [GameManager.get_age_name(), GameManager.current_age]
	_refresh_research_button()
	_refresh_build_costs()


func _refresh_research_button() -> void:
	if age_label:
		age_label.text = "Věk: %s (%d)" % [GameManager.get_age_name(), GameManager.current_age]
	if research_button == null:
		return
	if GameManager.current_age >= AgeData.MAX_AGE:
		research_button.text = "Max věk"
		research_button.disabled = true
		return
	var hall := get_tree().get_first_node_in_group("player_town_hall") as DropOff
	if hall != null and hall.researching_age:
		research_button.text = "Výzkum %.0fs" % maxf(hall.research_remaining, 0.0)
		research_button.disabled = true
		return
	var target := AgeData.next_age(GameManager.current_age)
	research_button.text = "Výzkum: %s" % AgeData.age_name(target)
	research_button.disabled = false


func _on_stop_pressed() -> void:
	SelectionManager.issue_stop()
	NotificationManager.show_message("Stop")


func _on_research_age_pressed() -> void:
	var hall := get_tree().get_first_node_in_group("player_town_hall") as DropOff
	if hall == null:
		NotificationManager.show_message("Nemáš radnici.")
		return
	hall.start_age_research()
	_refresh_research_button()


func _on_train_soldier_pressed() -> void:
	_barracks_enqueue("soldier")


func _on_train_spearman_pressed() -> void:
	_barracks_enqueue("spearman")


func _on_train_archer_pressed() -> void:
	var range_b := SelectionManager.selected_building as ArcheryRange
	if range_b == null:
		range_b = get_tree().get_first_node_in_group("archery_ranges") as ArcheryRange
	if range_b == null:
		NotificationManager.show_message("Nejdřív postav Střelnici.")
		return
	range_b.enqueue_unit("archer")


func _on_train_villager_pressed() -> void:
	var hall := SelectionManager.selected_building as DropOff
	if hall == null:
		hall = get_tree().get_first_node_in_group("player_town_hall") as DropOff
	if hall == null:
		NotificationManager.show_message("Nemáš radnici.")
		return
	hall.enqueue_villager()


func _barracks_enqueue(unit_id: String) -> void:
	var barracks := SelectionManager.selected_building as Barracks
	if barracks == null:
		barracks = get_tree().get_first_node_in_group("barracks") as Barracks
	if barracks == null:
		NotificationManager.show_message("Nejdřív postav Kasárnu.")
		return
	barracks.enqueue_unit(unit_id)


func _ensure_tech_row() -> void:
	if command_vbox == null or command_vbox.has_node("TechRow"):
		_tech_row = command_vbox.get_node_or_null("TechRow") as HBoxContainer
		return
	_tech_row = HBoxContainer.new()
	_tech_row.name = "TechRow"
	_tech_row.add_theme_constant_override("separation", 4)
	_tech_row.visible = false
	command_vbox.add_child(_tech_row)
	for tech_id in TechData.BLACKSMITH_ORDER:
		var btn := Button.new()
		btn.name = "Tech_%s" % tech_id
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_tech_pressed.bind(tech_id))
		_tech_row.add_child(btn)
		_tech_buttons[tech_id] = btn
	_refresh_tech_buttons()


func _refresh_tech_buttons(_a = null, _b = null) -> void:
	if _tech_row == null:
		return
	var smith := SelectionManager.selected_building as Blacksmith
	for tech_id in TechData.BLACKSMITH_ORDER:
		var btn: Button = _tech_buttons.get(tech_id)
		if btn == null:
			continue
		var def := TechData.tech_def(tech_id)
		var cost_txt := CivData.format_cost(def.get("cost", {}))
		var done := GameManager.has_tech(0, tech_id)
		btn.text = "%s\n%s" % [TechData.tech_name(tech_id), cost_txt]
		if done:
			btn.disabled = true
			btn.modulate = Color(0.55, 0.55, 0.55)
			btn.tooltip_text = "Už vyzkoumáno"
		elif smith == null or not smith.can_enqueue(tech_id):
			btn.disabled = true
			btn.modulate = Color(0.65, 0.65, 0.65)
			if smith and smith.is_researching():
				btn.tooltip_text = "Fronta plná (1)"
			else:
				btn.tooltip_text = "Nedostatek surovin / nelze"
		else:
			btn.disabled = false
			btn.modulate = Color.WHITE
			btn.tooltip_text = cost_txt


func _on_tech_pressed(tech_id: String) -> void:
	var smith := SelectionManager.selected_building as Blacksmith
	if smith == null:
		NotificationManager.show_message("Vyber Kovárnu.")
		return
	smith.enqueue_tech(tech_id)
	_refresh_tech_buttons()


func _connect_smith_signal(smith: Blacksmith) -> void:
	if _smith_connected and is_instance_valid(_smith_connected):
		if _smith_connected.research_changed.is_connected(_on_smith_research_changed):
			_smith_connected.research_changed.disconnect(_on_smith_research_changed)
	_smith_connected = smith
	if smith and not smith.research_changed.is_connected(_on_smith_research_changed):
		smith.research_changed.connect(_on_smith_research_changed)


func _on_smith_research_changed() -> void:
	_refresh_tech_buttons()
	if SelectionManager.selected_building is Blacksmith:
		SelectionManager.building_selection_changed.emit(SelectionManager.selected_building)


func _ensure_uni_tech_row() -> void:
	if command_vbox == null:
		return
	if command_vbox.has_node("UniTechRow"):
		_uni_tech_row = command_vbox.get_node_or_null("UniTechRow") as HBoxContainer
		for tech_id in TechData.UNIVERSITY_ORDER:
			_uni_tech_buttons[tech_id] = _uni_tech_row.get_node_or_null("UniTech_%s" % tech_id) as Button
		return
	_uni_tech_row = HBoxContainer.new()
	_uni_tech_row.name = "UniTechRow"
	_uni_tech_row.add_theme_constant_override("separation", 4)
	_uni_tech_row.visible = false
	command_vbox.add_child(_uni_tech_row)
	for tech_id in TechData.UNIVERSITY_ORDER:
		var btn := Button.new()
		btn.name = "UniTech_%s" % tech_id
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_uni_tech_pressed.bind(tech_id))
		_uni_tech_row.add_child(btn)
		_uni_tech_buttons[tech_id] = btn
	_refresh_uni_tech_buttons()


func _refresh_uni_tech_buttons(_a = null, _b = null) -> void:
	if _uni_tech_row == null:
		return
	var uni := SelectionManager.selected_building as University
	for tech_id in TechData.UNIVERSITY_ORDER:
		var btn: Button = _uni_tech_buttons.get(tech_id)
		if btn == null:
			continue
		var def := TechData.tech_def(tech_id)
		var cost_txt := CivData.format_cost(def.get("cost", {}))
		var done := GameManager.has_tech(0, tech_id)
		btn.text = "%s\n%s" % [TechData.tech_name(tech_id), cost_txt]
		if done:
			btn.disabled = true
			btn.modulate = Color(0.55, 0.55, 0.55)
			btn.tooltip_text = "Už vyzkoumáno"
		elif uni == null or not uni.can_enqueue(tech_id):
			btn.disabled = true
			btn.modulate = Color(0.65, 0.65, 0.65)
			if uni and uni.is_researching():
				btn.tooltip_text = "Fronta plná (1)"
			else:
				btn.tooltip_text = "Nedostatek surovin / nelze"
		else:
			btn.disabled = false
			btn.modulate = Color.WHITE
			btn.tooltip_text = cost_txt


func _on_uni_tech_pressed(tech_id: String) -> void:
	var uni := SelectionManager.selected_building as University
	if uni == null:
		NotificationManager.show_message("Vyber Univerzitu.")
		return
	uni.enqueue_tech(tech_id)
	_refresh_uni_tech_buttons()


func _connect_uni_signal(uni: University) -> void:
	if _uni_connected and is_instance_valid(_uni_connected):
		if _uni_connected.research_changed.is_connected(_on_uni_research_changed):
			_uni_connected.research_changed.disconnect(_on_uni_research_changed)
	_uni_connected = uni
	if uni and not uni.research_changed.is_connected(_on_uni_research_changed):
		uni.research_changed.connect(_on_uni_research_changed)


func _on_uni_research_changed() -> void:
	_refresh_uni_tech_buttons()
	if SelectionManager.selected_building is University:
		SelectionManager.building_selection_changed.emit(SelectionManager.selected_building)


## Test helpers
func get_build_button(building_id: String) -> Button:
	return _build_buttons.get(building_id) as Button


func get_tech_button(tech_id: String) -> Button:
	return _tech_buttons.get(tech_id) as Button


func get_uni_tech_button(tech_id: String) -> Button:
	return _uni_tech_buttons.get(tech_id) as Button


func is_build_row_visible() -> bool:
	return _build_row != null and _build_row.visible

func is_tech_row_visible() -> bool:
	return _tech_row != null and _tech_row.visible


func is_uni_tech_row_visible() -> bool:
	return _uni_tech_row != null and _uni_tech_row.visible


func _ensure_cavalry_row() -> void:
	if command_vbox == null:
		return
	if command_vbox.has_node("CavalryRow"):
		_cavalry_row = command_vbox.get_node_or_null("CavalryRow") as HBoxContainer
		return
	_cavalry_row = HBoxContainer.new()
	_cavalry_row.name = "CavalryRow"
	_cavalry_row.add_theme_constant_override("separation", 4)
	_cavalry_row.visible = false
	command_vbox.add_child(_cavalry_row)
	for unit_id in ["light_cavalry", "knight"]:
		var btn := Button.new()
		btn.name = "Train_%s" % unit_id
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_cavalry_train_pressed.bind(unit_id))
		_cavalry_row.add_child(btn)
		_cavalry_buttons[unit_id] = btn
	_refresh_cavalry_buttons()


func _refresh_cavalry_buttons() -> void:
	if _cavalry_row == null:
		return
	for unit_id in ["light_cavalry", "knight"]:
		var btn: Button = _cavalry_buttons.get(unit_id)
		if btn == null:
			continue
		var def: Dictionary = Stable.UNIT_DEFS.get(unit_id, {})
		var cost_txt := CivData.format_cost(def.get("cost", {}))
		btn.text = "%s\n%s" % [
			"Lehký jezdec" if unit_id == "light_cavalry" else "Rytíř",
			cost_txt,
		]
		var unlocked := GameManager.is_unit_unlocked(unit_id)
		btn.disabled = not unlocked
		btn.modulate = Color.WHITE if unlocked else Color(0.6, 0.6, 0.6)
		if unlocked:
			btn.tooltip_text = cost_txt
		else:
			var need := AgeData.unit_unlock_age(unit_id)
			btn.tooltip_text = "Zamčeno do věku %s (%d)" % [AgeData.age_name(need), need]


func _on_cavalry_train_pressed(unit_id: String) -> void:
	var stable := SelectionManager.selected_building as Stable
	if stable == null:
		NotificationManager.show_message("Vyber Stáj.")
		return
	if not GameManager.is_unit_unlocked(unit_id):
		var need := AgeData.unit_unlock_age(unit_id)
		NotificationManager.show_message(
			"Zamčeno do věku %s (%d)." % [AgeData.age_name(need), need]
		)
		_refresh_cavalry_buttons()
		return
	stable.enqueue_unit(unit_id)
	_refresh_cavalry_buttons()


func _ensure_siege_row() -> void:
	if command_vbox == null:
		return
	if command_vbox.has_node("SiegeRow"):
		_siege_row = command_vbox.get_node_or_null("SiegeRow") as HBoxContainer
		return
	_siege_row = HBoxContainer.new()
	_siege_row.name = "SiegeRow"
	_siege_row.add_theme_constant_override("separation", 4)
	_siege_row.visible = false
	command_vbox.add_child(_siege_row)
	for unit_id in ["ram", "trebuchet"]:
		var btn := Button.new()
		btn.name = "Train_%s" % unit_id
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.pressed.connect(_on_siege_train_pressed.bind(unit_id))
		_siege_row.add_child(btn)
		_siege_buttons[unit_id] = btn
	_refresh_siege_buttons()


func _refresh_siege_buttons() -> void:
	if _siege_row == null:
		return
	for unit_id in ["ram", "trebuchet"]:
		var btn: Button = _siege_buttons.get(unit_id)
		if btn == null:
			continue
		var def: Dictionary = SiegeWorkshop.UNIT_DEFS.get(unit_id, {})
		var cost_txt := CivData.format_cost(def.get("cost", {}))
		btn.text = "%s\n%s" % [
			"Beranidlo" if unit_id == "ram" else "Trebuchet",
			cost_txt,
		]
		var unlocked := GameManager.is_unit_unlocked(unit_id)
		btn.disabled = not unlocked
		btn.modulate = Color.WHITE if unlocked else Color(0.6, 0.6, 0.6)
		if unlocked:
			btn.tooltip_text = cost_txt
		else:
			var need := AgeData.unit_unlock_age(unit_id)
			btn.tooltip_text = "Zamčeno do věku %s (%d)" % [AgeData.age_name(need), need]


func _on_siege_train_pressed(unit_id: String) -> void:
	var shop := SelectionManager.selected_building as SiegeWorkshop
	if shop == null:
		NotificationManager.show_message("Vyber Obléhací dílnu.")
		return
	if not GameManager.is_unit_unlocked(unit_id):
		var need := AgeData.unit_unlock_age(unit_id)
		NotificationManager.show_message(
			"Zamčeno do věku %s (%d)." % [AgeData.age_name(need), need]
		)
		_refresh_siege_buttons()
		return
	shop.enqueue_unit(unit_id)
	_refresh_siege_buttons()


func _ensure_unique_row() -> void:
	if command_vbox == null:
		return
	if command_vbox.has_node("UniqueRow"):
		_unique_row = command_vbox.get_node_or_null("UniqueRow") as HBoxContainer
		_unique_button = _unique_row.get_node_or_null("TrainUnique") as Button if _unique_row else null
		return
	_unique_row = HBoxContainer.new()
	_unique_row.name = "UniqueRow"
	_unique_row.add_theme_constant_override("separation", 4)
	_unique_row.visible = false
	command_vbox.add_child(_unique_row)
	_unique_button = Button.new()
	_unique_button.name = "TrainUnique"
	_unique_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_unique_button.pressed.connect(_on_unique_train_pressed)
	_unique_row.add_child(_unique_button)
	_refresh_unique_button()


func _refresh_unique_button() -> void:
	if _unique_button == null:
		return
	var uid := CivData.unique_unit_id(GameManager.player_civ)
	var def := CivData.unique_unit_def(uid)
	var cost_txt := CivData.format_cost(def.get("cost", {}))
	_unique_button.text = "%s\n%s" % [CivData.unique_unit_label(uid), cost_txt]
	var unlocked := GameManager.is_unit_unlocked(uid)
	_unique_button.disabled = not unlocked
	_unique_button.modulate = Color.WHITE if unlocked else Color(0.6, 0.6, 0.6)
	if unlocked:
		_unique_button.tooltip_text = cost_txt
	else:
		var need := AgeData.unit_unlock_age(uid)
		_unique_button.tooltip_text = "Zamčeno do věku %s (%d)" % [AgeData.age_name(need), need]


func _on_unique_train_pressed() -> void:
	var castle := SelectionManager.selected_building as Castle
	if castle == null:
		NotificationManager.show_message("Vyber Hrad.")
		return
	castle.enqueue_unique()
	_refresh_unique_button()


func _ensure_monk_row() -> void:
	if command_vbox == null:
		return
	if command_vbox.has_node("MonkRow"):
		_monk_row = command_vbox.get_node_or_null("MonkRow") as HBoxContainer
		_monk_button = _monk_row.get_node_or_null("TrainMonk") as Button if _monk_row else null
		return
	_monk_row = HBoxContainer.new()
	_monk_row.name = "MonkRow"
	_monk_row.visible = false
	command_vbox.add_child(_monk_row)
	_monk_button = Button.new()
	_monk_button.name = "TrainMonk"
	_monk_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_monk_button.pressed.connect(_on_monk_train_pressed)
	_monk_row.add_child(_monk_button)
	_refresh_monk_button()


func _refresh_monk_button() -> void:
	if _monk_button == null:
		return
	_monk_button.text = "Mnich\n100 Z"
	var unlocked := GameManager.is_unit_unlocked("monk")
	_monk_button.disabled = not unlocked
	_monk_button.tooltip_text = "100 Zlato" if unlocked else "Zamčeno do věku Husitství"


func _on_monk_train_pressed() -> void:
	var mon := SelectionManager.selected_building as Monastery
	if mon == null:
		NotificationManager.show_message("Vyber Klášter.")
		return
	mon.enqueue_monk()
	_refresh_monk_button()


func _ensure_market_row() -> void:
	if command_vbox == null:
		return
	if command_vbox.has_node("MarketRow"):
		_market_row = command_vbox.get_node_or_null("MarketRow") as HBoxContainer
		_market_button = _market_row.get_node_or_null("TradeWood") as Button if _market_row else null
		return
	_market_row = HBoxContainer.new()
	_market_row.name = "MarketRow"
	_market_row.visible = false
	command_vbox.add_child(_market_row)
	_market_button = Button.new()
	_market_button.name = "TradeWood"
	_market_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_market_button.text = "Prodej dřeva\n100 D → Zlato"
	_market_button.pressed.connect(_on_market_trade_pressed)
	_market_row.add_child(_market_button)


func _on_market_trade_pressed() -> void:
	var mkt := SelectionManager.selected_building as Market
	if mkt == null:
		NotificationManager.show_message("Vyber Tržiště.")
		return
	mkt.trade_wood_for_gold(100)
