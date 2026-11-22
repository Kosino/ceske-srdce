extends PanelContainer
class_name CommandPanel
## Bottom-left command strip (AoE-like HUD). Context: villager builds / building trains.

const BUILD_BUTTONS := [
	{"id": "house", "name": "Dům"},
	{"id": "lumber_camp", "name": "Pila"},
	{"id": "mill", "name": "Mlýn"},
	{"id": "barracks", "name": "Kasárna"},
	{"id": "archery_range", "name": "Střelnice"},
	{"id": "blacksmith", "name": "Kovárna"},
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
var _build_row: HBoxContainer
var _research_refresh_accum: float = 0.0


func _ready() -> void:
	add_to_group("hud_command_panel")
	SelectionManager.selection_changed.connect(_on_context_changed)
	SelectionManager.building_selection_changed.connect(_on_building_changed)
	SelectionManager.formation_changed.connect(_refresh_formation_buttons)
	GameManager.age_changed.connect(_refresh_age_ui)
	_ensure_formation_row()
	_ensure_build_row()
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


func _on_context_changed(_units: Array) -> void:
	_refresh_context_ui()


func _on_building_changed(_building: Node) -> void:
	_refresh_context_ui()


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
	var show_train := b != null and is_instance_valid(b)
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
		btn.disabled = not unlocked
		if unlocked:
			btn.tooltip_text = "Cena (civ): %s" % cost_txt
		else:
			var need_age := AgeData.building_unlock_age(bid)
			btn.tooltip_text = "Zamčeno do věku %s (%d)" % [AgeData.age_name(need_age), need_age]


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


## Test helpers
func get_build_button(building_id: String) -> Button:
	return _build_buttons.get(building_id) as Button


func is_build_row_visible() -> bool:
	return _build_row != null and _build_row.visible
