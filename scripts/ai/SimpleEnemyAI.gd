extends Node
class_name SimpleEnemyAI
## Economy + wave AI. Team-agnostic (0 or 1) for Fáze 5 AI vs AI sim.

signal wave_launched(count: int)

const WAVE_MIN_UNITS := 3
const WAVE_INTERVAL_SEC := 40.0
const THINK_INTERVAL := 0.45
const START_FOOD := 300
const START_WOOD := 400
const START_GOLD := 80
const START_STONE := 700

const HOUSE_SCENE := preload("res://scenes/buildings/House.tscn")
const BARRACKS_SCENE := preload("res://scenes/buildings/Barracks.tscn")
const BLACKSMITH_SCENE := preload("res://scenes/buildings/Blacksmith.tscn")
const STABLE_SCENE := preload("res://scenes/buildings/Stable.tscn")
const CASTLE_SCENE := preload("res://scenes/buildings/Castle.tscn")
const TOWER_SCENE := preload("res://scenes/buildings/WatchTower.tscn")
const VILLAGER_SCENE := preload("res://scenes/units/Villager.tscn")
const DROPOFF_SCENE := preload("res://scenes/world/DropOff.tscn")

@export var team: int = 1
@export var retarget_interval: float = 1.0
@export var base_position: Vector2 = Vector2(2100, 700)
@export var civ_id: String = ""

var food: int = START_FOOD
var wood: int = START_WOOD
var gold: int = START_GOLD
var stone: int = START_STONE

var _think_timer: float = 0.0
var _combat_timer: float = 0.0
var _wave_timer: float = 0.0
var _wave_ready: bool = false
var _launched_wave: bool = false
var _hall: DropOff
var _units_parent: Node2D
var _bootstrapped: bool = false


func _ready() -> void:
	add_to_group("ai_controllers")
	if team == 1:
		add_to_group("enemy_ai")
	else:
		add_to_group("player_ai")
	if civ_id != "":
		if team == 0:
			GameManager.player_civ = civ_id
		else:
			GameManager.enemy_civ = civ_id
	elif team == 1 and not BalanceSim.active:
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
			stone += amount


func _bootstrap_base() -> void:
	if _bootstrapped:
		return
	var map := get_parent()
	_units_parent = map.get_node_or_null("Units") as Node2D
	if _units_parent == null:
		return
	_bootstrapped = true

	var hall_group := "player_town_hall" if team == 0 else "enemy_town_hall"
	_hall = get_tree().get_first_node_in_group(hall_group) as DropOff
	if _hall == null:
		_hall = DROPOFF_SCENE.instantiate() as DropOff
		_hall.team = team
		_hall.position = base_position
		_hall.spawn_parent = _units_parent
		_units_parent.add_child(_hall)
		var victory := map.get_node_or_null("VictoryController") as VictoryController
		if victory:
			victory.watch_new_hall(_hall)
	else:
		base_position = _hall.global_position

	var unit_group := "player_units" if team == 0 else "enemy_units"
	var has_villager := false
	for n in get_tree().get_nodes_in_group(unit_group):
		if n is Villager and (n as Villager).team == team:
			has_villager = true
			break
	# In normal play Map already spawns villagers; only fill if missing (sim / edge).
	if not has_villager:
		for offset in [Vector2(40, 40), Vector2(60, 60), Vector2(20, 70)]:
			var v: Villager = VILLAGER_SCENE.instantiate() as Villager
			v.team = team
			v.contribute_population = false
			v.position = base_position + offset
			_units_parent.add_child(v)

	print("[AI] bootstrapped team=%d civ=%s at %s" % [
		team, GameManager.civ_for_team(team), str(base_position)
	])


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
	var soldiers := _own_soldiers()
	if not _wave_ready and soldiers.size() >= WAVE_MIN_UNITS:
		_wave_ready = true
		_wave_timer = WAVE_INTERVAL_SEC
	if _wave_ready and _wave_timer >= WAVE_INTERVAL_SEC and soldiers.size() >= WAVE_MIN_UNITS:
		_launch_wave(soldiers)


