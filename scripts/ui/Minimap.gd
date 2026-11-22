extends PanelContainer
class_name Minimap
## Bottom-right minimap — LMB pans camera, RMB move orders, team markers + camera frame.


const MAP_SIZE := Vector2(3000, 3000)
const PLAYER_UNIT := Color(0.25, 0.9, 0.3)
const ENEMY_UNIT := Color(0.95, 0.25, 0.2)
const PLAYER_BUILD := Color(0.35, 0.75, 1.0)
const ENEMY_BUILD := Color(1.0, 0.55, 0.2)
const FOREST_COLOR := Color(0.08, 0.32, 0.12)
const GOLD_COLOR := Color(0.92, 0.82, 0.2)
const STONE_COLOR := Color(0.55, 0.55, 0.58)
const FRAME_COLOR := Color(1.0, 1.0, 0.85, 0.95)

@onready var draw_area: MinimapDraw = %MinimapDraw as MinimapDraw


func _ready() -> void:
	add_to_group("hud_minimap")
	if draw_area:
		draw_area.host = self
		if not draw_area.gui_input.is_connected(_on_draw_gui_input):
			draw_area.gui_input.connect(_on_draw_gui_input)


func _process(_delta: float) -> void:
	if draw_area and is_visible_in_tree():
		draw_area.queue_redraw()


func paint_minimap(surf: Control) -> void:
	var r := surf.size
	if r.x < 2.0 or r.y < 2.0:
		return
	surf.draw_rect(Rect2(Vector2.ZERO, r), Color(0.12, 0.16, 0.12, 0.85))
	surf.draw_rect(Rect2(Vector2.ZERO, r), Color(0.45, 0.5, 0.4, 0.9), false, 2.0)
	var tree := get_tree()
	if tree == null:
		return
	_draw_dots(surf, tree, "forest_resources", FOREST_COLOR, r, 1.6)
	_draw_dots(surf, tree, "gold_mines", GOLD_COLOR, r, 2.4)
	_draw_dots(surf, tree, "stone_mines", STONE_COLOR, r, 2.4)
	_draw_building_squares(surf, tree, "player_buildings", PLAYER_BUILD, r)
	_draw_building_squares(surf, tree, "enemy_buildings", ENEMY_BUILD, r)
	_draw_dots(surf, tree, "player_units", PLAYER_UNIT, r, 2.5)
	_draw_dots(surf, tree, "enemy_units", ENEMY_UNIT, r, 2.5)
	_draw_camera_frame(surf, r)


func _draw_dots(
	surf: Control, tree: SceneTree, group: String, color: Color, r: Vector2, radius: float
) -> void:
	for n in tree.get_nodes_in_group(group):
		if not (n is Node2D):
			continue
		var uv := _world_to_uv((n as Node2D).global_position)
		surf.draw_circle(Vector2(uv.x * r.x, uv.y * r.y), radius, color)


func _draw_building_squares(surf: Control, tree: SceneTree, group: String, color: Color, r: Vector2) -> void:
	for n in tree.get_nodes_in_group(group):
		if not (n is Node2D):
			continue
		var uv := _world_to_uv((n as Node2D).global_position)
		var c := Vector2(uv.x * r.x, uv.y * r.y)
		surf.draw_rect(Rect2(c - Vector2(3, 3), Vector2(6, 6)), color)


func _draw_camera_frame(surf: Control, r: Vector2) -> void:
	var cam := get_viewport().get_camera_2d() as Camera2D
	if cam == null:
		return
	var half: Vector2
	if cam is RTSCamera:
		half = (cam as RTSCamera).view_half_extents()
	else:
		half = get_viewport().get_visible_rect().size / cam.zoom * 0.5
	var top_left := cam.global_position - half
	var bottom_right := cam.global_position + half
	var a := _world_to_uv(top_left)
	var b := _world_to_uv(bottom_right)
	var rect := Rect2(
		Vector2(a.x * r.x, a.y * r.y),
		Vector2((b.x - a.x) * r.x, (b.y - a.y) * r.y)
	)
	surf.draw_rect(rect, FRAME_COLOR, false, 1.5)


func _world_to_uv(world: Vector2) -> Vector2:
	return Vector2(
		clampf(world.x / MAP_SIZE.x, 0.0, 1.0),
		clampf(world.y / MAP_SIZE.y, 0.0, 1.0)
	)


func minimap_to_world(local: Vector2) -> Vector2:
	var r := draw_area.size if draw_area else Vector2(148, 128)
	if r.x < 1.0 or r.y < 1.0:
		r = Vector2(148, 128)
	var uv := Vector2(clampf(local.x / r.x, 0.0, 1.0), clampf(local.y / r.y, 0.0, 1.0))
	return Vector2(uv.x * MAP_SIZE.x, uv.y * MAP_SIZE.y)


func move_camera_to_minimap(local: Vector2) -> void:
	var world := minimap_to_world(local)
	var cam := get_viewport().get_camera_2d()
	if cam is RTSCamera:
		(cam as RTSCamera).center_at(world)
	elif cam:
		cam.global_position = world


func issue_move_at_minimap(local: Vector2) -> void:
	SelectionManager.issue_move(minimap_to_world(local))


func _on_draw_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			move_camera_to_minimap(mb.position)
			accept_event()
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
			issue_move_at_minimap(mb.position)
			accept_event()
