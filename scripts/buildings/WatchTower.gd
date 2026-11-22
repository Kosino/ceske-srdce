extends Building
class_name WatchTower
## Strážní věž: 125 K + 25 D, 40 s, 1000 HP, 40×40, age 2. Attack 5 pierce / range 7 tiles.

const PROJECTILE_SCENE := preload("res://scenes/combat/Projectile.tscn")
const TEX_TOWER := preload("res://assets/sprites/buildings/watch_tower.png")
const ATTACK_DAMAGE := 5.0
const ATTACK_RANGE := 7.0 * 40.0
const ATTACK_COOLDOWN := 1.0

var spawn_parent: Node2D
var build_cost: Dictionary = {"stone": 125, "wood": 25}
var _attack_timer: float = 0.0


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
	var proj: Projectile = PROJECTILE_SCENE.instantiate() as Projectile
	var parent := spawn_parent if spawn_parent else get_parent()
	if parent == null:
		parent = get_tree().current_scene
	parent.add_child(proj)
	var origin := global_position + Vector2(0, -footprint.y * 0.35)
	proj.setup(origin, target.global_position, ATTACK_DAMAGE, team, target)
	print("[COMBAT] tower loosed arrow at %s" % target.name)


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := ATTACK_RANGE
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
			var d := global_position.distance_to((n as Node2D).global_position)
			if d <= best_d:
				best_d = d
				best = n as Node2D
	return best
