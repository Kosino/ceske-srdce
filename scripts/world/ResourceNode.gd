extends Node2D
class_name ResourceNode

signal depleted

@export var resource_type: String = "wood"
@export var amount_remaining: int = 200
@export var gather_radius: float = 28.0

@onready var visual: Polygon2D = $Visual
@onready var label: Label = $Label


func _ready() -> void:
	_refresh_label()
	if visual:
		match resource_type:
			"food":
				visual.color = Color(0.75, 0.55, 0.15, 1.0)
			"gold":
				visual.color = Color(0.9, 0.8, 0.2, 1.0)
			"stone":
				visual.color = Color(0.55, 0.55, 0.6, 1.0)
			_:
				visual.color = Color(0.4, 0.25, 0.12, 1.0)


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


func _refresh_label() -> void:
	if label:
		label.text = "%s %d" % [resource_type.capitalize(), amount_remaining]
