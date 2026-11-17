extends Node2D
class_name Building

@export var building_id: String = ""
@export var display_name: String = "Budova"
@export var max_hp: float = 500.0
@export var footprint: Vector2 = Vector2(72, 72)

var hp: float


func _ready() -> void:
	hp = max_hp
	add_to_group("buildings")
	if has_node("Label"):
		$Label.text = display_name
