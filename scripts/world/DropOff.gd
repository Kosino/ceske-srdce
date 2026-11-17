extends Node2D
class_name DropOff

signal destroyed(hall: DropOff)

@export var team: int = 0
@export var dropoff_radius: float = 48.0
@export var building_name: String = "Radnice"
@export var max_hp: float = 800.0

var hp: float


func _ready() -> void:
	hp = max_hp
	add_to_group("town_halls")
	if team == 0:
		add_to_group("player_town_hall")
		add_to_group("player_buildings")
	else:
		add_to_group("enemy_town_hall")
		add_to_group("enemy_buildings")
		building_name = "Nepřátelská radnice"
		if has_node("Visual"):
			$Visual.color = Color(0.35, 0.2, 0.2, 1.0)
		if has_node("Roof"):
			$Roof.color = Color(0.45, 0.1, 0.1, 1.0)
	if has_node("Label"):
		$Label.text = building_name


func _draw() -> void:
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	draw_rect(Rect2(Vector2(-40.0, -70.0), Vector2(80.0, 5.0)), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(Vector2(-40.0, -70.0), Vector2(80.0 * ratio, 5.0)), Color(0.9, 0.2, 0.15, 0.95))


func take_damage(amount: float) -> void:
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		die()


func die() -> void:
	destroyed.emit(self)
	print("[COMBAT] radnice destroyed team=%d" % team)
	queue_free()
