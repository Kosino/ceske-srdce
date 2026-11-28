extends Building
class_name WatchTower
## Strážní věž: 125 K + 25 D, 40 s, 1000 HP, 40×40, age 2. Attack 5 pierce / range 7 tiles.

const PROJECTILE_SCENE := preload("res://scenes/combat/Projectile.tscn")
const TEX_TOWER := preload("res://assets/sprites/buildings/watch_tower.png")
const BASE_ATTACK_DAMAGE := 5.0
const BASE_ATTACK_RANGE := 7.0 * 40.0
const ATTACK_COOLDOWN := 1.0

var spawn_parent: Node2D
var build_cost: Dictionary = {"stone": 125, "wood": 25}
var _attack_timer: float = 0.0
var attack_damage: float = BASE_ATTACK_DAMAGE
var attack_range_px: float = BASE_ATTACK_RANGE
## Tech ids already applied to this tower (idempotent).
var _applied_tower_techs: Dictionary = {}


func _ready() -> void:
	building_id = "watch_tower"
	display_name = "Strážní věž"
	footprint = Vector2(40, 40)
	max_hp = 1000.0
	build_time = 40.0
	if placed_cost.is_empty() and not build_cost.is_empty():
		placed_cost = build_cost.duplicate()
	_visual = get_node_or_null("Visual") as Sprite2D
	if _visual:
		_visual.visible = true
		_visual.texture = TEX_TOWER
	super._ready()
	add_to_group("watch_towers")
	if is_complete:
		GarrisonController.ensure(self)


func _on_construction_finished() -> void:
	GarrisonController.ensure(self)


func apply_tower_attack_bonus(amount: float, tech_id: String = "") -> void:
	if amount <= 0.0:
		return
	var key := tech_id if tech_id != "" else "atk_%.2f" % amount
	if _applied_tower_techs.get(key, false):
		return
	_applied_tower_techs[key] = true
	attack_damage += amount


func apply_tower_range_bonus(amount: float, tech_id: String = "") -> void:
	if amount <= 0.0:
		return
	var key := tech_id if tech_id != "" else "rng_%.2f" % amount
	# Range bonuses from different techs share prefix — use full key.
	var full := "rng_%s" % key
	if _applied_tower_techs.get(full, false):
		return
	_applied_tower_techs[full] = true
	attack_range_px += amount


func _process(delta: float) -> void:
	super._process(delta)
	if not is_complete:
		return
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_try_auto_attack()


func _try_auto_attack() -> void:
	if _attack_timer > 0.0:
		return
	var target := _nearest_enemy()
	if target == null:
		return
	_attack_timer = ATTACK_COOLDOWN
	var garr := GarrisonController.of(self)
	var arrows := garr.total_arrows(1) if garr else 1
	var parent := spawn_parent if spawn_parent else get_parent()
	if parent == null:
		parent = get_tree().current_scene
	var origin := global_position + Vector2(0, -footprint.y * 0.35)
	for i in arrows:
		var proj: Projectile = PROJECTILE_SCENE.instantiate() as Projectile
		parent.add_child(proj)
		var aim := target.global_position + Vector2(float(i) * 3.0 - float(arrows) * 1.5, 0.0)
		proj.setup(origin, aim, attack_damage, team, target)
	print("[COMBAT] tower loosed %d arrow(s) at %s" % [arrows, target.name])


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := attack_range_px
	var groups: Array
	if team == 0:
		groups = ["enemy_units", "enemy_buildings", "enemy_town_hall"]
	else:
		groups = ["player_units", "player_buildings", "player_town_hall"]
	var tree := get_tree()
	if tree == null:
		return null
	for g in groups:
		for n in tree.get_nodes_in_group(g):
			if not (n is Node2D) or not is_instance_valid(n):
				continue
			if n is Unit and (n as Unit).is_garrisoned:
				continue
			var d := global_position.distance_to((n as Node2D).global_position)
			if d <= best_d:
				best_d = d
				best = n as Node2D
	return best
