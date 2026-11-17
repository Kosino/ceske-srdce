extends Building
class_name House

## DESIGN: Dům 25 D, HP 550, +5 populace (strop 200).
@export var population_bonus: int = 5


func _ready() -> void:
	building_id = "house"
	display_name = "Dům"
	footprint = Vector2(56, 56)
	max_hp = 550.0
	super._ready()
	add_to_group("houses")
	if team == 0:
		GameManager.add_population_cap(population_bonus)