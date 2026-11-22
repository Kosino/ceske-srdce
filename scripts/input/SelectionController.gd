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
	elif event is InputEventMouseMotion:
		if _dragging:
			_drag_current_screen = (event as InputEventMouseMotion).position
			queue_redraw()
		else:
			_update_building_hover(get_global_mouse_position())


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
		return
	var building := _find_player_building_at(world_pos)
	if building:
		SelectionManager.select_building(building)
		return
	var resource := _find_resource_at(world_pos)
	if resource:
		SelectionManager.select_resource(resource)
		return
	SelectionManager.clear_selection()
	SelectionManager.clear_resource_selection()


func _find_player_building_at(world_pos: Vector2) -> Node:
	var best: Node = null
	var best_dist := 48.0
	for group_name in ["player_town_hall", "barracks", "archery_ranges", "player_buildings", "walls", "gates"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if not (node is Node2D):
				continue
			if node is Building and not (node as Building).is_complete:
				continue
			if "team" in node and int(node.get("team")) != 0:
				continue
			var radius := 36.0
			if node is DropOff:
				radius = (node as DropOff).dropoff_radius
			elif node is Building:
				radius = (node as Building).footprint.length() * 0.35
			var d := (node as Node2D).global_position.distance_to(world_pos)
			if d < best_dist + radius * 0.35:
				best_dist = d
				best = node
	return best


func _update_building_hover(world_pos: Vector2) -> void:
	var best: Building = null
	var best_dist := 36.0
	for group_name in ["walls", "gates"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if not (node is Building):
				continue
			var b := node as Building
			if b.team != 0 or not b.is_complete:
				continue
			var radius := b.footprint.length() * 0.35
			var d := b.global_position.distance_to(world_pos)
			if d < best_dist + radius * 0.3:
				best_dist = d
				best = b
	SelectionManager.set_hovered_building(best)


func _box_select(world_rect: Rect2) -> void:
	var picked: Array = []
	for node in get_tree().get_nodes_in_group("player_units"):
		if node is Unit and world_rect.has_point((node as Unit).global_position):
			picked.append(node)
	if picked.is_empty():
		SelectionManager.clear_selection()
		SelectionManager.clear_resource_selection()
	else:
		SelectionManager.select_multiple(picked)


func _issue_right_click_command() -> void:
	if SelectionManager.selected_units.is_empty():
		return
	var world_pos := get_global_mouse_position()
	var enemy := _find_enemy_at(world_pos)
	if enemy:
		SelectionManager.issue_attack(enemy)
		NotificationManager.show_message("Útok!" if not _has_selected_monk() else "Konverze!")
		return
	# Monk heal: RMB on damaged friendly unit.
	if _has_selected_monk():
		var ally := _find_damaged_friendly_unit_at(world_pos)
		if ally:
			for u in SelectionManager.selected_units:
				if u is Monk and is_instance_valid(u):
					(u as Monk).assign_heal(ally)
			NotificationManager.show_message("Léčení!")
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
	var repair := _find_damaged_own_building_at(world_pos)
	if repair:
		SelectionManager.issue_repair(repair)
		NotificationManager.show_message("Oprava: %s" % repair.display_name)
		return
	SelectionManager.issue_move(world_pos)


func _has_selected_monk() -> bool:
	for u in SelectionManager.selected_units:
		if u is Monk and is_instance_valid(u):
			return true
	return false


func _find_damaged_friendly_unit_at(world_pos: Vector2) -> Unit:
	var best: Unit = null
	var best_dist := 36.0
	for node in get_tree().get_nodes_in_group("player_units"):
		if not (node is Unit) or node is Monk:
			continue
		var u := node as Unit
		if u.hp >= u.max_hp - 0.5:
			continue
		var d := u.global_position.distance_to(world_pos)
		if d < best_dist:
			best_dist = d
			best = u
	return best


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


func _find_damaged_own_building_at(world_pos: Vector2) -> Building:
	if not SelectionManager.has_selected_villager():
		return null
	var best: Building = null
	var best_dist := 40.0
	for node in get_tree().get_nodes_in_group("player_buildings"):
		if not (node is Building):
			continue
		var b := node as Building
		if not b.needs_repair():
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