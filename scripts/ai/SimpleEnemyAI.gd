extends Node
class_name SimpleEnemyAI
## Economy + wave AI. Team-agnostic (0 or 1). Economic ages; civ uniques; age-based army.

signal wave_launched(count: int)

const WAVE_MIN_UNITS := 2
const WAVE_INTERVAL_SEC := 22.0
const THINK_INTERVAL := 0.45
const START_FOOD := 800
const START_WOOD := 700
const START_GOLD := 220
const START_STONE := 750
const TARGET_VILLAGERS := 10

const HOUSE_SCENE := preload("res://scenes/buildings/House.tscn")
const BARRACKS_SCENE := preload("res://scenes/buildings/Barracks.tscn")
const ARCHERY_SCENE := preload("res://scenes/buildings/ArcheryRange.tscn")
const BLACKSMITH_SCENE := preload("res://scenes/buildings/Blacksmith.tscn")
const STABLE_SCENE := preload("res://scenes/buildings/Stable.tscn")
const CASTLE_SCENE := preload("res://scenes/buildings/Castle.tscn")
const MONASTERY_SCENE := preload("res://scenes/buildings/Monastery.tscn")
const UNIVERSITY_SCENE := preload("res://scenes/buildings/University.tscn")
const TOWER_SCENE := preload("res://scenes/buildings/WatchTower.tscn")
const VILLAGER_SCENE := preload("res://scenes/units/Villager.tscn")
const DROPOFF_SCENE := preload("res://scenes/world/DropOff.tscn")

@export var team: int = 1
@export var retarget_interval: float = 1.0
@export var base_position: Vector2 = Vector2(2100, 700)
@export var civ_id: String = ""

## Per-game ±10% timing jitter (BalanceSim sets this).
var timing_jitter: float = 1.0
var rng := RandomNumberGenerator.new()

var food: int = START_FOOD
var wood: int = START_WOOD
var gold: int = START_GOLD
var stone: int = START_STONE

## Per-team economic age (not GameManager fixed timers).
var age: int = 1
var age_researching: bool = false
var age_research_remaining: float = 0.0

var _think_timer: float = 0.0
var _combat_timer: float = 0.0
var _wave_timer: float = 0.0
var _wave_ready: bool = false
var _launched_wave: bool = false
var _feudal_trained: int = 0 ## spears/archers/cav/uniques enqueued (sim wave gate)
var _age2_at_sec: float = -1.0
var _sim_elapsed: float = 0.0
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


func configure_sim(sim_seed: int, jitter: float) -> void:
	rng.seed = sim_seed + team * 7919
	timing_jitter = clampf(jitter, 0.90, 1.10)
	## Reset stockpile / age — enemy AI may have thought before BalanceSim.begin_game.
	food = START_FOOD
	wood = START_WOOD
	gold = START_GOLD
	stone = START_STONE
	age = 1
	age_researching = false
	age_research_remaining = 0.0
	_wave_timer = 0.0
	_wave_ready = false
	_launched_wave = false
	_feudal_trained = 0
	_age2_at_sec = -1.0
	_sim_elapsed = 0.0


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


func _think_dt() -> float:
	return THINK_INTERVAL * timing_jitter


func _wave_interval() -> float:
	return WAVE_INTERVAL_SEC * timing_jitter


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
	if not has_villager:
		for offset in [Vector2(40, 40), Vector2(60, 60), Vector2(20, 70)]:
			var v: Villager = VILLAGER_SCENE.instantiate() as Villager
			v.team = team
			v.contribute_population = false
			v.position = base_position + offset
			_units_parent.add_child(v)

	print("[AI] bootstrapped team=%d civ=%s at %s jitter=%.2f" % [
		team, GameManager.civ_for_team(team), str(base_position), timing_jitter
	])


func _process(delta: float) -> void:
	_sim_elapsed += delta
	if age_researching:
		age_research_remaining -= delta
		if age_research_remaining <= 0.0:
			_complete_age_research()

	_combat_timer -= delta
	if _combat_timer <= 0.0:
		_combat_timer = retarget_interval * timing_jitter
		_assign_combat_targets()

	_think_timer -= delta
	if _think_timer > 0.0:
		return
	_think_timer = _think_dt()
	if not _bootstrapped:
		return
	_tick_economy()
	_tick_wave(_think_dt())


