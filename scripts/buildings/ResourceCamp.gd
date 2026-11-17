extends Building
class_name ResourceCamp

## Shared drop-off building (Pila / Mlýn).
@export var dropoff_radius: float = 48.0
@export var accepted_resources: PackedStringArray = ["wood"]


func _ready() -> void:
	super._ready()
	if is_complete:
		_enable_dropoff()


func accepts(resource_type: String) -> bool:
	return is_complete and resource_type in accepted_resources


func _on_construction_finished() -> void:
	_enable_dropoff()


func _enable_dropoff() -> void:
	if not is_in_group("dropoffs"):
		add_to_group("dropoffs")