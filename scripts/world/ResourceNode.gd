extends Node2D
class_name ResourceNode
## Map resource — no permanent world labels (AoE: amount in SelectionInfo on hover/select).

signal depleted

const TEX_TREE_OAK := preload("res://assets/sprites/resources/tree_oak.png")
const TEX_TREE_PINE := preload("res://assets/sprites/resources/tree_pine.png")
const TEX_BERRY := preload("res://assets/sprites/resources/berry_bush.png")
const TEX_GOLD := preload("res://assets/sprites/resources/gold_mine.png")
const TEX_STONE := preload("res://assets/sprites/resources/stone_mine.png")

@export var resource_type: String = "wood"
@export var amount_remaining: int = 200
@export var gather_radius: float = 28.0

@onready var visual: Sprite2D = $Visual
@onready var label: Label = $Label

var _hovered: bool = false
var _selected: bool = false


func _ready() -> void:
	add_to_group("resources")
	match resource_type:
		"wood":
			add_to_group("forest_resources")
		"gold":
			add_to_group("gold_mines")
		"stone":
			add_to_group("stone_mines")
		"food":
			add_to_group("berry_bushes")
	if label:
		label.visible = false
		label.text = ""
	_apply_resource_sprite()
	_ensure_hover_area()


func _ensure_hover_area() -> void:
	if has_node("HoverArea"):
		return
	var area := Area2D.new()
	area.name = "HoverArea"
	area.input_pickable = true
	area.monitoring = false
	area.monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 22.0
	shape.shape = circle
	area.add_child(shape)
	add_child(area)
	area.mouse_entered.connect(_on_mouse_entered)
	area.mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	_hovered = true
	SelectionManager.set_hovered_resource(self)
	_refresh_selection_glow()


func _on_mouse_exited() -> void:
	_hovered = false
	if SelectionManager.hovered_resource == self:
		SelectionManager.set_hovered_resource(null)
	_refresh_selection_glow()


func set_resource_selected(on: bool) -> void:
	_selected = on
	_refresh_selection_glow()


func _refresh_selection_glow() -> void:
	if visual == null:
		return
	if _selected or _hovered:
		visual.modulate = Color(1.15, 1.15, 1.15, 1.0)
	else:
		visual.modulate = Color.WHITE


func _apply_resource_sprite() -> void:
	if visual == null:
		return
	var tex: Texture2D
	match resource_type:
		"food":
			tex = TEX_BERRY
		"gold":
			tex = TEX_GOLD
		"stone":
			tex = TEX_STONE
		_:
			var h := int(round(global_position.x * 0.05) + round(global_position.y * 0.05))
			tex = TEX_TREE_OAK if h % 2 == 0 else TEX_TREE_PINE
	visual.texture = tex
	visual.centered = true
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	visual.offset = Vector2(0.0, 8.0 - float(tex.get_height()) * 0.5)
	_refresh_selection_glow()


func is_depleted() -> bool:
	return amount_remaining <= 0


func harvest(amount: int) -> int:
	if amount <= 0 or is_depleted():
		return 0
	var taken := mini(amount, amount_remaining)
	amount_remaining -= taken
	if SelectionManager.selected_resource == self or SelectionManager.hovered_resource == self:
		SelectionManager.notify_resource_amount_changed(self)
	if is_depleted():
		depleted.emit()
		queue_free()
	return taken


func czech_type_name() -> String:
	match resource_type:
		"wood":
			return "Dřevo"
		"food":
			return "Jídlo"
		"gold":
			return "Zlato"
		"stone":
			return "Kámen"
		_:
			return resource_type.capitalize()


func info_line() -> String:
	return "%s — zbývá %d" % [czech_type_name(), amount_remaining]


func _exit_tree() -> void:
	if SelectionManager.hovered_resource == self:
		SelectionManager.set_hovered_resource(null)
	if SelectionManager.selected_resource == self:
		SelectionManager.clear_resource_selection()
