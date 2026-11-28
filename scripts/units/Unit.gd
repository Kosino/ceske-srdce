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

## Walk sheet: 4 cols (frames) × 4 rows (down, left, right, up). Missing → idle only.
const WALK_DIRS: Array[String] = ["down", "left", "right", "up"]
const WALK_FRAME_COUNT := 4
const WALK_FPS := 8.0
const WALK_MOVE_EPS_SQ := 4.0
## AoE-style underfoot team blob (inside selection ring r=14 so arcs do not collide).
const SELECTION_RING_RADIUS := 14.0
const TEAM_MARKER_RX := 8.0
const TEAM_MARKER_RY := 4.5
const TEAM_MARKER_ALPHA := 0.9

var hp: float
var selected: bool = false
var attack_target: Node2D = null
var _attack_timer: float = 0.0
var _facing: String = "down"
var _facing_textures: Dictionary = {}
var _visual: Sprite2D
var _unit_key: String = ""
var _walk_sheet: Texture2D = null
var _walk_frame: int = 0
var _walk_accum: float = 0.0
var _walk_active: bool = false
## When >= 0, group formation move uses min(speed, cap) so the group keeps pace.
var _move_speed_cap: float = -1.0
## Wall-aware waypoint path (tile centers); empty = use NavigationAgent alone.
var _wall_waypoints: Array[Vector2] = []
var _move_goal: Vector2 = Vector2.ZERO
## T-35 garrison: walk-to building, or currently inside a host.
var _garrison_target: Node = null
var is_garrisoned: bool = false
var garrison_host: Node = null

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
	_unit_key = unit_key
	_facing_textures = {
		"down": load("res://assets/sprites/units/%s_down.png" % unit_key),
		"left": load("res://assets/sprites/units/%s_left.png" % unit_key),
		"right": load("res://assets/sprites/units/%s_right.png" % unit_key),
		"up": load("res://assets/sprites/units/%s_up.png" % unit_key),
	}
	_walk_sheet = null
	var walk_path := "res://assets/sprites/units/%s_walk.png" % unit_key
	if ResourceLoader.exists(walk_path):
		_walk_sheet = load(walk_path) as Texture2D
	_walk_frame = 0
	_walk_accum = 0.0
	_walk_active = false
	if _visual == null:
		_visual = get_node_or_null("Visual") as Sprite2D
	if _visual:
		_visual.centered = true
		_visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_visual.hframes = 1
		_visual.vframes = 1
		_visual.frame = 0
	_apply_facing_texture()
	_apply_team_visual()


func has_walk_sheet() -> bool:
	return _walk_sheet != null


func walk_frame() -> int:
	return _walk_frame


func is_walk_animating() -> bool:
	return _walk_active


## Palette-swap team cloth/shields (AoE II style). Used after spawn and on convert.
func _apply_team_visual() -> void:
	if _visual == null:
		_visual = get_node_or_null("Visual") as Sprite2D
	if _visual == null:
		return
	TeamColors.apply(_visual, team)


func _idle_texture_height() -> float:
	if _facing_textures.has(_facing) and _facing_textures[_facing] != null:
		return float((_facing_textures[_facing] as Texture2D).get_height())
	return 0.0


func _walk_cell_height() -> float:
	if _walk_sheet == null:
		return 0.0
	return float(_walk_sheet.get_height()) / float(WALK_DIRS.size())


## Scale walk cells so on-screen height matches the idle facing sprite (feet stay on origin).
func _walk_size_scale() -> float:
	var idle_h := _idle_texture_height()
	var cell_h := _walk_cell_height()
	if idle_h <= 0.0 or cell_h <= 0.0:
		return 1.0
	return idle_h / cell_h


func visual_draw_height() -> float:
	## Texture cell height × |scale.y| — used by size-parity smoke.
	if _visual == null or _visual.texture == null:
		return 0.0
	var tex_h := float(_visual.texture.get_height())
	if _visual.vframes > 1:
		tex_h /= float(_visual.vframes)
	return tex_h * absf(_visual.scale.y)


