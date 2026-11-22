extends Unit
class_name Soldier

## DESIGN: Zbrojnos — 60 J, 20 Z, 21 s, HP 45, utok 6, 80 px/s.


func _ready() -> void:
	speed = 80.0
	max_hp = 45.0
	attack_damage = 6.0
	attack_range = 36.0
	attack_cooldown = 0.8
	can_attack = true
	super._ready()
	configure_facing_sprites("soldier")
	add_to_group("soldiers")
	_apply_team_visual()


func _apply_team_visual() -> void:
	if _visual == null:
		return
	_visual.modulate = Color(1, 1, 1, 1) if team == 0 else Color(1.0, 0.55, 0.55, 1.0)
