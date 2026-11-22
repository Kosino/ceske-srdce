extends Node2D
class_name ResourceNode

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
	_refresh_label()
	_apply_resource_sprite()


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
			# Alternate oak/pine for wood nodes.
			var h := int(round(global_position.x * 0.05) + round(global_position.y * 0.05))
			tex = TEX_TREE_OAK if h % 2 == 0 else TEX_TREE_PINE
	visual.texture = tex
	visual.centered = true
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Feet / trunk near origin bottom.
	visual.offset = Vector2(0.0, 8.0 - float(tex.get_height()) * 0.5)


func is_depleted() -> bool:
	return amount_remaining <= 0


func harvest(amount: int) -> int:
	if amount <= 0 or is_depleted():
		return 0
	var taken := mini(amount, amount_remaining)
	amount_remaining -= taken
	_refresh_label()
	if is_depleted():
		depleted.emit()
		queue_free()
	return taken


func _czech_type_name() -> String:
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


func _refresh_label() -> void:
	if label:
		label.text = "%s %d" % [_czech_type_name(), amount_remaining]