func _tick_wave(dt: float) -> void:
	_wave_timer += dt
	var army := _own_military()
	## In BalanceSim: feudal buildings + mix, or 80s after age2 (avoid infinite no-wave draws).
	## Normal play keeps the old early-wave behavior for the AI economy smoke.
	var can_wave := true
	if BalanceSim.active:
		var feudal_built := (
			age >= 2
			and _count_own_complete("archery_range") >= 1
			and _count_own_complete("stable") >= 1
		)
		var mix_ready := _feudal_trained >= 4
		var age2_wait := _age2_at_sec >= 0.0 and (_sim_elapsed - _age2_at_sec) >= 80.0
		can_wave = (feudal_built and (mix_ready or age2_wait)) or age >= 3
	if not _wave_ready and can_wave and army.size() >= WAVE_MIN_UNITS:
		_wave_ready = true
		_wave_timer = _wave_interval() * 0.35
	if _wave_ready and _wave_timer >= _wave_interval() and army.size() >= WAVE_MIN_UNITS:
		_launch_wave(army)


func _tick_economy() -> void:
	_assign_gatherers()
	_try_age_up()
	_try_place_next_building()
	_assign_builders()
	_try_train_villagers()
	_try_train_army()
	_try_blacksmith_research()
	_try_university_research()


func _try_age_up() -> void:
	if age_researching or age >= AgeData.MAX_AGE:
		return
	if _count_age_buildings(age) < AgeData.BUILDINGS_REQUIRED_TO_ADVANCE:
		return
	var def := AgeData.research_def_for_next(age)
	if def.is_empty():
		return
	var cost: Dictionary = def.get("cost", {})
	if not _can_afford(cost):
		return
	_spend(cost)
	age_researching = true
	## Full research time so report age times are meaningful (time_scale already high).
	age_research_remaining = float(def.get("time", 130.0)) * timing_jitter
	print("[AI] team=%d age research → %d (%.0fs) food=%d gold=%d" % [
		team, age + 1, age_research_remaining, food, gold
	])


func _complete_age_research() -> void:
	age_researching = false
	age_research_remaining = 0.0
	if age >= AgeData.MAX_AGE:
		return
	age += 1
	if age == 2:
		_age2_at_sec = _sim_elapsed
		## Seed feudal production after the age click drained the stockpile.
		if BalanceSim.active:
			food += 250
			gold += 120
			wood += 100
	## Keep GameManager age at least this high so shared unlock helpers don't block visuals.
	if GameManager.current_age < age:
		GameManager.current_age = age
	BalanceSim.record_age_reached(team, age)
	print("[AI] team=%d reached age %d" % [team, age])


func _count_age_buildings(for_age: int) -> int:
	var c := 0
	var bgroup := "player_buildings" if team == 0 else "enemy_buildings"
	for n in get_tree().get_nodes_in_group(bgroup):
		if n is DropOff:
			continue
		if not (n is Building):
			continue
		var b := n as Building
		if not b.is_complete or b.team != team or b.building_id == "":
			continue
		if AgeData.building_unlock_age(b.building_id) == for_age:
			c += 1
	return c


