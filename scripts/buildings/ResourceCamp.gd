extends Building
class_name ResourceCamp

## Shared drop-off building (Pila / Mlýn).
@export var dropoff_radius: float = 48.0
@export var accepted_resources: PackedStringArray = ["wood"]


func _ready() -> void:
	super._ready()
	add_to_group("dropoffs")


func accepts(resource_type: String) -> bool:
	return resource_type in accepted_resources