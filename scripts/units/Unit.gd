extends CharacterBody2D
class_name Unit

signal died(unit: Unit)

@export var team: int = 0
@export var unit_id: String = ""
@export var speed: float = 80.0
@export var max_hp: float = 25.0
@export var attack_damage: float = 3.0
@export var attack_range: float = 36.0
@export var attack_cooldown: float = 0.8
@export var can_attack: bool = true
@export var is_cavalry: bool = false
@export var bonus_vs_cavalry: float = 0.0
@export var bonus_vs_buildings: float = 0.0
## "melee" or "pierce" — archers pierce, others melee.
@export var attack_type: String = "melee"
@export var melee_armor: float = 0.0
@export var pierce_armor: float = 0.0
## Siege: only Building / DropOff / WallSegment / Gate / WatchTower.
@export var buildings_only: bool = false
## Trebuchet-style minimum range (0 = none).
@export var min_attack_range: float = 0.0
## Sight / LOS in pixels (6 tiles = 240 for light cavalry).
@export var sight_range: float = 200.0
## When false, population was already reserved (e.g. production queue).
@export var contribute_population: bool = true

var hp: float
var selected: bool = false
var attack_target: Node2D = null
var _attack_timer: float = 0.0
var _facing: String = "down"
var _facing_textures: Dictionary = {}
var _visual: Sprite2D
## When >= 0, group formation move uses min(speed, cap) so the group keeps pace.
var _move_speed_cap: float = -1.0
## Wall-aware waypoint path (tile centers); empty = use NavigationAgent alone.
var _wall_waypoints: Array[Vector2] = []
var _move_goal: Vector2 = Vector2.ZERO

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	GameManager.apply_civ_unit_bonuses(self)
	GameManager.apply_researched_techs_to_unit(self)
	hp = max_hp
	_visual = get_node_or_null("Visual") as Sprite2D
	add_to_group("units")
	_register_team_groups()
	_setup_wall_collision()
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		navigation_agent.avoidance_enabled = true
		navigation_agent.max_speed = effective_move_speed()


func _setup_wall_collision() -> void:
	## Layer 1 = units. Layer 2 = solid walls. 4 = player gates. 8 = enemy gates.
	collision_layer = 1
	collision_mask = 1 | 2
	if team == 0:
		collision_mask |= 8
	else:
		collision_mask |= 4


func configure_facing_sprites(unit_key: String) -> void:
	_facing_textures = {
		"down": load("res://assets/sprites/units/%s_down.png" % unit_key),
		"left": load("res://assets/sprites/units/%s_left.png" % unit_key),
		"right": load("res://assets/sprites/units/%s_right.png" % unit_key),
		"up": load("res://assets/sprites/units/%s_up.png" % unit_key),
	}
	if _visual == null:
		_visual = get_node_or_null("Visual") as Sprite2D
	if _visual:
		_visual.centered = true
		_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_apply_facing_texture()


func _apply_facing_texture() -> void:
	if _visual == null or not _facing_textures.has(_facing):
		return
	_visual.texture = _facing_textures[_facing]
	_anchor_sprite_to_feet()


func _anchor_sprite_to_feet() -> void:
	## Bottom of sprite at unit origin (no fixed offset.y=8).
	if _visual == null or _visual.texture == null:
		return
	_visual.centered = true
	_visual.offset = Vector2(0.0, -float(_visual.texture.get_height()) * 0.5)


func _update_facing_from_velocity() -> void:
	if velocity.length_squared() < 4.0:
		return
	var next_facing: String
	if absf(velocity.x) > absf(velocity.y):
		next_facing = "right" if velocity.x > 0.0 else "left"
	else:
		next_facing = "down" if velocity.y > 0.0 else "up"
	if next_facing == _facing:
		return
	_facing = next_facing
	_apply_facing_texture()


func _hp_bar_y() -> float:
	if _visual and _visual.texture:
		# Feet at origin; bar above sprite top.
		return -float(_visual.texture.get_height()) - 6.0
	return -28.0


func _register_team_groups() -> void:
	if team == 0:
		add_to_group("player_units")
		if contribute_population:
			GameManager.change_population(1)
	else:
		add_to_group("enemy_units")
	if BalanceSim.active and unit_id != "" and unit_id != "villager":
		BalanceSim.record_unit_trained(team, unit_id)


