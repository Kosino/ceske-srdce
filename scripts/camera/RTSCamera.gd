extends Camera2D

@export var move_speed: float = 500.0
@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.35
@export var max_zoom: float = 2.5
@export var map_size: Vector2 = Vector2(2000, 2000)

func _ready() -> void:
	make_current()


func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0

	if direction != Vector2.ZERO:
		var zoom_factor := maxf(zoom.x, 0.01)
		position += direction.normalized() * move_speed * delta / zoom_factor
		position = position.clamp(Vector2.ZERO, map_size)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		var next_zoom := zoom.x
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			next_zoom += zoom_step
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			next_zoom -= zoom_step
		else:
			return
		next_zoom = clampf(next_zoom, min_zoom, max_zoom)
		zoom = Vector2(next_zoom, next_zoom)
