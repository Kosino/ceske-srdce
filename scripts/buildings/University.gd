extends Building
class_name University
## Univerzita — NÁVRH: 200 D, 60 s, 2100 HP, 80×80, věk 4.


func _ready() -> void:
	building_id = "university"
	display_name = "Univerzita"
	footprint = Vector2(80, 80)
	max_hp = 2100.0
	build_time = 60.0
	super._ready()
	add_to_group("universities")
