extends CharacterBody2D
class_name Unit

@export var speed: float = 80.0
@export var max_hp: float = 40.0

var hp: float

@onready var navigation_agent: NavigationAgent2D = $NavigationAgent2D


func _ready() -> void:
	hp = max_hp
	if navigation_agent:
		navigation_agent.velocity_computed.connect(_on_velocity_computed)
		navigation_agent.avoidance_enabled = true
		navigation_agent.max_speed = speed


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


func _physics_process(_delta: float) -> void:
	_steer_toward_target()


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
	if hp <= 0.0:
		die()


func die() -> void:
	GameManager.change_population(-1)
	queue_free()
