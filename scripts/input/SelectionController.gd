extends Node2D
class_name SelectionController

@export var box_threshold: float = 8.0

var _dragging: bool = false
var _drag_start_screen: Vector2 = Vector2.ZERO
var _drag_current_screen: Vector2 = Vector2.ZERO


func _ready() -> void:
	add_to_group("selection_controller")
	z_index = 200


func _unhandled_input(event: InputEvent) -> void:
	var placer := get_tree().get_first_node_in_group("building_placer") as BuildingPlacer
	if placer and placer.placing_type != "":
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_dragging = true
				_drag_start_screen = mb.position
				_drag_current_screen = mb.position
			else:
				if _dragging:
					_finish_left_select(mb.position)
				_dragging = false
				queue_redraw()
			get_viewport().set_input_as_handled()
		elif mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			_issue_right_click_command()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _dragging:
		_drag_current_screen = (event as InputEventMouseMotion).position
		queue_redraw()


func _draw() -> void:
	if not _dragging:
		return
	var a := _screen_to_local(_drag_start_screen)
	var b := _screen_to_local(_drag_current_screen)
	var rect := Rect2(a, b - a).abs()
	draw_rect(rect, Color(0.2, 0.7, 1.0, 0.15), true)
	draw_rect(rect, Color(0.4, 0.85, 1.0, 0.9), false, 1.5)


func _finish_left_select(end_screen: Vector2) -> void:
	var start_world := _screen_to_world(_drag_start_screen)
	var end_world := _screen_to_world(end_screen)
	if _drag_start_screen.distance_to(end_screen) < box_threshold:
		_single_select_at(end_world)
	else:
		_box_select(Rect2(start_world, end_world - start_world).abs())


func _single_select_at(world_pos: Vector2) -> void:
	var best: Unit = null
	var best_dist := 28.0
	for node in get_tree().get_nodes_in_group("player_units"):
		if not (node is Unit):
			continue
		var unit := node as Unit
		var d := unit.global_position.distance_to(world_pos)
		if d < best_dist:
			best_dist = d
			best = unit
	if best:
		SelectionManager.select_single(best)
	else:
		SelectionManager.clear_selection()


func _box_select(world_rect: Rect2) -> void:
	var picked: Array = []
	for node in get_tree().get_nodes_in_group("player_units"):
		if node is Unit and world_rect.has_point((node as Unit).global_position):
			picked.append(node)
	if picked.is_empty():
		SelectionManager.clear_selection()
	else:
		SelectionManager.select_multiple(picked)


func _issue_right_click_command() -> void:
	if SelectionManager.selected_units.is_empty():
		return
	var world_pos := get_global_mouse_position()
	var enemy := _find_enemy_at(world_pos)
	if enemy:
		SelectionManager.issue_attack(enemy)
		NotificationManager.show_message("Útok!")
		return
	var resource := _find_resource_at(world_pos)
	if resource:
		SelectionManager.issue_gather(resource)
		NotificationManager.show_message("Sklizeň: %s" % resource.resource_type)
		return
	var site := _find_unfinished_building_at(world_pos)
	if site:
		SelectionManager.issue_build(site)
		NotificationManager.show_message("Stavba: %s" % site.display_name)
		return
	SelectionManager.issue_move(world_pos)


func _find_resource_at(world_pos: Vector2) -> ResourceNode:
	var best: ResourceNode = null
	var best_dist := 40.0
	for node in get_tree().get_nodes_in_group("resources"):
		if not (node is ResourceNode):
			continue
		var res := node as ResourceNode
		if res.is_depleted():
			continue
		var d := res.global_position.distance_to(world_pos)
		if d < best_dist + res.gather_radius:
			best_dist = d
			best = res
	return best


func _find_unfinished_building_at(world_pos: Vector2) -> Building:
	var best: Building = null
	var best_dist := 40.0
	for node in get_tree().get_nodes_in_group("player_buildings"):
		if not (node is Building):
			continue
		var b := node as Building
		if b.is_complete:
			continue
		var radius := b.footprint.length() * 0.35
		var d := b.global_position.distance_to(world_pos)
		if d < best_dist + radius:
			best_dist = d
			best = b
	return best


func _find_enemy_at(world_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist := 40.0
	for group_name in ["enemy_units", "enemy_buildings", "enemy_town_hall"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if not (node is Node2D):
				continue
			var n := node as Node2D
			var radius := 24.0
			if n is DropOff:
				radius = (n as DropOff).dropoff_radius
			elif n is Building:
				radius = (n as Building).footprint.length() * 0.3
			var d := n.global_position.distance_to(world_pos)
			if d < best_dist + radius:
				best_dist = d
				best = n
	return best


func _screen_to_world(screen_pos: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * screen_pos


func _screen_to_local(screen_pos: Vector2) -> Vector2:
	return to_local(_screen_to_world(screen_pos))