func _hp_fill_color() -> Color:
	return Color(0.2, 0.85, 0.25, 0.95) if team == 0 else Color(0.9, 0.2, 0.15, 0.95)


func _draw() -> void:
	if selected:
		draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 28, Color(1.0, 0.9, 0.2, 0.95), 2.0)
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	var bar_w := 20.0
	var bar_y := _hp_bar_y()
	draw_rect(Rect2(Vector2(-bar_w * 0.5, bar_y), Vector2(bar_w, 3.0)), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(Vector2(-bar_w * 0.5, bar_y), Vector2(bar_w * ratio, 3.0)), _hp_fill_color())


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func set_movement_target(target: Vector2) -> void:
	_move_goal = target
	_wall_waypoints.clear()
	var tree := get_tree()
	if tree and not WallNav.occupancy_map(tree).is_empty():
		if not WallNav.path_exists(global_position, target, team, tree):
			if can_attack:
				var wall := WallNav.nearest_blocking_segment(global_position, target, team, tree)
				if wall:
					command_attack(wall)
					return
			# No path and cannot attack — stop.
			stop_movement()
			return
		var path := WallNav.find_path(global_position, target, team, tree)
		if not path.is_empty():
			_wall_waypoints = path
			if navigation_agent:
				navigation_agent.target_position = _wall_waypoints[0]
			return
	if navigation_agent:
		navigation_agent.target_position = target


func stop_movement() -> void:
	_wall_waypoints.clear()
	if navigation_agent:
		navigation_agent.target_position = global_position
		navigation_agent.velocity = Vector2.ZERO
	velocity = Vector2.ZERO


func is_navigation_finished() -> bool:
	if not _wall_waypoints.is_empty():
		return false
	return navigation_agent == null or navigation_agent.is_navigation_finished()


func effective_move_speed() -> float:
	if _move_speed_cap < 0.0:
		return speed
	return minf(speed, _move_speed_cap)


func command_move(world_pos: Vector2, speed_cap: float = -1.0) -> void:
	attack_target = null
	_move_speed_cap = speed_cap
	if navigation_agent:
		navigation_agent.max_speed = effective_move_speed()
	set_movement_target(world_pos)


