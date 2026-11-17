extends Building
class_name House

@export var population_bonus: int = 5


func _ready() -> void:
	building_id = "house"
	display_name = "Dům"
	footprint = Vector2(56, 56)
	max_hp = 220.0
	super._ready()
	add_to_group("houses")
	GameManager.add_population_cap(population_bonus)
