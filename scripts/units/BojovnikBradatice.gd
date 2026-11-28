extends Unit
class_name BojovnikBradatice
## Moravané unique — Bojovník s bradaticí. 60J+30Z, HP 70, atk 9 (+8 vs budovy), zbroj 1/1.


const VILLAGER_SPEED := 80.0


func _ready() -> void:
	unit_id = "bojovnik_bradatice"
	speed = VILLAGER_SPEED * 1.0
	max_hp = 70.0
	attack_damage = 9.0
	melee_armor = 1.0
	pierce_armor = 1.0
	bonus_vs_buildings = 8.0
	attack_range = 36.0
	attack_cooldown = 0.85
	can_attack = true
	attack_type = "melee"
	super._ready()
	configure_facing_sprites("bojovnik_bradatice")
	add_to_group("soldiers")