func is_friendly_target(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return true
	if "team" in target and int(target.get("team")) == team:
		return true
	if team == 0 and (target.is_in_group("player_buildings") or target.is_in_group("player_town_hall") or target.is_in_group("player_units")):
		return true
	if team != 0 and (target.is_in_group("enemy_buildings") or target.is_in_group("enemy_town_hall") or target.is_in_group("enemy_units")):
		return true
	return false


func is_structure_target(target: Node2D) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	return (
		target is Building
		or target is DropOff
		or target is WallSegment
		or target is Gate
		or target.is_in_group("player_town_hall")
		or target.is_in_group("enemy_town_hall")
		or target.is_in_group("walls")
		or target.is_in_group("gates")
	)


func command_attack(target: Node2D) -> void:
	if not can_attack or target == null or not is_instance_valid(target):
		return
	if is_friendly_target(target):
		print("[COMBAT] refuse friendly fire team=%d -> %s" % [team, target.name])
		return
	if buildings_only and not is_structure_target(target):
		print("[COMBAT] siege refuse non-building %s" % target.name)
		return
	attack_target = target
	_move_speed_cap = -1.0
	_wall_waypoints.clear()
	_move_goal = target.global_position
	if navigation_agent:
		navigation_agent.max_speed = effective_move_speed()
		navigation_agent.target_position = target.global_position


func command_stop() -> void:
	attack_target = null
	_move_speed_cap = -1.0
	if navigation_agent:
		navigation_agent.max_speed = speed
	stop_movement()


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if can_attack and is_instance_valid(attack_target):
		if is_friendly_target(attack_target):
			print("[COMBAT] clear friendly attack_target %s" % attack_target.name)
			attack_target = null
			stop_movement()
			return
		_chase_and_attack()
	else:
		attack_target = null
		_steer_toward_target()


func _chase_and_attack() -> void:
	var dist := global_position.distance_to(attack_target.global_position)
	var reach := attack_range + _target_radius(attack_target)
	if min_attack_range > 0.0 and dist < min_attack_range:
		## Too close for siege artillery — back off.
		var away := global_position - attack_target.global_position
		if away.length_squared() < 0.01:
			away = Vector2.RIGHT
		var retreat := global_position + away.normalized() * (min_attack_range - dist + 24.0)
		_move_goal = retreat
		_wall_waypoints.clear()
		if navigation_agent:
			navigation_agent.max_speed = effective_move_speed()
			navigation_agent.target_position = retreat
		_steer_toward_target()
		return
	if dist <= reach:
		stop_movement()
		_try_strike()
	else:
		_move_goal = attack_target.global_position
		_wall_waypoints.clear()
		if navigation_agent:
			navigation_agent.target_position = attack_target.global_position
		_steer_toward_target()


func _try_strike() -> void:
	if _attack_timer > 0.0 or not is_instance_valid(attack_target):
		return
	if is_friendly_target(attack_target):
		print("[COMBAT] refuse strike friendly %s" % attack_target.name)
		attack_target = null
		return
	if buildings_only and not is_structure_target(attack_target):
		print("[COMBAT] siege refuse strike non-building %s" % attack_target.name)
		attack_target = null
		return
	if min_attack_range > 0.0:
		var dist := global_position.distance_to(attack_target.global_position)
		if dist < min_attack_range:
			return
	_attack_timer = attack_cooldown
	var damage := attack_damage
	if attack_target is Unit and (attack_target as Unit).is_cavalry:
		damage += bonus_vs_cavalry
	if attack_target is Building or attack_target is DropOff:
		damage += bonus_vs_buildings
	## BalanceSim: soft TC until ~12 min so boom/FC can age; then resolve fights.
	if BalanceSim.active and attack_target is DropOff:
		if BalanceSim.elapsed() < 720.0:
			damage *= 0.25 ## chip only — keeps avg length in 12–30 min
		else:
			damage *= 5.0
	if attack_target.has_method("take_damage"):
		attack_target.call("take_damage", damage, attack_type)
		if attack_type == "pierce":
			AudioManager.play_sfx("bow_shot")
		else:
			AudioManager.play_sfx("melee_hit")
		print("[COMBAT] team%d hit %s for %.1f (%s)" % [team, attack_target.name, damage, attack_type])
	if not is_instance_valid(attack_target):
		attack_target = null


func _target_radius(target: Node2D) -> float:
	if target is Building:
		return (target as Building).footprint.length() * 0.25
	if target is DropOff:
		return (target as DropOff).dropoff_radius * 0.5
	return 8.0


func _steer_toward_target() -> void:
	if not _wall_waypoints.is_empty():
		var wp: Vector2 = _wall_waypoints[0]
		if global_position.distance_to(wp) <= 12.0:
			_wall_waypoints.pop_front()
			if _wall_waypoints.is_empty():
				if navigation_agent:
					navigation_agent.target_position = _move_goal
			else:
				if navigation_agent:
					navigation_agent.target_position = _wall_waypoints[0]
		elif navigation_agent:
			navigation_agent.target_position = wp
	if not navigation_agent or (navigation_agent.is_navigation_finished() and _wall_waypoints.is_empty()):
		stop_movement()
		return
	var next_pos := navigation_agent.get_next_path_position()
	var direction := (next_pos - global_position).normalized()
	var move_spd := effective_move_speed()
	navigation_agent.max_speed = move_spd
	navigation_agent.velocity = direction * move_spd


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	_update_facing_from_velocity()
	move_and_slide()


func take_damage(amount: float, dmg_type: String = "melee") -> void:
	var armor := pierce_armor if dmg_type == "pierce" else melee_armor
	var dealt := maxf(1.0, amount - armor)
	hp -= dealt
	queue_redraw()
	if team == 0:
		AudioManager.play_under_attack()
	if hp <= 0.0:
		die()


func die() -> void:
	died.emit(self)
	if team == 0:
		GameManager.change_population(-1)
	SelectionManager.notify_unit_removed(self)
	print("[COMBAT] unit died team=%d name=%s" % [team, name])
	queue_free()