func _apply_facing_texture() -> void:
	## Idle facing texture. Does not touch modulate/material (T-18).
	if _visual == null or not _facing_textures.has(_facing):
		return
	_walk_active = false
	_visual.hframes = 1
	_visual.vframes = 1
	_visual.frame = 0
	_visual.texture = _facing_textures[_facing]
	_visual.scale = Vector2.ONE
	_anchor_sprite_to_feet()


func _apply_walk_frame() -> void:
	## Walk sheet cell. Does not touch modulate/material (T-18).
	if _visual == null or _walk_sheet == null:
		return
	_walk_active = true
	_visual.texture = _walk_sheet
	_visual.hframes = WALK_FRAME_COUNT
	_visual.vframes = WALK_DIRS.size()
	var row := WALK_DIRS.find(_facing)
	if row < 0:
		row = 0
	_visual.frame = row * WALK_FRAME_COUNT + clampi(_walk_frame, 0, WALK_FRAME_COUNT - 1)
	var s := _walk_size_scale()
	_visual.scale = Vector2(s, s)
	_anchor_sprite_to_feet()


func _anchor_sprite_to_feet() -> void:
	## Bottom of sprite at unit origin (no fixed offset.y=8).
	## Offset is in local (pre-scale) space so feet stay put when walk scale ≠ 1.
	if _visual == null or _visual.texture == null:
		return
	_visual.centered = true
	var tex_h := float(_visual.texture.get_height())
	if _visual.vframes > 1:
		tex_h /= float(_visual.vframes)
	_visual.offset = Vector2(0.0, -tex_h * 0.5)


func _update_facing_from_velocity() -> void:
	if velocity.length_squared() < WALK_MOVE_EPS_SQ:
		return
	var next_facing: String
	if absf(velocity.x) > absf(velocity.y):
		next_facing = "right" if velocity.x > 0.0 else "left"
	else:
		next_facing = "down" if velocity.y > 0.0 else "up"
	if next_facing == _facing:
		return
	_facing = next_facing
	if _walk_active and _walk_sheet != null:
		_apply_walk_frame()
	else:
		_apply_facing_texture()


func _update_walk_animation(delta: float) -> void:
	var moving := velocity.length_squared() >= WALK_MOVE_EPS_SQ
	if not moving:
		_walk_accum = 0.0
		_walk_frame = 0
		if _walk_active:
			_apply_facing_texture()
		return
	if _walk_sheet == null:
		## No walk sheet → keep static facing (updated by _update_facing_from_velocity).
		return
	_walk_accum += delta
	var step := 1.0 / WALK_FPS
	while _walk_accum >= step:
		_walk_accum -= step
		_walk_frame = (_walk_frame + 1) % WALK_FRAME_COUNT
	_apply_walk_frame()


func _hp_bar_y() -> float:
	if _visual and _visual.texture:
		# Feet at origin; bar above sprite top (account for walk size scale).
		return -visual_draw_height() - 6.0
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


## Re-add combat/selection groups after leaving garrison (no population delta).
func _register_team_groups_soft() -> void:
	if team == 0:
		if not is_in_group("player_units"):
			add_to_group("player_units")
	else:
		if not is_in_group("enemy_units"):
			add_to_group("enemy_units")


func _hp_fill_color() -> Color:
	return Color(0.2, 0.85, 0.25, 0.95) if team == 0 else Color(0.9, 0.2, 0.15, 0.95)


## T-28: team colour for the underfoot oval (player blue / AI red).
func team_marker_color() -> Color:
	var c := TeamColors.color_for(team)
	c.a = TEAM_MARKER_ALPHA
	return c


func _draw_team_marker() -> void:
	## Filled ellipse under feet; max radius < selection ring so they do not collide.
	var col := team_marker_color()
	var pts := PackedVector2Array()
	const SEGMENTS := 20
	for i in SEGMENTS:
		var a := TAU * float(i) / float(SEGMENTS)
		pts.append(Vector2(cos(a) * TEAM_MARKER_RX, sin(a) * TEAM_MARKER_RY))
	draw_colored_polygon(pts, col)


