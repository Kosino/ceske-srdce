extends ResourceCamp
class_name Mill

## DESIGN: Mlýn 100 D, HP 1000, drop-off jídlo.


func _ready() -> void:
	building_id = "mill"
	display_name = "Mlýn"
	footprint = Vector2(72, 72)
	max_hp = 1000.0
	accepted_resources = PackedStringArray(["food"])
	super._ready()