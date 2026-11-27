extends Unit
class_name LightCavalry
## DESIGN: Lehký jezdec — 80 J, 30 s, HP 60, útok 4, zbroj 0/2, rychlost 1.6× vesničan.


const VILLAGER_SPEED := 80.0


func _ready() -> void:
	unit_id = "light_cavalry"
	is_cavalry = true
	speed = VILLAGER_SPEED * 1.6
	max_hp = 60.0
	attack_damage = 4.0
	melee_armor = 0.0
	pierce_armor = 2.0
	attack_range = 36.0
	attack_cooldown = 0.75
	can_attack = true
	attack_type = "melee"
	sight_range = 6.0 * 40.0
	super._ready()
	configure_facing_sprites("light_cavalry")
	add_to_group("soldiers")
	add_to_group("cavalry")