func _try_place_next_building() -> void:
	## One house is enough for pop in sim; save wood for archery/stable.
	var house_target := 1 if BalanceSim.active else 2
	if _count_own_buildings("house") < house_target and wood >= 25:
		_try_place_building("house", base_position + Vector2(-90, 80 + _count_own_buildings("house") * 40))
		return
	if _count_own_buildings("barracks") < 1 and wood >= 175:
		_try_place_building("barracks", base_position + Vector2(110, 90))
		return
	if age >= 2 and _count_own_buildings("archery_range") < 1 and wood >= 175:
		_try_place_building("archery_range", base_position + Vector2(150, 40))
		return
	if age >= 2 and _count_own_buildings("barracks") >= 1 and _count_own_buildings("stable") < 1 and wood >= 175:
		_try_place_building("stable", base_position + Vector2(120, -70))
		return
	if age >= 2 and _count_own_buildings("blacksmith") < 1 and wood >= 150:
		_try_place_building("blacksmith", base_position + Vector2(-100, -80))
		return
	if age >= 2 and _count_own_buildings("house") < 2 and wood >= 25:
		_try_place_building("house", base_position + Vector2(-90, 120))
		return
	if age >= 2 and _count_own_buildings("watch_tower") < 2 and stone >= 125 and wood >= 25:
		var tower_i := _count_own_buildings("watch_tower")
		var tower_off := Vector2(70, -50) if tower_i == 0 else Vector2(-70, 60)
		_try_place_building("watch_tower", base_position + tower_off)
		return
	if age >= 3 and _count_own_buildings("castle") < 1 and stone >= 650:
		_try_place_building("castle", base_position + Vector2(-40, 140))
		return
	if age >= 3 and _count_own_buildings("monastery") < 1 and wood >= 175:
		_try_place_building("monastery", base_position + Vector2(-130, 40))
		return
	if age >= 4 and _count_own_buildings("university") < 1 and wood >= 200:
		_try_place_building("university", base_position + Vector2(40, -140))
		return


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
		"archery_range":
			if wood < 175:
				return false
			wood -= 175
			building = ARCHERY_SCENE.instantiate() as Building
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
		"monastery":
			if wood < 175:
				return false
			wood -= 175
			building = MONASTERY_SCENE.instantiate() as Building
		"university":
			if wood < 200:
				return false
			wood -= 200
			building = UNIVERSITY_SCENE.instantiate() as Building
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
	elif building is ArcheryRange:
		(building as ArcheryRange).spawn_parent = _units_parent
	elif building is Stable:
		(building as Stable).spawn_parent = _units_parent
	elif building is Castle:
		(building as Castle).spawn_parent = _units_parent
	elif building is Monastery:
		(building as Monastery).spawn_parent = _units_parent
	elif building is WatchTower:
		(building as WatchTower).spawn_parent = _units_parent
	print("[AI] team=%d placing %s at %s" % [team, building_id, str(pos)])
	return true


func _try_blacksmith_research() -> void:
	var smith := _own_blacksmith()
	if smith == null or not smith.is_complete or smith.is_researching():
		return
	for tech_id in TechData.BLACKSMITH_ORDER:
		if GameManager.has_tech(team, tech_id):
			continue
		if smith.can_enqueue(tech_id):
			smith.enqueue_tech(tech_id)
		return


func _try_university_research() -> void:
	if age < 4:
		return
	var uni := _own_university()
	if uni == null or not uni.is_complete or uni.is_researching():
		return
	for tech_id in TechData.UNIVERSITY_ORDER:
		if GameManager.has_tech(team, tech_id):
			continue
		if uni.can_enqueue(tech_id):
			uni.enqueue_tech(tech_id)
		return


func _own_blacksmith() -> Blacksmith:
	for n in get_tree().get_nodes_in_group("blacksmiths"):
		if n is Blacksmith and (n as Blacksmith).team == team:
			return n as Blacksmith
	return null


func _own_university() -> University:
	for n in get_tree().get_nodes_in_group("universities"):
		if n is University and (n as University).team == team:
			return n as University
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


func _count_villagers() -> int:
	var c := 0
	for n in get_tree().get_nodes_in_group("villagers"):
		if n is Villager and (n as Villager).team == team:
			c += 1
	return c


func _food_reserve_for_age() -> int:
	## Only reserve when we can click age *now* (buildings ready + can afford).
	## Never starve the army for a long save-up — that caused 40min timeout draws.
	if age_researching or age >= AgeData.MAX_AGE:
		return 0
	if _count_age_buildings(age) < AgeData.BUILDINGS_REQUIRED_TO_ADVANCE:
		return 0
	var cost: Dictionary = AgeData.research_def_for_next(age).get("cost", {})
	if _can_afford(cost):
		return int(cost.get("food", 0))
	return 0


func _gold_reserve_for_age() -> int:
	if age_researching or age >= AgeData.MAX_AGE:
		return 0
	if _count_age_buildings(age) < AgeData.BUILDINGS_REQUIRED_TO_ADVANCE:
		return 0
	var cost: Dictionary = AgeData.research_def_for_next(age).get("cost", {})
	if _can_afford(cost):
		return int(cost.get("gold", 0))
	return 0


