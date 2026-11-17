extends Camera2D

@export var pan_speed: float = 500.0
@export var edge_margin: float = 16.0
@export var zoom_step: float = 0.1
@export var min_zoom: float = 0.4
@export var max_zoom: float = 2.0
@export var map_rect: Rect2 = Rect2(0, 0, 3000, 3000)

func _ready() -> void:
	make_current()
	_clamp_to_map()

func _process(delta: float) -> void:
	var direction := Input.get_vector("camera_left", "camera_right", "camera_up", "camera_down")
	direction += _edge_direction()
	if direction != Vector2.ZERO:
		position += direction.normalized() * pan_speed * delta / zoom.x
	_clamp_to_map()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(zoom.x + zoom_step)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(zoom.x - zoom_step)

func _edge_direction() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2.ZERO
	var mouse := viewport.get_mouse_position()
	var size := viewport.get_visible_rect().size
	if mouse.x < 0.0 or mouse.y < 0.0 or mouse.x > size.x or mouse.y > size.y:
		return Vector2.ZERO
	var direction := Vector2.ZERO
	if mouse.x <= edge_margin:
		direction.x -= 1.0
	elif mouse.x >= size.x - edge_margin:
		direction.x += 1.0
	if mouse.y <= edge_margin:
		direction.y -= 1.0
	elif mouse.y >= size.y - edge_margin:
		direction.y += 1.0
	return direction

func _set_zoom(value: float) -> void:
	zoom = Vector2.ONE * clampf(value, min_zoom, max_zoom)
	_clamp_to_map()

func _clamp_to_map() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var half := viewport.get_visible_rect().size / zoom * 0.5
	position.x = _clamp_axis(position.x, map_rect.position.x, map_rect.end.x, half.x)
	position.y = _clamp_axis(position.y, map_rect.position.y, map_rect.end.y, half.y)

func _clamp_axis(value: float, bound_min: float, bound_max: float, half_view: float) -> float:
	var min_center := bound_min + half_view
	var max_center := bound_max - half_view
	if min_center > max_center:
		return (bound_min + bound_max) * 0.5
	return clampf(value, min_center, max_center)
