extends Node2D
class_name DropOff

@export var dropoff_radius: float = 48.0
@export var building_name: String = "Radnice"


func _ready() -> void:
	if has_node("Label"):
		$Label.text = building_name
