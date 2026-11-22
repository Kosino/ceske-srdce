extends Building
class_name Blacksmith

## NÁVRH: Kovárna 150 D, 40 s, HP 1800, footprint 80×80.
## Build-only for now (counts toward age-2 gate); no techs yet.


func _ready() -> void:
	building_id = "blacksmith"
	display_name = "Kovárna"
	footprint = Vector2(80, 80)
	max_hp = 1800.0
	build_time = 40.0
	super._ready()
	add_to_group("blacksmiths")
