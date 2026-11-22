extends Node
class_name SimpleEnemyAI
## Fáze 2 — AI economy (gather/build/train) + wave attacks. Civ = Husité.

signal wave_launched(count: int)

## Schváleno (CS Designer) 2026-11-22: wave size / intervals.
const WAVE_MIN_UNITS := 3
const WAVE_INTERVAL_SEC := 40.0
const THINK_INTERVAL := 0.45
const START_FOOD := 300 # enough for Kovářství + Kroužková zbroj after buildings
const START_WOOD := 400
const START_GOLD := 80

const HOUSE_SCENE := preload("res://scenes/buildings/House.tscn")
const BARRACKS_SCENE := preload("res://scenes/buildings/Barracks.tscn")
const BLACKSMITH_SCENE := preload("res://scenes/buildings/Blacksmith.tscn")
const STABLE_SCENE := preload("res://scenes/buildings/Stable.tscn")
const VILLAGER_SCENE := preload("res://scenes/units/Villager.tscn")
const DROPOFF_SCENE := preload("res://scenes/world/DropOff.tscn")
const RESOURCE_SCENE := preload("res://scenes/world/ResourceNode.tscn")

@export var retarget_interval: float = 1.0
@export var base_position: Vector2 = Vector2(2100, 700)

var food: int = START_FOOD
var wood: int = START_WOOD
var gold: int = START_GOLD

var _think_timer: float = 0.0
var _combat_timer: float = 0.0
var _wave_timer: float = 0.0
var _wave_ready: bool = false
var _launched_wave: bool = false
var _hall: DropOff
var _units_parent: Node2D
var _bootstrapped: bool = false


func _ready() -> void:
	add_to_group("enemy_ai")
	GameManager.enemy_civ = CivData.HUSITE
	call_deferred("_bootstrap_base")


func add_resource(type: String, amount: int) -> void:
	match type:
		"food":
			food += amount
		"wood":
			wood += amount
		"gold":
			gold += amount
		"stone":
			pass


func _bootstrap_base() -> void:
	if _bootstrapped:
		return
	var map := get_parent()
	_units_parent = map.get_node_or_null("Units") as Node2D
	if _units_parent == null:
		return
	_bootstrapped = true

	# MapGenerator owns resources + enemy TC; reuse hall if already present.
	_hall = get_tree().get_first_node_in_group("enemy_town_hall") as DropOff
	if _hall == null:
		_hall = DROPOFF_SCENE.instantiate() as DropOff
		_hall.team = 1
		_hall.position = base_position
		_hall.spawn_parent = _units_parent
		_units_parent.add_child(_hall)
		var victory := map.get_node_or_null("VictoryController") as VictoryController
		if victory:
			victory.watch_new_hall(_hall)
	else:
		base_position = _hall.global_position

	var has_enemy_villager := false
	for n in get_tree().get_nodes_in_group("enemy_units"):
		if n is Villager:
			has_enemy_villager = true
			break
	if not has_enemy_villager:
		for offset in [Vector2(40, 40), Vector2(60, 60), Vector2(20, 70)]:
			var v: Villager = VILLAGER_SCENE.instantiate() as Villager
			v.team = 1
			v.contribute_population = false
			v.position = base_position + offset
			_units_parent.add_child(v)

	print("[AI] bootstrapped Husité base at %s" % str(base_position))


func _process(delta: float) -> void:
	_combat_timer -= delta
	if _combat_timer <= 0.0:
		_combat_timer = retarget_interval
		_assign_combat_targets()

	_think_timer -= delta
	if _think_timer > 0.0:
		return
	_think_timer = THINK_INTERVAL
	if not _bootstrapped:
		return
	_tick_economy()
	_tick_wave(THINK_INTERVAL)


