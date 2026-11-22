extends Building
class_name Gate
## Replaces 3 wall segments. Own units pass; enemies blocked. 30 stone, 1500 HP.

const PLAYER_GATE_LAYER := 4
const ENEMY_GATE_LAYER := 8
const TEX_GATE := preload("res://assets/sprites/buildings/gate.png")

@export var orientation: String = "h" # h = 3×1 tiles, v = 1×3
var anchor_tile: Vector2i = Vector2i.ZERO
var build_cost: Dictionary = {"stone": 30}
var _body: StaticBody2D


func _ready() -> void:
	building_id = "gate"
	display_name = "Brána"
	max_hp = 1500.0
	build_time = 10.0
	if orientation == "v":
		footprint = Vector2(40, 120)
	else:
		footprint = Vector2(120, 40)
	if placed_cost.is_empty() and not build_cost.is_empty():
		placed_cost = build_cost.duplicate()
	_visual = get_node_or_null("Visual") as Sprite2D
	if _visual:
		_visual.visible = true
		_visual.texture = TEX_GATE
	super._ready()
	add_to_group("gates")
	anchor_tile = WallNav.world_to_tile(global_position - _footprint_offset())
	if is_complete:
		_ensure_blocker()


func occupied_tiles() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in range(3):
		if orientation == "v":
			out.append(anchor_tile + Vector2i(0, i))
		else:
			out.append(anchor_tile + Vector2i(i, 0))
	return out


func _footprint_offset() -> Vector2:
	if orientation == "v":
		return Vector2(0, 40)
	return Vector2(40, 0)


func _on_construction_finished() -> void:
	_ensure_blocker()
	_refresh_label()
	queue_redraw()


func should_show_name_label() -> bool:
	return (not is_complete) or ui_selected or ui_hovered


func should_show_hp_bar() -> bool:
	if not is_complete:
		return true
	return ui_selected or ui_hovered or needs_repair()


func _ensure_blocker() -> void:
	if _body != null and is_instance_valid(_body):
		return
	_body = StaticBody2D.new()
	_body.collision_layer = PLAYER_GATE_LAYER if team == 0 else ENEMY_GATE_LAYER
	_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	if orientation == "v":
		rect.size = Vector2(36, 116)
	else:
		rect.size = Vector2(116, 36)
	shape.shape = rect
	_body.add_child(shape)
	add_child(_body)


func die() -> void:
	if _body and is_instance_valid(_body):
		_body.queue_free()
		_body = null
	super.die()
