extends Node2D

const VILLAGER_SCENE := preload("res://scenes/units/Villager.tscn")
const RESOURCE_SCENE := preload("res://scenes/world/ResourceNode.tscn")
const DROPOFF_SCENE := preload("res://scenes/world/DropOff.tscn")
const SOLDIER_SCENE := preload("res://scenes/units/Soldier.tscn")

@onready var units: Node2D = $Units
@onready var building_placer: BuildingPlacer = $BuildingPlacer
@onready var victory: VictoryController = $VictoryController


func _ready() -> void:
	await get_tree().physics_frame
	await get_tree().physics_frame
	_spawn_core_demo()
	NotificationManager.show_message("F3 debug. Command: Train Z/K/L/V. Pila/Mlýn drop-off.")


func _spawn_core_demo() -> void:
	var hall: DropOff = DROPOFF_SCENE.instantiate()
	hall.team = 0
	hall.position = Vector2(900, 700)
	hall.spawn_parent = units
	units.add_child(hall)
	victory.watch_new_hall(hall)

	var wood: ResourceNode = RESOURCE_SCENE.instantiate()
	wood.resource_type = "wood"
	wood.amount_remaining = 200
	wood.position = Vector2(1080, 620)
	units.add_child(wood)

	var food: ResourceNode = RESOURCE_SCENE.instantiate()
	food.resource_type = "food"
	food.amount_remaining = 120
	food.position = Vector2(760, 820)
	units.add_child(food)

	var villager: Villager = VILLAGER_SCENE.instantiate()
	villager.position = Vector2(940, 720)
	units.add_child(villager)
	villager.assign_gather(wood)

	building_placer.place_at("house", Vector2(780, 640))
	building_placer.place_at("lumber_camp", Vector2(1000, 560))
	building_placer.place_at("mill", Vector2(820, 860))
	var barracks := building_placer.place_at("barracks", Vector2(1020, 780))
	if barracks is Barracks:
		var b := barracks as Barracks
		b.enqueue_soldier()
		b.enqueue_spearman()

	# Combat demo: enemy hall uses reduced HP so victory is verifiable in headless.
	var enemy_hall: DropOff = DROPOFF_SCENE.instantiate()
	enemy_hall.team = 1
	enemy_hall.max_hp = 90.0
	enemy_hall.population_bonus = 0
	enemy_hall.position = Vector2(1220, 900)
	units.add_child(enemy_hall)
	victory.watch_new_hall(enemy_hall)

	var enemy: Soldier = SOLDIER_SCENE.instantiate()
	enemy.team = 1
	enemy.contribute_population = false
	enemy.position = Vector2(1160, 860)
	units.add_child(enemy)

	for offset in [Vector2(1080, 820), Vector2(1100, 840)]:
		var ally: Soldier = SOLDIER_SCENE.instantiate()
		ally.team = 0
		ally.contribute_population = true
		ally.position = offset
		units.add_child(ally)
		ally.command_attack(enemy_hall)