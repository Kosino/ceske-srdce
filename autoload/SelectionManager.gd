extends Node

signal selection_changed(units: Array)
signal building_selection_changed(building: Node)
signal formation_changed(kind: String)
signal resource_focus_changed(resource: ResourceNode)

var selected_units: Array[Node] = []
## Selected production building (Radnice / Kasárna / Střelnice) — AoE-like train UI.
var selected_building: Node = null
## Selected / hovered map resource — amount shown in SelectionInfo (no world labels).
var selected_resource: ResourceNode = null
var hovered_resource: ResourceNode = null
## Hovered fortification (wall/gate) — name/HP only while hovered.
var hovered_building: Building = null
## Current formation for group moves (AoE II style).
var formation: String = FormationData.LINE


func set_formation(kind: String) -> void:
	if kind != FormationData.LINE and kind != FormationData.SCATTERED and kind != FormationData.BOX:
		return
	if formation == kind:
		return
	formation = kind
	formation_changed.emit(formation)


func select_single(unit: Node) -> void:
	_clear_building()
	clear_resource_selection()
	clear_selection(false)
	if unit and is_instance_valid(unit):
		_add(unit)
		AudioManager.play_sfx("select")
	selection_changed.emit(selected_units)


func select_multiple(units: Array) -> void:
	_clear_building()
	clear_resource_selection()
	clear_selection(false)
	for u in units:
		if u and is_instance_valid(u):
			_add(u)
	if not selected_units.is_empty():
		AudioManager.play_sfx("select")
	selection_changed.emit(selected_units)


func select_building(building: Node) -> void:
	clear_selection(false)
	clear_resource_selection()
	_clear_building()
	if building and is_instance_valid(building):
		selected_building = building
		if building is Building:
			(building as Building).set_ui_selected(true)
		AudioManager.play_sfx("select")
	building_selection_changed.emit(selected_building)
	selection_changed.emit(selected_units)


func select_resource(resource: ResourceNode) -> void:
	clear_selection(false)
	_clear_building()
	clear_resource_selection()
	if resource and is_instance_valid(resource) and not resource.is_depleted():
		selected_resource = resource
		resource.set_resource_selected(true)
	resource_focus_changed.emit(selected_resource)
	selection_changed.emit(selected_units)


func set_hovered_resource(resource: ResourceNode) -> void:
	hovered_resource = resource if resource and is_instance_valid(resource) else null
	resource_focus_changed.emit(focused_resource())


func set_hovered_building(building: Building) -> void:
	if hovered_building == building:
		return
	if hovered_building != null and is_instance_valid(hovered_building):
		hovered_building.set_ui_hovered(false)
	hovered_building = building if building and is_instance_valid(building) else null
	if hovered_building != null:
		hovered_building.set_ui_hovered(true)


func notify_resource_amount_changed(resource: ResourceNode) -> void:
	if resource == selected_resource or resource == hovered_resource:
		resource_focus_changed.emit(focused_resource())


func focused_resource() -> ResourceNode:
	if selected_resource and is_instance_valid(selected_resource):
		return selected_resource
	if hovered_resource and is_instance_valid(hovered_resource):
		return hovered_resource
	return null


func clear_resource_selection() -> void:
	if selected_resource and is_instance_valid(selected_resource):
		selected_resource.set_resource_selected(false)
	selected_resource = null
	resource_focus_changed.emit(focused_resource())


func clear_selection(emit_building: bool = true) -> void:
	for u in selected_units:
		if is_instance_valid(u) and u.has_method("set_selected"):
			u.set_selected(false)
	selected_units.clear()
	if emit_building:
		_clear_building()
	selection_changed.emit(selected_units)


func _clear_building() -> void:
	if selected_building == null:
		return
	if selected_building is Building and is_instance_valid(selected_building):
		(selected_building as Building).set_ui_selected(false)
	selected_building = null
	building_selection_changed.emit(null)


func issue_move(world_pos: Vector2) -> void:
	var movers: Array[Unit] = []
	for u in selected_units:
		if is_instance_valid(u) and u is Unit and u.has_method("command_move"):
			movers.append(u as Unit)
	if movers.is_empty():
		return
	AudioManager.play_sfx("command")
	if movers.size() == 1:
		movers[0].command_move(world_pos)
		return
	var slowest := movers[0].speed
	var centroid := Vector2.ZERO
	for u in movers:
		slowest = minf(slowest, u.speed)
		centroid += u.global_position
	centroid /= float(movers.size())
	var facing := world_pos - centroid
	if facing.length_squared() < 0.0001:
		facing = Vector2.RIGHT
	else:
		facing = facing.normalized()
	var right := Vector2(-facing.y, facing.x)
	movers.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.global_position.dot(right) < b.global_position.dot(right)
	)
	var offs := FormationData.offsets(formation, movers.size(), facing)
	for i in movers.size():
		movers[i].command_move(world_pos + offs[i], slowest)


func issue_attack(target: Node2D) -> void:
	var any := false
	for u in selected_units:
		if is_instance_valid(u) and u.has_method("command_attack"):
			u.command_attack(target)
			any = true
	if any:
		AudioManager.play_sfx("command")


func issue_gather(resource: Node2D) -> void:
	if resource == null or not is_instance_valid(resource):
		return
	if not resource.has_method("is_depleted") or resource.call("is_depleted"):
		return
	if resource is Farm and not (resource as Farm).is_complete:
		return
	var any := false
	for u in selected_units:
		if is_instance_valid(u) and u is Villager:
			(u as Villager).assign_gather(resource)
			any = true
	if any:
		AudioManager.play_sfx("command")


func issue_build(building: Building) -> void:
	if building == null or not is_instance_valid(building) or building.is_complete:
		return
	var any := false
	for u in selected_units:
		if is_instance_valid(u) and u is Villager:
			(u as Villager).assign_build(building)
			any = true
	if any:
		AudioManager.play_sfx("command")


func issue_repair(building: Building) -> void:
	if building == null or not is_instance_valid(building) or not building.needs_repair():
		return
	var any := false
	for u in selected_units:
		if is_instance_valid(u) and u is Villager:
			(u as Villager).assign_repair(building)
			any = true
	if any:
		AudioManager.play_sfx("command")


func issue_stop() -> void:
	var any := false
	for u in selected_units:
		if is_instance_valid(u) and u.has_method("command_stop"):
			u.command_stop()
			any = true
	if any:
		AudioManager.play_sfx("command")


func notify_unit_removed(unit: Node) -> void:
	if selected_units.has(unit):
		selected_units.erase(unit)
		selection_changed.emit(selected_units)


func has_selected_villager() -> bool:
	for u in selected_units:
		if is_instance_valid(u) and u is Villager:
			return true
	return false


func _add(unit: Node) -> void:
	selected_units.append(unit)
	if unit.has_method("set_selected"):
		unit.set_selected(true)
