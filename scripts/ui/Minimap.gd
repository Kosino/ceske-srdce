extends PanelContainer
class_name Minimap
## Bottom-right minimap placeholder — frame + unit dots.


const MAP_SIZE := Vector2(3000, 3000)

@onready var draw_area: MinimapDraw = %MinimapDraw as MinimapDraw


func _ready() -> void:
	add_to_group("hud_minimap")
	if draw_area:
		draw_area.host = self


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
	_draw_dots(surf, tree, "player_units", Color(0.25, 0.9, 0.3), r)
	_draw_dots(surf, tree, "enemy_units", Color(0.95, 0.25, 0.2), r)
	_draw_dots(surf, tree, "player_town_hall", Color(0.4, 0.85, 1.0), r)
	_draw_dots(surf, tree, "enemy_town_hall", Color(1.0, 0.55, 0.2), r)


func _draw_dots(surf: Control, tree: SceneTree, group: String, color: Color, r: Vector2) -> void:
	for n in tree.get_nodes_in_group(group):
		if not (n is Node2D):
			continue
		var p: Vector2 = (n as Node2D).global_position
		var uv := Vector2(clampf(p.x / MAP_SIZE.x, 0.0, 1.0), clampf(p.y / MAP_SIZE.y, 0.0, 1.0))
		surf.draw_circle(Vector2(uv.x * r.x, uv.y * r.y), 2.5, color)
