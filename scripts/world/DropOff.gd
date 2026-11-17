extends Node2D
class_name DropOff

signal destroyed(hall: DropOff)
signal queue_changed

const VILLAGER_SCENE := preload("res://scenes/units/Villager.tscn")
## DESIGN: Vesničan 50 J, 25 s.
const VILLAGER_COST := {"food": 50}
const VILLAGER_TIME := 25.0
const MAX_QUEUE := 5

@export var team: int = 0
@export var dropoff_radius: float = 48.0
@export var building_name: String = "Radnice"
## DESIGN: Radnice HP 2400, +5 populace.
@export var max_hp: float = 2400.0
@export var population_bonus: int = 5
@export var accepted_resources: PackedStringArray = ["food", "wood", "gold", "stone"]

var hp: float
var queue: Array[String] = []
var train_remaining: float = 0.0
var spawn_parent: Node2D


func _ready() -> void:
	hp = max_hp
	add_to_group("dropoffs")
	add_to_group("town_halls")
	if team == 0:
		add_to_group("player_town_hall")
		add_to_group("player_buildings")
		GameManager.add_population_cap(population_bonus)
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


func accepts(resource_type: String) -> bool:
	return resource_type in accepted_resources


func _process(delta: float) -> void:
	if team != 0 or queue.is_empty():
		return
	train_remaining -= delta
	if train_remaining <= 0.0:
		_complete_training()


func enqueue_villager() -> bool:
	if team != 0:
		return false
	if queue.size() >= MAX_QUEUE:
		NotificationManager.show_message("Fronta radnice je plná.")
		return false
	if not GameManager.can_add_population(1):
		NotificationManager.show_message("Nedostatek populace (postav Dům).")
		return false
	if not GameManager.spend(VILLAGER_COST):
		NotificationManager.show_message("Nedostatek surovin na vesničana.")
		return false
	GameManager.change_population(1)
	queue.append("villager")
	if queue.size() == 1:
		train_remaining = VILLAGER_TIME
	queue_changed.emit()
	print("[PROD] queued villager (queue=%d)" % queue.size())
	return true


func get_queue_summary() -> String:
	if queue.is_empty():
		return "fronta prázdná"
	return "fronta %d | %.1fs" % [queue.size(), maxf(train_remaining, 0.0)]


func _complete_training() -> void:
	if queue.is_empty():
		return
	queue.pop_front()
	var villager: Villager = VILLAGER_SCENE.instantiate() as Villager
	villager.contribute_population = false
	villager.team = team
	var parent := spawn_parent if spawn_parent else get_parent()
	villager.position = global_position + Vector2(0, 56.0)
	parent.add_child(villager)
	# Ensure selectable after spawn (team groups from Unit._ready).
	if villager.team == 0 and not villager.is_in_group("player_units"):
		villager.add_to_group("player_units")
	print("[PROD] spawned villager at %s groups_ok=%s" % [str(villager.position), villager.is_in_group("player_units")])
	NotificationManager.show_message("Vycvičen vesničan.")
	queue_changed.emit()
	if not queue.is_empty():
		train_remaining = VILLAGER_TIME


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