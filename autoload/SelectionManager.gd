extends Node

signal selection_changed(units: Array)

var selected_units: Array[Node] = []


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
	for u in selected_units:
		if is_instance_valid(u) and u.has_method("command_move"):
			u.command_move(world_pos)


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