func _tick_wave(dt: float) -> void:
	_wave_timer += dt
	var soldiers := _enemy_soldiers()
	if not _wave_ready and soldiers.size() >= WAVE_MIN_UNITS:
		_wave_ready = true
		_wave_timer = WAVE_INTERVAL_SEC # allow immediate first wave
	if _wave_ready and _wave_timer >= WAVE_INTERVAL_SEC and soldiers.size() >= WAVE_MIN_UNITS:
		_launch_wave(soldiers)


func _tick_economy() -> void:
	_assign_gatherers()
	if _count_enemy_buildings("house") < 1 and wood >= 25:
		_try_place_building("house", base_position + Vector2(-90, 80))
	elif _count_enemy_buildings("barracks") < 1 and wood >= 175:
		_try_place_building("barracks", base_position + Vector2(110, 90))
	elif _count_enemy_buildings("blacksmith") < 1 and wood >= 150:
		_try_place_building("blacksmith", base_position + Vector2(-100, -80))
	elif (
		GameManager.current_age >= 2
		and _count_enemy_buildings("barracks") >= 1
		and _count_enemy_buildings("stable") < 1
		and wood >= 175
	):
		_try_place_building("stable", base_position + Vector2(120, -70))
	_assign_builders()
	_try_train()
	_try_blacksmith_research()


func _try_place_building(building_id: String, pos: Vector2) -> bool:
	var building: Building = null
	match building_id:
		"house":
			if wood < 25:
				return false
			wood -= 25
			building = HOUSE_SCENE.instantiate() as Building
		"barracks":
			if wood < 175:
				return false
			wood -= 175
			building = BARRACKS_SCENE.instantiate() as Building
		"blacksmith":
			if wood < 150:
				return false
			wood -= 150
			building = BLACKSMITH_SCENE.instantiate() as Building
		"stable":
			if wood < 175:
				return false
			wood -= 175
			building = STABLE_SCENE.instantiate() as Building
		_:
			return false
	building.team = 1
	building.position = pos
	building.is_complete = false
	_units_parent.add_child(building)
	# Headless / prototype: finish quickly so waves are testable.
	var build_t := 3.0 if DisplayServer.get_name() == "headless" else float(BuildingPlacer.BUILD_TIMES.get(building_id, 25.0))
	building.start_construction(build_t)
	if building is Barracks:
		(building as Barracks).spawn_parent = _units_parent
	elif building is Stable:
		(building as Stable).spawn_parent = _units_parent
	print("[AI] placing %s at %s (wood left %d)" % [building_id, str(pos), wood])
	return true


func _try_blacksmith_research() -> void:
	var smith := _enemy_blacksmith()
	if smith == null or not smith.is_complete or smith.is_researching():
		return
	# After Kovárna: Kovářství then Kroužková zbroj.
	for tech_id in [TechData.FORGING, TechData.CHAIN_MAIL]:
		if GameManager.has_tech(1, tech_id):
			continue
		if smith.can_enqueue(tech_id):
			smith.enqueue_tech(tech_id)
		return


func _enemy_blacksmith() -> Blacksmith:
	for n in get_tree().get_nodes_in_group("blacksmiths"):
		if n is Blacksmith and (n as Blacksmith).team == 1:
			return n as Blacksmith
	return null


func _assign_gatherers() -> void:
	for n in get_tree().get_nodes_in_group("villagers"):
		if not (n is Villager):
			continue
		var v := n as Villager
		if v.team != 1:
			continue
		if v.state == Villager.State.BUILDING or v.state == Villager.State.MOVE_TO_BUILD:
			continue
		if v.state == Villager.State.HARVESTING or v.state == Villager.State.MOVE_TO_RESOURCE or v.state == Villager.State.MOVE_TO_DROPOFF:
			continue
		if v.carried_amount > 0:
			continue
		var res := _nearest_resource(v.global_position)
		if res:
			v.assign_gather(res, _hall)


