extends ResourceCamp
class_name LumberCamp
## DESIGN: Pila 100 D, 25 s, HP 600, 80×80, drop-off dřevo.


func _ready() -> void:
	building_id = "lumber_camp"
	display_name = "Pila"
	footprint = Vector2(80, 80)
	max_hp = 600.0
	build_time = 25.0
	accepted_resources = PackedStringArray(["wood"])
	super._ready()
