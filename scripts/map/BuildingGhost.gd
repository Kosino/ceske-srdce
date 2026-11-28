extends Node2D
class_name BuildingGhost
## AoE II fog memory: frozen enemy-building snapshot (HP / build phase).
## Not selectable or attackable — right-click falls through to a move order.


const CONSTRUCTION_TEX := preload("res://assets/sprites/buildings/construction_site.png")

## Live building instance_id while it still exists; 0 after destruction out of sight.
var source_instance_id: int = 0
var footprint: Vector2 = Vector2(72, 72)
var display_name: String = "Budova"
var max_hp: float = 500.0
var snap_hp: float = 500.0
var snap_build_progress: float = 1.0
var snap_is_complete: bool = true
var team: int = 1
## True when the live building died while this ghost was the last-known image.
var is_destroyed_memory: bool = false
## Set after the first successful capture_from (fog freeze uses this).
var has_snapshot: bool = false

var _visual: Sprite2D
var _label: Label


func _ready() -> void:
	add_to_group("fog_building_ghosts")
	z_index = 4
	if _visual == null:
		_ensure_nodes()


func _ensure_nodes() -> void:
	if _visual == null:
		_visual = Sprite2D.new()
		_visual.name = "Visual"
		_visual.centered = true
		_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_visual)
	if _label == null:
		_label = Label.new()
		_label.name = "Label"
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.position = Vector2(-36, 24)
		_label.size = Vector2(72, 24)
		add_child(_label)


## Capture frozen state from a live enemy Building or DropOff (call only while in LOS).
func capture_from(node: Node2D) -> void:
	if node == null or not is_instance_valid(node):
		return
	_ensure_nodes()
	source_instance_id = node.get_instance_id()
	is_destroyed_memory = false
	global_position = node.global_position
	team = int(node.get("team")) if "team" in node else 1

	if node is Building:
		var b := node as Building
		footprint = b.footprint
		display_name = b.display_name
		max_hp = b.max_hp
		snap_hp = b.hp
		snap_build_progress = b.build_progress
		snap_is_complete = b.is_complete
		_apply_building_texture(b)
	elif node is DropOff:
		var hall := node as DropOff
		footprint = Vector2(80, 80)
		display_name = hall.building_name
		max_hp = hall.max_hp
		snap_hp = hall.hp
		snap_build_progress = 1.0
		snap_is_complete = true
		_apply_dropoff_texture(hall)
	else:
		return
	has_snapshot = true
	_refresh_label()
	queue_redraw()


func mark_destroyed_memory() -> void:
	is_destroyed_memory = true
	source_instance_id = 0


func _apply_building_texture(b: Building) -> void:
	var src := b.get_node_or_null("Visual") as Sprite2D
	var tex: Texture2D = null
	if not snap_is_complete:
		tex = CONSTRUCTION_TEX
	elif src != null and src.texture != null:
		tex = src.texture
	_visual.texture = tex
	_anchor_sprite(tex)
	TeamColors.apply(_visual, team, true)


func _apply_dropoff_texture(hall: DropOff) -> void:
	var src := hall.get_node_or_null("Visual") as Sprite2D
	var tex: Texture2D = src.texture if src != null else null
	_visual.texture = tex
	_anchor_sprite(tex)
	TeamColors.apply(_visual, team, true)


func _anchor_sprite(tex: Texture2D) -> void:
	if _visual == null or tex == null:
		return
	_visual.centered = true
	_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_visual.offset = Vector2(0.0, footprint.y * 0.5 - float(tex.get_height()) * 0.5)


func _refresh_label() -> void:
	if _label == null:
		return
	_label.visible = true
	_label.position = Vector2(-footprint.x * 0.5, footprint.y * 0.35)
	_label.size = Vector2(footprint.x, 24.0)
	if snap_is_complete:
		_label.text = display_name
	else:
		_label.text = "%s %d%%" % [display_name, int(snap_build_progress * 100.0)]


func _hp_fill_color() -> Color:
	return Color(0.9, 0.2, 0.15, 0.95)


func _draw() -> void:
	var bar_w := footprint.x * 0.8
	var origin := Vector2(-bar_w * 0.5, -footprint.y * 0.5 - 10.0)
	draw_rect(Rect2(origin, Vector2(bar_w, 4.0)), Color(0.1, 0.1, 0.1, 0.8))
	if snap_is_complete:
		var ratio := clampf(snap_hp / maxf(max_hp, 1.0), 0.0, 1.0)
		draw_rect(Rect2(origin, Vector2(bar_w * ratio, 4.0)), _hp_fill_color())
	else:
		draw_rect(Rect2(origin, Vector2(bar_w * snap_build_progress, 4.0)), Color(0.95, 0.85, 0.2, 0.95))
