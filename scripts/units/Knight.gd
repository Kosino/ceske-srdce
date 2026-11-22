extends Unit
class_name Knight
## DESIGN: Rytíř — 60 J + 75 Z, 30 s, HP 100, útok 10, zbroj 2/2, rychlost 1.35×, věk 3.


const VILLAGER_SPEED := 80.0


func _ready() -> void:
	unit_id = "knight"
	is_cavalry = true
	speed = VILLAGER_SPEED * 1.35
	max_hp = 100.0
	attack_damage = 10.0
	melee_armor = 2.0
	pierce_armor = 2.0
	attack_range = 36.0
	attack_cooldown = 0.85
	can_attack = true
	attack_type = "melee"
	sight_range = 5.0 * 40.0
	super._ready()
	configure_facing_sprites("knight")
	add_to_group("soldiers")
	add_to_group("cavalry")
	if _visual:
		_visual.modulate = Color(1, 1, 1, 1) if team == 0 else Color(1.0, 0.55, 0.55, 1.0)
