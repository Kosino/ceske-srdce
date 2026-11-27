extends Unit
class_name Ram
## Beranidlo — age 4 siege. Buildings/walls only; huge building bonus; high pierce armor.


func _ready() -> void:
	unit_id = "ram"
	speed = 40.0
	max_hp = 175.0
	attack_damage = 2.0
	bonus_vs_buildings = 125.0
	attack_range = 40.0
	attack_cooldown = 1.5
	can_attack = true
	attack_type = "melee"
	melee_armor = 0.0
	pierce_armor = 7.0
	buildings_only = true
	super._ready()
	configure_facing_sprites("ram")
	add_to_group("soldiers")
	add_to_group("siege")
	if _visual:
		_visual.modulate = Color(0.85, 0.75, 0.55, 1.0) if team == 0 else Color(1.0, 0.55, 0.45, 1.0)