func _draw() -> void:
	_draw_team_marker()
	if selected:
		draw_arc(Vector2.ZERO, SELECTION_RING_RADIUS, 0.0, TAU, 28, Color(1.0, 0.9, 0.2, 0.95), 2.0)
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
	_walk_accum = 0.0
	_walk_frame = 0
	if _walk_active:
		_apply_facing_texture()


func is_navigation_finished() -> bool:
	if not _wall_waypoints.is_empty():
		return false
	return navigation_agent == null or navigation_agent.is_navigation_finished()


func effective_move_speed() -> float:
	if _move_speed_cap < 0.0:
		return speed
	return minf(speed, _move_speed_cap)


func command_move(world_pos: Vector2, speed_cap: float = -1.0) -> void:
	if is_garrisoned:
		return
	_garrison_target = null
	attack_target = null
	_move_speed_cap = speed_cap
	if navigation_agent:
		navigation_agent.max_speed = effective_move_speed()
	set_movement_target(world_pos)


## Walk to a garrison host and enter when in range.
func command_garrison(building: Node) -> void:
	if is_garrisoned or not GarrisonController.can_garrison_unit(self):
		return
	if not GarrisonController.can_host(building):
		return
	if "team" in building and int(building.get("team")) != team:
		return
	var g := GarrisonController.ensure(building)
	if g == null or g.is_full():
		if g != null and g.is_full():
			NotificationManager.show_message("Posádka je plná (%d)." % g.capacity)
		return
	attack_target = null
	_garrison_target = building
	_move_speed_cap = -1.0
	if navigation_agent:
		navigation_agent.max_speed = effective_move_speed()
	var dest := (building as Node2D).global_position if building is Node2D else global_position
	set_movement_target(dest)


## Returns true if this frame was consumed by garrison approach / enter.
func _try_garrison_approach() -> bool:
	if is_garrisoned:
		stop_movement()
		return true
	if _garrison_target == null:
		return false
	if not is_instance_valid(_garrison_target) or not GarrisonController.can_host(_garrison_target):
		_garrison_target = null
		return false
	var dest := (_garrison_target as Node2D).global_position
	var reach := GarrisonController.ENTER_RANGE
	if _garrison_target is Building:
		reach += (_garrison_target as Building).footprint.length() * 0.2
	elif _garrison_target is DropOff:
		reach += ( _garrison_target as DropOff).dropoff_radius * 0.35
	if global_position.distance_to(dest) <= reach:
		var g := GarrisonController.ensure(_garrison_target)
		if g and g.try_enter(self):
			return true
		_garrison_target = null
		stop_movement()
		return true
	set_movement_target(dest)
	_steer_toward_target()
	return true


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
	if is_garrisoned:
		return
	if not can_attack or target == null or not is_instance_valid(target):
		return
	if is_friendly_target(target):
		print("[COMBAT] refuse friendly fire team=%d -> %s" % [team, target.name])
		return
	if buildings_only and not is_structure_target(target):
		print("[COMBAT] siege refuse non-building %s" % target.name)
		return
	_garrison_target = null
	attack_target = target
	_move_speed_cap = -1.0
	_wall_waypoints.clear()
	_move_goal = target.global_position
	if navigation_agent:
		navigation_agent.max_speed = effective_move_speed()
		navigation_agent.target_position = target.global_position


func command_stop() -> void:
	if is_garrisoned:
		return
	_garrison_target = null
	attack_target = null
	_move_speed_cap = -1.0
	if navigation_agent:
		navigation_agent.max_speed = speed
	stop_movement()


func _physics_process(delta: float) -> void:
	if is_garrisoned:
		return
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if _try_garrison_approach():
		return
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
	_update_walk_animation(get_physics_process_delta_time())
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
	if is_garrisoned and garrison_host != null:
		var g := GarrisonController.of(garrison_host)
		if g:
			g.garrisoned.erase(self)
	died.emit(self)
	if team == 0:
		GameManager.change_population(-1)
	SelectionManager.notify_unit_removed(self)
	print("[COMBAT] unit died team=%d name=%s" % [team, name])
	queue_free()