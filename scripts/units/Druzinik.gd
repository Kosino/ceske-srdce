extends Unit
class_name Druzinik
## Přemyslovci unique — Družiník. 70J+70Z, HP 120, atk 11, zbroj 2/3, jízda 1.3×.


const VILLAGER_SPEED := 80.0


func _ready() -> void:
	unit_id = "druzinik"
	is_cavalry = true
	speed = VILLAGER_SPEED * 1.3
	max_hp = 120.0
	attack_damage = 11.0
	melee_armor = 2.0
	pierce_armor = 3.0
	attack_range = 36.0
	attack_cooldown = 0.85
	can_attack = true
	attack_type = "melee"
	super._ready()
	configure_facing_sprites("druzinik")
	add_to_group("soldiers")
	add_to_group("cavalry")
	if _visual:
		_visual.modulate = Color(1, 1, 1, 1) if team == 0 else Color(1.0, 0.55, 0.55, 1.0)
