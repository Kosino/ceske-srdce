extends Node2D

const MAP_SIZE := Vector2(2000, 2000)
const VILLAGER_SCENE := preload("res://scenes/units/Villager.tscn")
const RESOURCE_SCENE := preload("res://scenes/world/ResourceNode.tscn")
const DROPOFF_SCENE := preload("res://scenes/world/DropOff.tscn")

@onready var navigation_region: NavigationRegion2D = $NavigationRegion2D
@onready var entities: Node2D = $Entities
@onready var building_placer: BuildingPlacer = $BuildingPlacer


func _ready() -> void:
	_setup_navigation()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_spawn_gathering_demo()
	_spawn_building_demo()
	NotificationManager.show_message("Stavění: Dům/Kasárna z debug panelu, Train = fronta.")


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
	dropoff.position = Vector2(1000, 1000)
	entities.add_child(dropoff)

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
	# Deterministic placement for headless validation + playable starting buildings.
	building_placer.place_at("house", Vector2(880, 940))
	var barracks := building_placer.place_at("barracks", Vector2(1120, 1080))
	if barracks is Barracks:
		var b := barracks as Barracks
		b.enqueue_soldier()
		b.enqueue_soldier()
