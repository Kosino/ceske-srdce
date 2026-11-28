extends Unit
class_name Soldier

## DESIGN: Zbrojnos — 60 J, 20 Z, 21 s, HP 45, utok 6, 80 px/s.


func _ready() -> void:
	unit_id = "soldier"
	speed = 80.0
	max_hp = 45.0
	attack_damage = 6.0
	attack_range = 36.0
	attack_cooldown = 0.8
	can_attack = true
	sight_range = 4.0 * 40.0
	super._ready()
	configure_facing_sprites("soldier")
	add_to_group("soldiers")
