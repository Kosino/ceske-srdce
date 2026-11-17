extends CharacterBody2D

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
	if GameManager:
		GameManager.change_population(1)

func _unhandled_input(event: InputEvent) -> void:
	# TEMP: pravé tlačítko pošle všechny jednotky na kurzor. Nahradí se selection systémem.
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		set_movement_target(get_global_mouse_position())

func set_movement_target(target: Vector2) -> void:
	if navigation_agent:
		navigation_agent.target_position = target

func _physics_process(_delta: float) -> void:
	if not navigation_agent or navigation_agent.is_navigation_finished():
		return
	var next_pos = navigation_agent.get_next_path_position()
	var direction = (next_pos - global_position).normalized()
	navigation_agent.velocity = direction * speed

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity
	move_and_slide()

func take_damage(amount: float) -> void:
	hp -= amount
	if hp <= 0:
		die()

func die() -> void:
	if GameManager:
		GameManager.change_population(-1)
	queue_free()
