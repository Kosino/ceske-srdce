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
	await _run_gather_rmb_smoke()
	await _run_construction_smoke()
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


## RMB-style gather: issue_gather must enter harvest and reduce resource (not stay MOVING).
func _run_gather_rmb_smoke() -> void:
	await get_tree().physics_frame
	var wood: ResourceNode = null
	for n in get_tree().get_nodes_in_group("resources"):
		if n is ResourceNode and (n as ResourceNode).resource_type == "wood":
			wood = n as ResourceNode
			break
	var villagers: Array[Villager] = []
	for n in get_tree().get_nodes_in_group("villagers"):
		if n is Villager and (n as Villager).team == 0:
			villagers.append(n as Villager)
	if wood == null or villagers.is_empty():
		print("[TEST] FAIL gather setup missing wood/villagers")
		return

	# Place villagers near the node so navigation isn't flaky in headless.
	for i in villagers.size():
		villagers[i].global_position = wood.global_position + Vector2(18.0 + float(i) * 10.0, 8.0)

	var amount_before := wood.amount_remaining
	SelectionManager.select_multiple(villagers)
	SelectionManager.issue_gather(wood)
	await get_tree().physics_frame

	var ordered := 0
	for v in villagers:
		if v.state == Villager.State.MOVE_TO_RESOURCE or v.state == Villager.State.HARVESTING:
			ordered += 1
	print("[TEST] gather_rmb ordered=%d/%d state0=%s" % [ordered, villagers.size(), villagers[0].state])

	var harvested := false
	for _i in range(40):
		await get_tree().create_timer(0.25).timeout
		if not is_instance_valid(wood):
			harvested = true
			break
		if wood.amount_remaining < amount_before:
			harvested = true
			break

	var amount_after := wood.amount_remaining if is_instance_valid(wood) else 0
	print("[TEST] gather_rmb amount %d -> %d harvested=%s" % [amount_before, amount_after, harvested])
	if ordered > 0 and harvested:
		print("[TEST] PASS gather after RMB adds resource progress")
	else:
		print("[TEST] FAIL gather after RMB")

	SelectionManager.issue_stop()
	await get_tree().physics_frame


## Place house under construction; villager builds; completes after timed progress.
func _run_construction_smoke() -> void:
	await get_tree().physics_frame
	var villager: Villager = null
	for n in get_tree().get_nodes_in_group("villagers"):
		if n is Villager and (n as Villager).team == 0:
			villager = n as Villager
			break
	if villager == null or building_placer == null:
		print("[TEST] FAIL construction setup")
		return

	SelectionManager.select_single(villager)
	var place_pos := Vector2(1100, 780)
	var house := building_placer.place_at("house", place_pos)
	if house == null:
		print("[TEST] FAIL house place")
		return

	# Keep DESIGN formula, but shorten base time so headless finishes quickly.
	house.build_time = 2.0
	villager.global_position = house.global_position + Vector2(30, 0)
	villager.assign_build(house)

	var started_incomplete := not house.is_complete and house.build_progress < 0.05
	var low_hp := house.hp <= house.max_hp * 0.15 + 0.01
	print("[TEST] construction placed incomplete=%s low_hp=%s progress=%.2f hp=%.1f" % [
		started_incomplete, low_hp, house.build_progress, house.hp
	])

	await get_tree().create_timer(0.4).timeout
	print("[TEST] construction villager_state=%s builders=%d" % [villager.state, house.builder_count()])

	var progressed := false
	var completed := false
	for _i in range(40):
		await get_tree().create_timer(0.25).timeout
		if not is_instance_valid(house):
			break
		if house.build_progress > 0.05:
			progressed = true
		if house.is_complete:
			completed = true
			break

	print("[TEST] construction progressed=%s completed=%s final_progress=%.2f" % [
		progressed,
		completed,
		house.build_progress if is_instance_valid(house) else -1.0
	])
	if started_incomplete and low_hp and progressed and completed:
		print("[TEST] PASS building completes after time")
	else:
		print("[TEST] FAIL construction smoke")