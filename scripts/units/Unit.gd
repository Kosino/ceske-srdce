extends CharacterBody2D
class_name Unit

signal died(unit: Unit)

@export var team: int = 0
@export var speed: float = 80.0
@export var max_hp: float = 25.0
@export var attack_damage: float = 3.0
@export var attack_range: float = 36.0
@export var attack_cooldown: float = 0.8
@export var can_attack: bool = true
@export var is_cavalry: bool = false
@export var bonus_vs_cavalry: float = 0.0
## When false, population was already reserved (e.g. production queue).
@export var contribute_population: bool = true

var hp: float
var selected: bool = false
var attack_target: Node2D = null
var _attack_timer: float = 0.0
var _facing: String = "down"
var _facing_textures: Dictionary = {}
var _visual: Sprite2D

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	hp = max_hp
	_visual = get_node_or_null("Visual") as Sprite2D
	add_to_group("units")
	_register_team_groups()
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		navigation_agent.avoidance_enabled = true
		navigation_agent.max_speed = speed


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
		_visual.offset = Vector2(0.0, 8.0)
	_apply_facing_texture()


func _apply_facing_texture() -> void:
	if _visual == null or not _facing_textures.has(_facing):
		return
	_visual.texture = _facing_textures[_facing]


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
		return _visual.offset.y - float(_visual.texture.get_height()) * 0.5 - 6.0
	return -28.0


func _register_team_groups() -> void:
	if team == 0:
		add_to_group("player_units")
		if contribute_population:
			GameManager.change_population(1)
	else:
		add_to_group("enemy_units")


func _draw() -> void:
	if selected:
		draw_arc(Vector2.ZERO, 14.0, 0.0, TAU, 28, Color(1.0, 0.9, 0.2, 0.95), 2.0)
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	var bar_w := 20.0
	var bar_y := _hp_bar_y()
	draw_rect(Rect2(Vector2(-bar_w * 0.5, bar_y), Vector2(bar_w, 3.0)), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(Vector2(-bar_w * 0.5, bar_y), Vector2(bar_w * ratio, 3.0)), Color(0.2, 0.85, 0.25, 0.95))


func set_selected(value: bool) -> void:
	selected = value
	queue_redraw()


func set_movement_target(target: Vector2) -> void:
	if navigation_agent:
		navigation_agent.target_position = target


func stop_movement() -> void:
	if navigation_agent:
		navigation_agent.target_position = global_position
		navigation_agent.velocity = Vector2.ZERO
	velocity = Vector2.ZERO


func is_navigation_finished() -> bool:
	return navigation_agent == null or navigation_agent.is_navigation_finished()


func command_move(world_pos: Vector2) -> void:
	attack_target = null
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


func command_attack(target: Node2D) -> void:
	if not can_attack or target == null or not is_instance_valid(target):
		return
	if is_friendly_target(target):
		print("[COMBAT] refuse friendly fire team=%d -> %s" % [team, target.name])
		return
	attack_target = target
	set_movement_target(target.global_position)


func command_stop() -> void:
	attack_target = null
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
	var reach := attack_range + _target_radius(attack_target)
	if global_position.distance_to(attack_target.global_position) <= reach:
		stop_movement()
		_try_strike()
	else:
		set_movement_target(attack_target.global_position)
		_steer_toward_target()


func _try_strike() -> void:
	if _attack_timer > 0.0 or not is_instance_valid(attack_target):
		return
	if is_friendly_target(attack_target):
		print("[COMBAT] refuse strike friendly %s" % attack_target.name)
		attack_target = null
		return
	_attack_timer = attack_cooldown
	var damage := attack_damage
	if attack_target is Unit and (attack_target as Unit).is_cavalry:
		damage += bonus_vs_cavalry
	if attack_target.has_method("take_damage"):
		attack_target.call("take_damage", damage)
		print("[COMBAT] team%d hit %s for %.1f" % [team, attack_target.name, damage])
	if not is_instance_valid(attack_target):
		attack_target = null


func _target_radius(target: Node2D) -> float:
	if target is Building:
		return (target as Building).footprint.length() * 0.25
	if target is DropOff:
		return (target as DropOff).dropoff_radius * 0.5
	return 8.0


func _steer_toward_target() -> void:
	if not navigation_agent or navigation_agent.is_navigation_finished():
		stop_movement()
		return
	var next_pos := navigation_agent.get_next_path_position()
	var direction := (next_pos - global_position).normalized()
	navigation_agent.velocity = direction * speed


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	_update_facing_from_velocity()
	move_and_slide()


func take_damage(amount: float) -> void:
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		die()


func die() -> void:
	died.emit(self)
	if team == 0:
		GameManager.change_population(-1)
	SelectionManager.notify_unit_removed(self)
	print("[COMBAT] unit died team=%d name=%s" % [team, name])
	queue_free()