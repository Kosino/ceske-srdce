extends Node2D
class_name Building

signal destroyed(building: Building)

@export var team: int = 0
@export var building_id: String = ""
@export var display_name: String = "Budova"
@export var max_hp: float = 500.0
@export var footprint: Vector2 = Vector2(72, 72)

var hp: float


func _ready() -> void:
	hp = max_hp
	add_to_group("buildings")
	if team == 0:
		add_to_group("player_buildings")
	else:
		add_to_group("enemy_buildings")
	if has_node("Label"):
		$Label.text = display_name


func _draw() -> void:
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	var bar_w := footprint.x * 0.8
	draw_rect(Rect2(Vector2(-bar_w * 0.5, -footprint.y * 0.5 - 10.0), Vector2(bar_w, 4.0)), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(Vector2(-bar_w * 0.5, -footprint.y * 0.5 - 10.0), Vector2(bar_w * ratio, 4.0)), Color(0.85, 0.25, 0.2, 0.95))


func take_damage(amount: float) -> void:
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		die()


func die() -> void:
	destroyed.emit(self)
	print("[COMBAT] building destroyed team=%d id=%s" % [team, building_id])
	queue_free()
