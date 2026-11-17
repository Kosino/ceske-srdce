extends Unit
class_name Soldier


func _ready() -> void:
	speed = 90.0
	max_hp = 55.0
	attack_damage = 8.0
	attack_range = 38.0
	attack_cooldown = 0.7
	can_attack = true
	super._ready()
	add_to_group("soldiers")
	_apply_team_visual()


func _apply_team_visual() -> void:
	if not has_node("Visual"):
		return
	if team == 0:
		$Visual.color = Color(0.2, 0.45, 0.85, 1.0)
	else:
		$Visual.color = Color(0.75, 0.15, 0.15, 1.0)
