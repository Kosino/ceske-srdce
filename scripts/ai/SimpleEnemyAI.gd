extends Node
class_name SimpleEnemyAI

@export var retarget_interval: float = 1.0

var _timer: float = 0.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = retarget_interval
	_assign_targets()


func _assign_targets() -> void:
	var enemies := get_tree().get_nodes_in_group("enemy_units")
	if enemies.is_empty():
		return
	for node in enemies:
		if not (node is Unit):
			continue
		var unit := node as Unit
		if is_instance_valid(unit.attack_target):
			continue
		var target := _nearest_player_threat(unit.global_position)
		if target:
			unit.command_attack(target)


func _nearest_player_threat(from_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for group_name in ["player_units", "player_buildings", "player_town_hall"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if not (node is Node2D):
				continue
			var n := node as Node2D
			var d := from_pos.distance_to(n.global_position)
			if d < best_dist:
				best_dist = d
				best = n
	return best
