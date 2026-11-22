extends Node

signal selection_changed(units: Array)
signal formation_changed(kind: String)

var selected_units: Array[Node] = []
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
	clear_selection()
	if unit and is_instance_valid(unit):
		_add(unit)
	selection_changed.emit(selected_units)


func select_multiple(units: Array) -> void:
	clear_selection()
	for u in units:
		if u and is_instance_valid(u):
			_add(u)
	selection_changed.emit(selected_units)


func clear_selection() -> void:
	for u in selected_units:
		if is_instance_valid(u) and u.has_method("set_selected"):
			u.set_selected(false)
	selected_units.clear()
	selection_changed.emit(selected_units)


func issue_move(world_pos: Vector2) -> void:
	var movers: Array[Unit] = []
	for u in selected_units:
		if is_instance_valid(u) and u is Unit and u.has_method("command_move"):
			movers.append(u as Unit)
	if movers.is_empty():
		return
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
	# AoE II: line axis is perpendicular to march; sort units along that axis to avoid crossing.
	var right := Vector2(-facing.y, facing.x)
	movers.sort_custom(func(a: Unit, b: Unit) -> bool:
		return a.global_position.dot(right) < b.global_position.dot(right)
	)
	var offs := FormationData.offsets(formation, movers.size(), facing)
	for i in movers.size():
		movers[i].command_move(world_pos + offs[i], slowest)


func issue_attack(target: Node2D) -> void:
	for u in selected_units:
		if is_instance_valid(u) and u.has_method("command_attack"):
			u.command_attack(target)


func issue_gather(resource: ResourceNode) -> void:
	if resource == null or not is_instance_valid(resource) or resource.is_depleted():
		return
	for u in selected_units:
		if is_instance_valid(u) and u is Villager:
			(u as Villager).assign_gather(resource)


func issue_build(building: Building) -> void:
	if building == null or not is_instance_valid(building) or building.is_complete:
		return
	for u in selected_units:
		if is_instance_valid(u) and u is Villager:
			(u as Villager).assign_build(building)


func issue_stop() -> void:
	for u in selected_units:
		if is_instance_valid(u) and u.has_method("command_stop"):
			u.command_stop()


func notify_unit_removed(unit: Node) -> void:
	if selected_units.has(unit):
		selected_units.erase(unit)
		selection_changed.emit(selected_units)


func _add(unit: Node) -> void:
	selected_units.append(unit)
	if unit.has_method("set_selected"):
		unit.set_selected(true)