func _try_train_villagers() -> void:
	if _hall == null or not is_instance_valid(_hall):
		return
	if age_researching:
		return
	var cap := TARGET_VILLAGERS if age >= 2 else 6
	if _count_villagers() >= cap:
		return
	## Keep food for feudal click — don't drain the stockpile on villagers first.
	if age == 1 and food < 520:
		return
	if food - _food_reserve_for_age() < 50:
		return
	if _hall.queue.size() >= 2:
		return
	food -= 50
	_hall.ai_enqueue_villager()


func _try_train_army() -> void:
	## Age-based mix: spears, archers, cav, castle uniques, monk. Civ bonuses apply on spawn.
	var food_free := food - _food_reserve_for_age()
	var gold_free := gold - _gold_reserve_for_age()
	var roll := rng.randf()
	# Castle unique (age 3+)
	if age >= 3 and roll < 0.28:
		var castle := _own_castle()
		if castle != null and castle.is_complete and castle.queue.size() < 2:
			var uid := castle.unique_unit_id()
			var def := CivData.unique_unit_def(uid)
			var cost: Dictionary = def.get("cost", {})
			if (
				food_free >= int(cost.get("food", 0))
				and wood >= int(cost.get("wood", 0))
				and gold_free >= int(cost.get("gold", 0))
				and stone >= int(cost.get("stone", 0))
			):
				_spend(cost)
				castle.ai_enqueue_unit(uid)
				_feudal_trained += 1
				return
	# Monk (age 3+)
	if age >= 3 and roll < 0.40:
		var mon := _own_monastery()
		if mon != null and mon.is_complete and mon.queue.size() < 1 and gold_free >= 100:
			gold -= 100
			mon.ai_enqueue_unit("monk")
			_feudal_trained += 1
			return
	# Knight (age 3+)
	if age >= 3 and roll < 0.55:
		var stable_k := _own_stable()
		if stable_k != null and stable_k.is_complete and stable_k.queue.size() < 2:
			if food_free >= 60 and gold_free >= 75:
				food -= 60
				gold -= 75
				stable_k.ai_enqueue_unit("knight")
				_feudal_trained += 1
				return
	# Prefer feudal mix once buildings are up (composition for the report).
	if age >= 2:
		var stable := _own_stable()
		if stable != null and stable.is_complete and stable.queue.size() < 2:
			if food_free >= 80 and (roll < 0.80 or _feudal_trained < 4):
				food -= 80
				stable.ai_enqueue_unit("light_cavalry")
				_feudal_trained += 1
				return
		var range_b := _own_archery()
		if range_b != null and range_b.is_complete and range_b.queue.size() < 3:
			if wood >= 25 and gold_free >= 45 and (roll < 0.60 or _feudal_trained < 4):
				wood -= 25
				gold -= 45
				range_b.ai_enqueue_unit("archer")
				_feudal_trained += 1
				return
	# Spearman (age 2+) / Soldier (age 1+)
	var barracks := _own_barracks()
	if barracks != null and barracks.is_complete and barracks.queue.size() < 3:
		if age >= 2 and food_free >= 35 and wood >= 25 and (roll < 0.55 or _feudal_trained < 4):
			food -= 35
			wood -= 25
			barracks.ai_enqueue_unit("spearman")
			_feudal_trained += 1
		elif food_free >= 60 and gold_free >= 20:
			## In sim, finish feudal mix before spamming dark-age soldiers again.
			if BalanceSim.active and age >= 2 and _feudal_trained < 4:
				return
			food -= 60
			gold -= 20
			barracks.ai_enqueue_unit("soldier")


func _can_afford(cost: Dictionary) -> bool:
	return (
		food >= int(cost.get("food", 0))
		and wood >= int(cost.get("wood", 0))
		and gold >= int(cost.get("gold", 0))
		and stone >= int(cost.get("stone", 0))
	)


func _spend(cost: Dictionary) -> void:
	food -= int(cost.get("food", 0))
	wood -= int(cost.get("wood", 0))
	gold -= int(cost.get("gold", 0))
	stone -= int(cost.get("stone", 0))