func _assign_builders() -> void:
	for n in get_tree().get_nodes_in_group("enemy_buildings"):
		if not (n is Building):
			continue
		var b := n as Building
		if b.is_complete or b.builder_count() >= 2:
			continue
		for vn in get_tree().get_nodes_in_group("villagers"):
			if not (vn is Villager):
				continue
			var v := vn as Villager
			if v.team != 1:
				continue
			if v.state == Villager.State.BUILDING or v.state == Villager.State.MOVE_TO_BUILD:
				continue
			v.assign_build(b)
			break


func _try_train() -> void:
	var barracks := _enemy_barracks()
	if barracks != null and barracks.is_complete:
		# Prefer soldiers; costs match DESIGN (AI pool, not GameManager).
		if food >= 60 and gold >= 20 and barracks.queue.size() < 3:
			food -= 60
			gold -= 20
			barracks.ai_enqueue_unit("soldier")
	# From age 2: mix light cavalry from Stable.
	if GameManager.current_age >= 2:
		var stable := _enemy_stable()
		if stable != null and stable.is_complete and food >= 80 and stable.queue.size() < 2:
			food -= 80
			stable.ai_enqueue_unit("light_cavalry")


func _launch_wave(soldiers: Array) -> void:
	_wave_timer = 0.0
	_launched_wave = true
	var target := _nearest_player_threat(base_position)
	var count := 0
	for u in soldiers:
		if u is Unit and is_instance_valid(u):
			if target:
				(u as Unit).command_attack(target)
			else:
				(u as Unit).command_move(Vector2(900, 700))
			count += 1
	wave_launched.emit(count)
	print("[AI] wave launched count=%d target=%s" % [count, target.name if target else "none"])


func _enemy_soldiers() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group("enemy_units"):
		if n is Soldier or n is Spearman or n is LightCavalry or n is Knight:
			out.append(n)
	return out


func _enemy_stable() -> Stable:
	for n in get_tree().get_nodes_in_group("stables"):
		if n is Stable and (n as Stable).team == 1:
			return n as Stable
	return null


func _enemy_barracks() -> Barracks:
	for n in get_tree().get_nodes_in_group("barracks"):
		if n is Barracks and (n as Barracks).team == 1:
			return n as Barracks
	return null


func _count_enemy_buildings(building_id: String) -> int:
	var c := 0
	for n in get_tree().get_nodes_in_group("enemy_buildings"):
		if n is Building and (n as Building).building_id == building_id:
			c += 1
	return c


func _nearest_resource(from_pos: Vector2) -> ResourceNode:
	var best: ResourceNode = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("resources"):
		if not (n is ResourceNode):
			continue
		var r := n as ResourceNode
		if r.is_depleted():
			continue
		# Prefer resources near AI base.
		if r.global_position.distance_to(base_position) > 500.0:
			continue
		var d := from_pos.distance_to(r.global_position)
		if d < best_d:
			best_d = d
			best = r
	return best


func _assign_combat_targets() -> void:
	# Idle soldiers that are not in an active wave still hold; wave sets attack.
	for node in get_tree().get_nodes_in_group("enemy_units"):
		if not (node is Unit):
			continue
		var unit := node as Unit
		if unit is Villager:
			continue
		if is_instance_valid(unit.attack_target):
			continue
		if not _launched_wave:
			continue
		var target := _nearest_player_threat(unit.global_position)
		if target:
			unit.command_attack(target)


func _nearest_player_threat(from_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for group_name in ["player_units", "player_buildings", "player_town_hall"]:
		for node in get_tree().get_nodes_in_group(group_name):
			if not (node is Node2D):
				continue
			var n := node as Node2D
			var d := from_pos.distance_to(n.global_position)
			if d < best_dist:
				best_dist = d
				best = n
	return best


func has_placed_building() -> bool:
	return _count_enemy_buildings("house") + _count_enemy_buildings("barracks") > 0


func has_launched_wave() -> bool:
	return _launched_wave
