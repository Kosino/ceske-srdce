extends Unit
class_name ValecnyVuz
## Husité unique — Válečný vůz. 110D+60Z, HP 165, atk 7 pierce / 5 dlaždic, zbroj 0/6, 0.8×.


const VILLAGER_SPEED := 80.0
const PROJECTILE_SCENE := preload("res://scenes/combat/Projectile.tscn")


func _ready() -> void:
	unit_id = "valecny_vuz"
	speed = VILLAGER_SPEED * 0.8
	max_hp = 165.0
	attack_damage = 7.0
	melee_armor = 0.0
	pierce_armor = 6.0
	attack_range = 5.0 * 40.0
	attack_cooldown = 1.1
	can_attack = true
	attack_type = "pierce"
	super._ready()
	configure_facing_sprites("valecny_vuz")
	add_to_group("soldiers")

func _try_strike() -> void:
	if _attack_timer > 0.0 or not is_instance_valid(attack_target):
		return
	if is_friendly_target(attack_target):
		attack_target = null
		return
	_attack_timer = attack_cooldown
	var proj: Projectile = PROJECTILE_SCENE.instantiate() as Projectile
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(proj)
	proj.setup(global_position, attack_target.global_position, attack_damage, team, attack_target)
	print("[COMBAT] war wagon loosed at %s" % attack_target.name)
