extends Node2D
class_name Projectile

## Arrow / bolt: flies to aim point locked at fire time.
const SPEED := 400.0
const HIT_RADIUS := 20.0

var team: int = 0
var damage: float = 4.0
var aim_pos: Vector2 = Vector2.ZERO
var intended_target: Node2D = null
var _alive: bool = true


func setup(origin: Vector2, aim: Vector2, dmg: float, shooter_team: int, target: Node2D) -> void:
	global_position = origin
	aim_pos = aim
	damage = dmg
	team = shooter_team
	intended_target = target
	rotation = (aim_pos - global_position).angle()
	z_index = 50


func _physics_process(delta: float) -> void:
	if not _alive:
		return
	var to_aim := aim_pos - global_position
	var dist := to_aim.length()
	var step := SPEED * delta
	if dist <= step:
		global_position = aim_pos
		_impact()
		_alive = false
		queue_free()
		return
	global_position += to_aim / dist * step
	rotation = to_aim.angle()


func _impact() -> void:
	if intended_target == null or not is_instance_valid(intended_target):
		print("[COMBAT] arrow miss (no target)")
		return
	if intended_target.global_position.distance_to(aim_pos) > HIT_RADIUS:
		print("[COMBAT] arrow miss (target moved)")
		return
	if _is_friendly(intended_target):
		print("[COMBAT] arrow refuse friendly fire")
		return
	if intended_target.has_method("take_damage"):
		intended_target.call("take_damage", damage, "pierce")
		print("[COMBAT] arrow hit %s for %.1f (pierce)" % [intended_target.name, damage])


func _is_friendly(target: Node2D) -> bool:
	if target == null:
		return true
	if "team" in target and int(target.get("team")) == team:
		return true
	if team == 0 and (target.is_in_group("player_buildings") or target.is_in_group("player_town_hall") or target.is_in_group("player_units")):
		return true
	if team != 0 and (target.is_in_group("enemy_buildings") or target.is_in_group("enemy_town_hall") or target.is_in_group("enemy_units")):
		return true
	return false