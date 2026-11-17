extends CharacterBody2D
class_name Unit

signal died(unit: Unit)

@export var team: int = 0
@export var speed: float = 80.0
@export var max_hp: float = 40.0
@export var attack_damage: float = 5.0
@export var attack_range: float = 36.0
@export var attack_cooldown: float = 0.8
@export var can_attack: bool = true

var hp: float
var selected: bool = false
var attack_target: Node2D = null
var _attack_timer: float = 0.0

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	hp = max_hp
	add_to_group("units")
	if team == 0:
		add_to_group("player_units")
	else:
		add_to_group("enemy_units")
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		navigation_agent.avoidance_enabled = true
		navigation_agent.max_speed = speed


func _draw() -> void:
	if selected:
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 28, Color(1.0, 0.9, 0.2, 0.95), 2.0)
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	var bar_w := 24.0
	draw_rect(Rect2(Vector2(-bar_w * 0.5, -22.0), Vector2(bar_w, 3.0)), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(Vector2(-bar_w * 0.5, -22.0), Vector2(bar_w * ratio, 3.0)), Color(0.2, 0.85, 0.25, 0.95))


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


func command_move(world_pos: Vector2) -> void:
	attack_target = null
	set_movement_target(world_pos)


func command_attack(target: Node2D) -> void:
	if not can_attack or target == null or not is_instance_valid(target):
		return
	if "team" in target and int(target.get("team")) == team:
		return
	attack_target = target
	set_movement_target(target.global_position)


func command_stop() -> void:
	attack_target = null
	stop_movement()


func is_navigation_finished() -> bool:
	return navigation_agent == null or navigation_agent.is_navigation_finished()


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	if can_attack and is_instance_valid(attack_target):
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
	_attack_timer = attack_cooldown
	if attack_target.has_method("take_damage"):
		attack_target.call("take_damage", attack_damage)
		print("[COMBAT] team%d hit %s for %.1f" % [team, attack_target.name, attack_damage])
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
