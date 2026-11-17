extends Unit
class_name Spearman

## DESIGN: Kopiník — 35 J + 25 D, 22 s, HP 45, útok 3 (+15 vs jízda), 85 px/s.


func _ready() -> void:
	speed = 85.0
	max_hp = 45.0
	attack_damage = 3.0
	bonus_vs_cavalry = 15.0
	attack_range = 36.0
	attack_cooldown = 0.8
	can_attack = true
	super._ready()
	add_to_group("soldiers")
	if has_node("Visual"):
		$Visual.color = Color(0.15, 0.55, 0.35, 1.0) if team == 0 else Color(0.55, 0.2, 0.2, 1.0)