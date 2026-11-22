extends ResourceCamp
class_name MiningCamp
## DESIGN: Důlní tábor 100 D, 25 s, HP 600, 80×80, drop-off zlato + kámen.


func _ready() -> void:
	building_id = "mining_camp"
	display_name = "Důlní tábor"
	footprint = Vector2(80, 80)
	max_hp = 600.0
	build_time = 25.0
	accepted_resources = PackedStringArray(["gold", "stone"])
	super._ready()
