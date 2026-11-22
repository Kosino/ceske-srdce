extends Unit
class_name Lancknecht
## Habsburkové unique — Lancknecht. 55J+45Z, HP 75, atk 8 (+10 vs jízda), zbroj 1/1.


const VILLAGER_SPEED := 80.0


func _ready() -> void:
	unit_id = "lancknecht"
	speed = VILLAGER_SPEED * 1.0
	max_hp = 75.0
	attack_damage = 8.0
	melee_armor = 1.0
	pierce_armor = 1.0
	bonus_vs_cavalry = 10.0
	attack_range = 36.0
	attack_cooldown = 0.85
	can_attack = true
	attack_type = "melee"
	super._ready()
	configure_facing_sprites("lancknecht")
	add_to_group("soldiers")
	if _visual:
		_visual.modulate = Color(1, 1, 1, 1) if team == 0 else Color(1.0, 0.55, 0.55, 1.0)