func _launch_wave(army: Array) -> void:
	_wave_timer = 0.0
	_launched_wave = true
	## Prefer enemy Town Center — sim win condition.
	var target := _enemy_town_hall()
	if target == null:
		target = _nearest_enemy_threat(base_position)
	## BalanceSim: muster near enemy TC so navigation/time_scale doesn't stall 40min draws.
	var muster := Vector2.ZERO
	var do_muster := BalanceSim.active and target != null
	if do_muster:
		var toward := base_position.direction_to(target.global_position)
		muster = target.global_position - toward * 70.0
	var count := 0
	var i := 0
	for u in army:
		if u is Unit and is_instance_valid(u):
			if u is Monk:
				continue
			if do_muster:
				var offset := Vector2(float((i % 5) - 2) * 18.0, float((i / 5) - 1) * 18.0)
				(u as Unit).global_position = muster + offset
				i += 1
			if target:
				(u as Unit).command_attack(target)
			else:
				var enemy_base := Vector2(2100, 700) if team == 0 else Vector2(900, 700)
				(u as Unit).command_move(enemy_base)
			count += 1
	wave_launched.emit(count)
	print("[AI] team=%d wave count=%d target=%s" % [team, count, target.name if target else "none"])


func _enemy_town_hall() -> Node2D:
	var g := "enemy_town_hall" if team == 0 else "player_town_hall"
	return get_tree().get_first_node_in_group(g) as Node2D


func _own_military() -> Array:
	var out: Array = []
	var ugroup := "player_units" if team == 0 else "enemy_units"
	for n in get_tree().get_nodes_in_group(ugroup):
		if n is Monk:
			continue
		if (
			n is Soldier or n is Spearman or n is Archer or n is LightCavalry or n is Knight
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


func _own_archery() -> ArcheryRange:
	for n in get_tree().get_nodes_in_group("archery_ranges"):
		if n is ArcheryRange and (n as ArcheryRange).team == team:
			return n as ArcheryRange
	return null


func _own_monastery() -> Monastery:
	for n in get_tree().get_nodes_in_group("monasteries"):
		if n is Monastery and (n as Monastery).team == team:
			return n as Monastery
	return null


func _count_own_buildings(building_id: String) -> int:
	var c := 0
	var bgroup := "player_buildings" if team == 0 else "enemy_buildings"
	for n in get_tree().get_nodes_in_group(bgroup):
		if n is Building and (n as Building).building_id == building_id and (n as Building).team == team:
			c += 1
	return c


func _count_own_complete(building_id: String) -> int:
	var c := 0
	var bgroup := "player_buildings" if team == 0 else "enemy_buildings"
	for n in get_tree().get_nodes_in_group(bgroup):
		if n is Building and (n as Building).building_id == building_id and (n as Building).team == team:
			if (n as Building).is_complete:
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
	if not _launched_wave:
		return
	var ugroup := "player_units" if team == 0 else "enemy_units"
	var hall := _enemy_town_hall()
	for node in get_tree().get_nodes_in_group(ugroup):
		if not (node is Unit):
			continue
		var unit := node as Unit
		if unit is Villager or unit is Monk or unit.team != team:
			continue
		## Hard-focus enemy TC once waves are up (sim win condition).
		if hall and is_instance_valid(hall):
			if unit.attack_target != hall:
				unit.command_attack(hall)
			continue
		if is_instance_valid(unit.attack_target):
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
		groups = ["player_town_hall", "walls", "gates", "player_units", "player_buildings"]
	else:
		groups = ["enemy_town_hall", "walls", "gates", "enemy_units", "enemy_buildings"]
	for group_name in groups:
		for node in get_tree().get_nodes_in_group(group_name):
			if not (node is Node2D):
				continue
			if "team" in node and int(node.get("team")) != enemy_team:
				if group_name in ["walls", "gates"] and int(node.get("team")) == team:
					continue
				elif group_name not in ["walls", "gates"]:
					continue
			var n := node as Node2D
			var d := from_pos.distance_to(n.global_position)
			if group_name.ends_with("town_hall"):
				d *= 0.35
			elif n is WallSegment or n is Gate:
				d *= 0.75
			if d < best_dist:
				best_dist = d
				best = n
	return best


func has_placed_building() -> bool:
	return _count_own_buildings("house") + _count_own_buildings("barracks") > 0


func has_launched_wave() -> bool:
	return _launched_wave
