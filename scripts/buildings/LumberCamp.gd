extends ResourceCamp
class_name LumberCamp

## DESIGN: Pila 100 D, 35 s, HP 1000, drop-off dřevo.


func _ready() -> void:
	building_id = "lumber_camp"
	display_name = "Pila"
	footprint = Vector2(72, 72)
	max_hp = 1000.0
	build_time = 35.0
	accepted_resources = PackedStringArray(["wood"])
	super._ready()