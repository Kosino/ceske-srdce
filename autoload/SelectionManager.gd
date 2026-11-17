extends Node

signal selection_changed(units: Array)

var selected_units: Array[Node] = []

func select_single(unit: Node) -> void:
	clear_selection()
	if unit and is_instance_valid(unit):
		selected_units.append(unit)
	selection_changed.emit(selected_units)

func select_multiple(units: Array) -> void:
	clear_selection()
	for u in units:
		if u and is_instance_valid(u):
			selected_units.append(u)
	selection_changed.emit(selected_units)

func clear_selection() -> void:
	selected_units.clear()
	selection_changed.emit(selected_units)