func _tick_economy() -> void:
	_assign_gatherers()
	if _count_own_buildings("house") < 1 and wood >= 25:
		_try_place_building("house", base_position + Vector2(-90, 80))
	elif _count_own_buildings("barracks") < 1 and wood >= 175:
		_try_place_building("barracks", base_position + Vector2(110, 90))
	elif _count_own_buildings("blacksmith") < 1 and wood >= 150:
		_try_place_building("blacksmith", base_position + Vector2(-100, -80))
	elif (
		GameManager.current_age >= 2
		and _count_own_buildings("barracks") >= 1
		and _count_own_buildings("stable") < 1
		and wood >= 175
	):
		_try_place_building("stable", base_position + Vector2(120, -70))
	elif (
		GameManager.current_age >= 2
		and _count_own_buildings("watch_tower") < 2
		and stone >= 125
		and wood >= 25
	):
		var tower_i := _count_own_buildings("watch_tower")
		var tower_off := Vector2(70, -50) if tower_i == 0 else Vector2(-70, 60)
		_try_place_building("watch_tower", base_position + tower_off)
	elif (
		GameManager.current_age >= 3
		and _count_own_buildings("castle") < 1
		and stone >= 650
	):
		_try_place_building("castle", base_position + Vector2(-40, 140))
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
		"castle":
			if stone < 650:
				return false
			stone -= 650
			building = CASTLE_SCENE.instantiate() as Building
		"watch_tower":
			if stone < 125 or wood < 25:
				return false
			stone -= 125
			wood -= 25
			building = TOWER_SCENE.instantiate() as Building
		_:
			return false
	building.team = team
	building.position = pos
	building.is_complete = false
	_units_parent.add_child(building)
	var build_t := 3.0 if DisplayServer.get_name() == "headless" else float(BuildingPlacer.BUILD_TIMES.get(building_id, 25.0))
	building.start_construction(build_t)
	if building is Barracks:
		(building as Barracks).spawn_parent = _units_parent
	elif building is Stable:
		(building as Stable).spawn_parent = _units_parent
	elif building is Castle:
		(building as Castle).spawn_parent = _units_parent
	elif building is WatchTower:
		(building as WatchTower).spawn_parent = _units_parent
	print("[AI] team=%d placing %s at %s (wood %d stone %d)" % [team, building_id, str(pos), wood, stone])
	return true


func _try_blacksmith_research() -> void:
	var smith := _own_blacksmith()
	if smith == null or not smith.is_complete or smith.is_researching():
		return
	for tech_id in [TechData.FORGING, TechData.CHAIN_MAIL]:
		if GameManager.has_tech(team, tech_id):
			continue
		if smith.can_enqueue(tech_id):
			smith.enqueue_tech(tech_id)
		return


func _own_blacksmith() -> Blacksmith:
	for n in get_tree().get_nodes_in_group("blacksmiths"):
		if n is Blacksmith and (n as Blacksmith).team == team:
			return n as Blacksmith
	return null


func _assign_gatherers() -> void:
	for n in get_tree().get_nodes_in_group("villagers"):
		if not (n is Villager):
			continue
		var v := n as Villager
		if v.team != team:
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
	var bgroup := "player_buildings" if team == 0 else "enemy_buildings"
	for n in get_tree().get_nodes_in_group(bgroup):
		if not (n is Building):
			continue
		var b := n as Building
		if b.is_complete or b.builder_count() >= 2:
			continue
		for vn in get_tree().get_nodes_in_group("villagers"):
			if not (vn is Villager):
				continue
			var v := vn as Villager
			if v.team != team:
				continue
			if v.state == Villager.State.BUILDING or v.state == Villager.State.MOVE_TO_BUILD:
				continue
			v.assign_build(b)
			break


func _try_train() -> void:
	var barracks := _own_barracks()
	if barracks != null and barracks.is_complete:
		if food >= 60 and gold >= 20 and barracks.queue.size() < 3:
			food -= 60
			gold -= 20
			barracks.ai_enqueue_unit("soldier")
	if GameManager.current_age >= 2:
		var stable := _own_stable()
		if stable != null and stable.is_complete and food >= 80 and stable.queue.size() < 2:
			food -= 80
			stable.ai_enqueue_unit("light_cavalry")
	if GameManager.current_age >= 3:
		var castle := _own_castle()
		if castle != null and castle.is_complete and castle.queue.size() < 2:
			var uid := castle.unique_unit_id()
			var def := CivData.unique_unit_def(uid)
			var cost: Dictionary = def.get("cost", {})
			var need_f := int(cost.get("food", 0))
			var need_w := int(cost.get("wood", 0))
			var need_g := int(cost.get("gold", 0))
			if food >= need_f and wood >= need_w and gold >= need_g:
				food -= need_f
				wood -= need_w
				gold -= need_g
				castle.ai_enqueue_unit(uid)


