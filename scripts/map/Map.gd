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
	await _run_friendly_target_smoke()
	NotificationManager.show_message("Start: Radnice + vesničané + zdroje. F3 stavění/trénink.")


func _spawn_core_demo() -> void:
	# DESIGN start: only Radnice, villagers, and resource nodes (no prebuilt House/Pila/combat).
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

	for offset in [Vector2(940, 720), Vector2(920, 740), Vector2(960, 740)]:
		var villager: Villager = VILLAGER_SCENE.instantiate()
		villager.position = offset
		units.add_child(villager)


## Headless/manual regression: own buildings must not take friendly damage.
func _run_friendly_target_smoke() -> void:
	await get_tree().physics_frame
	var hall := get_tree().get_first_node_in_group("player_town_hall") as DropOff
	if hall == null:
		print("[TEST] FAIL no player town hall")
		return
	var hp_before := hall.hp

	var soldier: Soldier = SOLDIER_SCENE.instantiate()
	soldier.team = 0
	soldier.contribute_population = false
	soldier.position = hall.global_position + Vector2(40, 40)
	units.add_child(soldier)
	await get_tree().physics_frame

	soldier.command_attack(hall)
	await get_tree().create_timer(0.3).timeout

	var refused := soldier.attack_target == null
	var hp_ok := is_equal_approx(hall.hp, hp_before)
	print("[TEST] friendly_fire refused=%s hp_unchanged=%s (hp=%.1f)" % [refused, hp_ok, hall.hp])
	if not refused or not hp_ok:
		print("[TEST] FAIL friendly fire check")
	else:
		print("[TEST] PASS friendly fire check")

	var villager := get_tree().get_first_node_in_group("player_units") as Villager
	if villager:
		villager.command_attack(hall)
		print("[TEST] villager_attack_target_null=%s" % [villager.attack_target == null])
		villager.command_move(hall.global_position + Vector2(80, 0))
		await get_tree().physics_frame
		print("[TEST] villager_moving_state=%s" % [villager.state == Villager.State.MOVING])

	soldier.queue_free()