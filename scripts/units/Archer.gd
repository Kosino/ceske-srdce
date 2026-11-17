extends Unit
class_name Archer

## DESIGN: Lučištník — 25 D + 45 Z, 35 s, HP 30, útok 4, dosah 160 px.


func _ready() -> void:
	speed = 80.0
	max_hp = 30.0
	attack_damage = 4.0
	attack_range = 160.0
	attack_cooldown = 1.0
	can_attack = true
	super._ready()
	add_to_group("soldiers")
	if has_node("Visual"):
		$Visual.color = Color(0.55, 0.35, 0.15, 1.0) if team == 0 else Color(0.55, 0.15, 0.35, 1.0)