func _launch_wave(soldiers: Array) -> void:
	_wave_timer = 0.0
	_launched_wave = true
	var target := _nearest_enemy_threat(base_position)
	var count := 0
	for u in soldiers:
		if u is Unit and is_instance_valid(u):
			if target:
				(u as Unit).command_attack(target)
			else:
				var enemy_base := Vector2(2100, 700) if team == 0 else Vector2(900, 700)
				(u as Unit).command_move(enemy_base)
			count += 1
	wave_launched.emit(count)
	print("[AI] team=%d wave count=%d target=%s" % [team, count, target.name if target else "none"])


func _own_soldiers() -> Array:
	var out: Array = []
	var ugroup := "player_units" if team == 0 else "enemy_units"
	for n in get_tree().get_nodes_in_group(ugroup):
		if (
			n is Soldier or n is Spearman or n is LightCavalry or n is Knight
			or n is BojovnikBradatice or n is Druzinik or n is ValecnyVuz or n is Lancknecht
		):
			if n is Unit and (n as Unit).team == team:
				out.append(n)
	return out


func _own_stable() -> Stable:
	for n in get_tree().get_nodes_in_group("stables"):
		if n is Stable and (n as Stable).team == team:
			return n as Stable
	return null


func _own_castle() -> Castle:
	for n in get_tree().get_nodes_in_group("castles"):
		if n is Castle and (n as Castle).team == team:
			return n as Castle
	return null


func _own_barracks() -> Barracks:
	for n in get_tree().get_nodes_in_group("barracks"):
		if n is Barracks and (n as Barracks).team == team:
			return n as Barracks
	return null


func _count_own_buildings(building_id: String) -> int:
	var c := 0
	var bgroup := "player_buildings" if team == 0 else "enemy_buildings"
	for n in get_tree().get_nodes_in_group(bgroup):
		if n is Building and (n as Building).building_id == building_id and (n as Building).team == team:
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
		if r.global_position.distance_to(base_position) > 500.0:
			continue
		var d := from_pos.distance_to(r.global_position)
		if d < best_d:
			best_d = d
			best = r
	return best


func _assign_combat_targets() -> void:
	var ugroup := "player_units" if team == 0 else "enemy_units"
	for node in get_tree().get_nodes_in_group(ugroup):
		if not (node is Unit):
			continue
		var unit := node as Unit
		if unit is Villager or unit.team != team:
			continue
		if is_instance_valid(unit.attack_target):
			continue
		if not _launched_wave:
			continue
		var target := _nearest_enemy_threat(unit.global_position)
		if target:
			unit.command_attack(target)


func _nearest_enemy_threat(from_pos: Vector2) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	var enemy_team := 1 if team == 0 else 0
	var groups: Array
	if enemy_team == 0:
		groups = ["walls", "gates", "player_units", "player_buildings", "player_town_hall"]
	else:
		groups = ["walls", "gates", "enemy_units", "enemy_buildings", "enemy_town_hall"]
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if not (node is Node2D):
				continue
			if "team" in node and int(node.get("team")) != enemy_team:
				# walls/gates may be either team — skip own fortifications
				if group_name in ["walls", "gates"] and int(node.get("team")) == team:
					continue
				elif group_name not in ["walls", "gates"]:
					continue
			var n := node as Node2D
			var d := from_pos.distance_to(n.global_position)
			if n is WallSegment or n is Gate:
				d *= 0.75
			if d < best_dist:
				best_dist = d
				best = n
	return best


func has_placed_building() -> bool:
	return _count_own_buildings("house") + _count_own_buildings("barracks") > 0


func has_launched_wave() -> bool:
	return _launched_wave
