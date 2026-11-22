extends Building
class_name WallSegment
## Palisade / stone wall tile — 40×40. Blocks all units when complete.

const SOLID_LAYER := 2
const TEX_PALISADE := preload("res://assets/sprites/buildings/palisade.png")
const TEX_STONE := preload("res://assets/sprites/buildings/stone_wall.png")

@export var wall_kind: String = "palisade" # palisade | stone_wall
var tile: Vector2i = Vector2i.ZERO
var chain_id: int = -1
var chain_index: int = 0
var build_cost: Dictionary = {}
var _body: StaticBody2D


func _ready() -> void:
	footprint = Vector2(40, 40)
	match wall_kind:
		"stone_wall":
			building_id = "stone_wall"
			display_name = "Kamenná zeď"
			max_hp = 1800.0
			build_time = 8.0
			if build_cost.is_empty():
				build_cost = {"stone": 5}
		_:
			building_id = "palisade"
			display_name = "Palisáda"
			max_hp = 250.0
			build_time = 5.0
			if build_cost.is_empty():
				build_cost = {"wood": 2}
	if placed_cost.is_empty() and not build_cost.is_empty():
		placed_cost = build_cost.duplicate()
	# Assign final texture before Building._ready caches it.
	_visual = get_node_or_null("Visual") as Sprite2D
	if _visual:
		_visual.visible = true
		_visual.texture = TEX_STONE if wall_kind == "stone_wall" else TEX_PALISADE
	super._ready()
	add_to_group("walls")
	tile = WallNav.world_to_tile(global_position)
	if is_complete:
		_ensure_blocker()


func _on_construction_finished() -> void:
	_ensure_blocker()


func _ensure_blocker() -> void:
	if _body != null and is_instance_valid(_body):
		return
	_body = StaticBody2D.new()
	_body.collision_layer = SOLID_LAYER
	_body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 36)
	shape.shape = rect
	_body.add_child(shape)
	add_child(_body)


func die() -> void:
	if _body and is_instance_valid(_body):
		_body.queue_free()
		_body = null
	super.die()
