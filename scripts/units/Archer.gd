extends Unit
class_name Archer

## DESIGN: Lučištník — 25 D + 45 Z, 35 s, HP 30, útok 4, dosah 160 px. Střílí projektilem.

const PROJECTILE_SCENE := preload("res://scenes/combat/Projectile.tscn")


func _ready() -> void:
	unit_id = "archer"
	speed = 80.0
	max_hp = 30.0
	attack_damage = 4.0
	attack_range = 160.0
	attack_cooldown = 1.0
	can_attack = true
	attack_type = "pierce"
	super._ready()
	configure_facing_sprites("archer")
	add_to_group("soldiers")
	add_to_group("archers")
	if _visual:
		_visual.modulate = Color(1, 1, 1, 1) if team == 0 else Color(1.0, 0.55, 0.55, 1.0)


func _try_strike() -> void:
	if _attack_timer > 0.0 or not is_instance_valid(attack_target):
		return
	if "team" in attack_target and int(attack_target.get("team")) == team:
		attack_target = null
		return
	_attack_timer = attack_cooldown
	var proj: Projectile = PROJECTILE_SCENE.instantiate() as Projectile
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(proj)
	proj.setup(global_position, attack_target.global_position, attack_damage, team, attack_target)
	AudioManager.play_sfx("bow_shot")
	print("[COMBAT] archer loosed arrow at %s" % attack_target.name)