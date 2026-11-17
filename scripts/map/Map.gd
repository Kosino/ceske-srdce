extends Node2D

const MAP_SIZE := Vector2(2000, 2000)
const VILLAGER_SCENE := preload("res://scenes/units/Villager.tscn")
const RESOURCE_SCENE := preload("res://scenes/world/ResourceNode.tscn")
const DROPOFF_SCENE := preload("res://scenes/world/DropOff.tscn")
const SOLDIER_SCENE := preload("res://scenes/units/Soldier.tscn")

@onready var navigation_region: NavigationRegion2D = $NavigationRegion2D
@onready var entities: Node2D = $Entities
@onready var building_placer: BuildingPlacer = $BuildingPlacer
@onready var victory: VictoryController = $VictoryController


func _ready() -> void:
	_setup_navigation()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_spawn_gathering_demo()
	_spawn_building_demo()
	_spawn_combat_demo()
	NotificationManager.show_message("Combat: LMB výběr, RMB útok/pohyb. Znič nepřátelskou radnici.")


func _setup_navigation() -> void:
	var outline := PackedVector2Array([
		Vector2.ZERO,
		Vector2(MAP_SIZE.x, 0.0),
		MAP_SIZE,
		Vector2(0.0, MAP_SIZE.y),
	])
	var polygon := NavigationPolygon.new()
	polygon.vertices = outline
	polygon.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	polygon.add_outline(outline)
	navigation_region.navigation_polygon = polygon


func _spawn_gathering_demo() -> void:
	var dropoff: DropOff = DROPOFF_SCENE.instantiate()
	dropoff.team = 0
	dropoff.position = Vector2(1000, 1000)
	entities.add_child(dropoff)
	victory.watch_new_hall(dropoff)

	var wood: ResourceNode = RESOURCE_SCENE.instantiate()
	wood.resource_type = "wood"
	wood.amount_remaining = 120
	wood.position = Vector2(1180, 920)
	entities.add_child(wood)

	var food: ResourceNode = RESOURCE_SCENE.instantiate()
	food.resource_type = "food"
	food.amount_remaining = 80
	food.position = Vector2(860, 1120)
	entities.add_child(food)

	var villager: Villager = VILLAGER_SCENE.instantiate()
	villager.position = Vector2(1040, 1000)
	entities.add_child(villager)
	villager.assign_gather(wood, dropoff)


func _spawn_building_demo() -> void:
	building_placer.place_at("house", Vector2(880, 940))
	var barracks := building_placer.place_at("barracks", Vector2(1120, 1080))
	if barracks is Barracks:
		var b := barracks as Barracks
		b.enqueue_soldier()
		b.enqueue_soldier()


func _spawn_combat_demo() -> void:
	var enemy_hall: DropOff = DROPOFF_SCENE.instantiate()
	enemy_hall.team = 1
	enemy_hall.max_hp = 50.0
	enemy_hall.position = Vector2(1320, 1220)
	entities.add_child(enemy_hall)
	victory.watch_new_hall(enemy_hall)

	var enemy: Soldier = SOLDIER_SCENE.instantiate()
	enemy.team = 1
	enemy.position = Vector2(1260, 1180)
	entities.add_child(enemy)

	# Immediate player strike team for headless victory without waiting on train timers.
	for offset in [Vector2(1180, 1140), Vector2(1200, 1160)]:
		var ally: Soldier = SOLDIER_SCENE.instantiate()
		ally.team = 0
		ally.position = offset
		entities.add_child(ally)
		GameManager.change_population(1)
		ally.command_attack(enemy_hall)
