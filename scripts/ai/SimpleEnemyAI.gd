extends Node
class_name SimpleEnemyAI
## Economy + wave AI. Team-agnostic (0 or 1).
## Normal play: AoE II Standard feel (~20 vills, mill/farms, 4-min waves, retreat).
## BalanceSim: strategy-gated ages/waves (rush / boom / fast_castle).

signal wave_launched(count: int)

const WAVE_MIN_UNITS := 2
const WAVE_INTERVAL_SEC := 22.0 ## BalanceSim cadence
const WAVE_INTERVAL_STANDARD := 240.0 ## ~4 min between waves
const WAVE_FIRST_MIN_SEC := 360.0 ## first Standard wave not before minute 6
const WAVE_FIRST_MIN_STANDARD := 6 ## Standard first wave ≥ this many units
const EARLY_ARMY_SCREEN := 2 ## tiny screen while booming villagers
const WAVE_RETREAT_LOSS := 0.60
const THINK_INTERVAL := 0.45
const START_FOOD := 800
const START_WOOD := 700
const START_GOLD := 220
const START_STONE := 750
const TARGET_VILLAGERS := 10
const TARGET_VILLAGERS_BOOM := 14
const TARGET_VILLAGERS_STANDARD := 20
const TC_POP_BONUS := 5
const HOUSE_POP_BONUS := 5
const POP_HEADROOM := 2
const DEFAULT_SEED := 9001
const STANDARD_TOWER_TARGET := 2
const STANDARD_WALL_TARGET := 60 ## towers 250 + walls 300 → stone unspent = 200
const WALLS_PER_THINK := 2 ## AoE feel: never spam foundations
const MAX_UNFINISHED_FORTIFICATIONS := 2 ## wall + tower scaffolds in flight
const FOUNDATION_STALE_SEC := 60.0 ## cancel/refund if untouched this long
const ECO_READY_VILLS := 12 ## boom to 12, then fill wave ≥6
const AGE_UP_MIN_VILLS := 8 ## don't burn 500 food before eco is online

## Counter pick from TechData.unit_role roles (AoE rock-paper-scissors on main).
## many archers → cavalry / swordsmen; many cavalry → spearmen.
const COUNTER_TABLE := {
	"archer": ["light_cavalry", "soldier"],
	"cavalry": ["spearman"],
	"infantry": ["archer", "soldier"],
}

const HOUSE_SCENE := preload("res://scenes/buildings/House.tscn")
const BARRACKS_SCENE := preload("res://scenes/buildings/Barracks.tscn")
const ARCHERY_SCENE := preload("res://scenes/buildings/ArcheryRange.tscn")
const BLACKSMITH_SCENE := preload("res://scenes/buildings/Blacksmith.tscn")
const STABLE_SCENE := preload("res://scenes/buildings/Stable.tscn")
const CASTLE_SCENE := preload("res://scenes/buildings/Castle.tscn")
const MONASTERY_SCENE := preload("res://scenes/buildings/Monastery.tscn")
const UNIVERSITY_SCENE := preload("res://scenes/buildings/University.tscn")
const SIEGE_WORKSHOP_SCENE := preload("res://scenes/buildings/SiegeWorkshop.tscn")
const TOWER_SCENE := preload("res://scenes/buildings/WatchTower.tscn")
const WALL_SCENE := preload("res://scenes/buildings/WallSegment.tscn")
const MILL_SCENE := preload("res://scenes/buildings/Mill.tscn")
const FARM_SCENE := preload("res://scenes/buildings/Farm.tscn")
const VILLAGER_SCENE := preload("res://scenes/units/Villager.tscn")
const DROPOFF_SCENE := preload("res://scenes/world/DropOff.tscn")

@export var team: int = 1
@export var retarget_interval: float = 1.0
@export var base_position: Vector2 = Vector2(2100, 700)
@export var civ_id: String = ""

## Per-game ±10% timing jitter (BalanceSim sets this).
var timing_jitter: float = 1.0
var rng := RandomNumberGenerator.new()
## BalanceSim strategy: rush | boom | fast_castle (normal play ignores).
var strategy: String = BalanceSim.STRAT_RUSH

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
var _waves_launched: int = 0
var _feudal_trained: int = 0
var _unique_trained: int = 0
var _siege_trained: int = 0
var _age2_at_sec: float = -1.0
var _age3_at_sec: float = -1.0
var _sim_elapsed: float = 0.0
var _hall: DropOff
var _units_parent: Node2D
var _bootstrapped: bool = false
var _wave_roster: Array = []
var _wave_start_size: int = 0
var _first_wave_count: int = 0
var _retreating: bool = false
var _last_counter_pick: String = ""
## instance_id -> sim time when wall/tower foundation was placed (stale cancel).
var _foundation_born_at: Dictionary = {}
## Peak unfinished wall+tower foundations (smoke: must stay ≤ MAX).
var _smoke_max_unfinished_fortifications: int = 0
## Frozen chebyshev radius for the perimeter wall ring (set on first plan).
var _cached_wall_ring_radius: int = 0


func _ready() -> void:
	add_to_group("ai_controllers")
	if team == 1:
		add_to_group("enemy_ai")
	else:
		add_to_group("player_ai")
	## Deterministic default seed (BalanceSim overwrites via configure_sim).
	rng.seed = DEFAULT_SEED + team * 7919
	if civ_id != "":
		if team == 0:
			GameManager.player_civ = civ_id
		else:
			GameManager.enemy_civ = civ_id
	elif team == 1 and not BalanceSim.active:
		GameManager.enemy_civ = CivData.HUSITE
	call_deferred("_bootstrap_base")


func configure_sim(sim_seed: int, jitter: float, strat: String = BalanceSim.STRAT_RUSH) -> void:
	rng.seed = sim_seed + team * 7919
	timing_jitter = clampf(jitter, 0.90, 1.10)
	strategy = strat if strat in BalanceSim.STRATEGIES else BalanceSim.STRAT_RUSH
	## Reset stockpile / age — enemy AI may have thought before BalanceSim.begin_game.
	food = START_FOOD
	wood = START_WOOD
	gold = START_GOLD
	stone = START_STONE
	if strategy == BalanceSim.STRAT_BOOM:
		food += 200
		wood += 150
		gold += 100
		stone += 100
	elif strategy == BalanceSim.STRAT_FC:
		food += 200
		gold += 120
		wood += 100
		stone += 650 ## castle-ready after age 3
	age = 1
	age_researching = false
	age_research_remaining = 0.0
	_wave_timer = 0.0
	_wave_ready = false
	_launched_wave = false
	_waves_launched = 0
	_feudal_trained = 0
	_unique_trained = 0
	_siege_trained = 0
	_age2_at_sec = -1.0
	_age3_at_sec = -1.0
	_sim_elapsed = 0.0
	_wave_roster.clear()
	_wave_start_size = 0
	_first_wave_count = 0
	_retreating = false
	_last_counter_pick = ""
	_foundation_born_at.clear()
	_smoke_max_unfinished_fortifications = 0
	_cached_wall_ring_radius = 0
	print("[AI] team=%d strategy=%s" % [team, strategy])


## Fixed seed for Standard / headless smoke (no BalanceSim resource top-ups).
func configure_standard(sim_seed: int, jitter: float = 1.0) -> void:
	rng.seed = sim_seed + team * 7919
	timing_jitter = clampf(jitter, 0.90, 1.10)
	strategy = BalanceSim.STRAT_RUSH
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
	_waves_launched = 0
	_feudal_trained = 0
	_unique_trained = 0
	_siege_trained = 0
	_age2_at_sec = -1.0
	_age3_at_sec = -1.0
	_sim_elapsed = 0.0
	_wave_roster.clear()
	_wave_start_size = 0
	_first_wave_count = 0
	_retreating = false
	_last_counter_pick = ""
	_foundation_born_at.clear()
	_smoke_max_unfinished_fortifications = 0
	_cached_wall_ring_radius = 0
	print("[AI] team=%d standard seed=%d" % [team, sim_seed])


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
	if BalanceSim.active:
		return WAVE_INTERVAL_SEC * timing_jitter
	return WAVE_INTERVAL_STANDARD * timing_jitter


func _wave_min_units() -> int:
	if BalanceSim.active:
		return WAVE_MIN_UNITS
	## Standard: first wave ≥6; later waves grow with age.
	match age:
		1, 2:
			return WAVE_FIRST_MIN_STANDARD
		3:
			return WAVE_FIRST_MIN_STANDARD + 2
		_:
			return WAVE_FIRST_MIN_STANDARD + 4


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
		_check_wave_retreat()
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
	var min_u := _wave_min_units()
	## Normal play: early waves. BalanceSim: strategy gates (boom/FC hold for castle age).
	var can_wave := true
	if BalanceSim.active:
		can_wave = _sim_can_wave()
	elif _sim_elapsed < WAVE_FIRST_MIN_SEC:
		can_wave = false
	if not _wave_ready and can_wave and army.size() >= min_u:
		_wave_ready = true
		## Standard: launch immediately once army ≥ min after minute 6; BalanceSim keeps partial wait.
		if BalanceSim.active:
			_wave_timer = _wave_interval() * 0.35
		else:
			_wave_timer = _wave_interval() ## saturates the wait check below
	if _wave_ready and _wave_timer >= _wave_interval() and army.size() >= min_u and not _retreating:
		_launch_wave(army)


func _sim_can_wave() -> bool:
	match strategy:
		BalanceSim.STRAT_RUSH:
			## Feudal army, but hold the push so boom/FC can age (length + age4 %).
			var feudal_built := (
				age >= 2
				and _count_own_complete("archery_range") >= 1
				and _count_own_complete("stable") >= 1
			)
			var mix_ready := _feudal_trained >= 4
			return feudal_built and mix_ready and _sim_elapsed >= 600.0
		BalanceSim.STRAT_FC:
			## Castle age + uniques, then commit around ~12–14 min.
			return (
				age >= 3
				and _count_own_complete("castle") >= 1
				and _unique_trained >= 2
				and _sim_elapsed >= 780.0
			)
		BalanceSim.STRAT_BOOM:
			## Imperial + uniques; commit after ~15 min.
			return (
				age >= 4
				and _count_own_complete("castle") >= 1
				and _unique_trained >= 2
				and _sim_elapsed >= 960.0
			)
		_:
			return age >= 2


func _tick_economy() -> void:
	_cancel_stale_foundations()
	_note_unfinished_fortification_peak()
	_assign_gatherers()
	_try_reseed_farms()
	_try_age_up()
	_try_place_next_building()
	_try_place_stone_defenses()
	_assign_builders()
	_try_train_villagers()
	_try_train_army()
	_try_blacksmith_research()
	_try_university_research()
	_note_unfinished_fortification_peak()


## Stone needed for planned spends (towers / walls / castle / uni techs). 0 → don't gather.
func _planned_stone_need() -> int:
	var need := 0
	var tower_target := 0
	## Standard: don't pull stone gatherers until the first wave is out.
	var std_defenses := not BalanceSim.active and age >= 2 and _waves_launched >= 1
	if std_defenses:
		tower_target = STANDARD_TOWER_TARGET
	elif BalanceSim.active and strategy == BalanceSim.STRAT_RUSH and age >= 2:
		tower_target = 2
	var towers_have := _count_own_buildings("watch_tower")
	if towers_have < tower_target:
		need += (tower_target - towers_have) * 125
	if std_defenses:
		var walls_have := _count_own_buildings("stone_wall")
		if walls_have < STANDARD_WALL_TARGET:
			need += (STANDARD_WALL_TARGET - walls_have) * 5
	if age >= 3 and _count_own_buildings("castle") < 1:
		need += 650
	if age >= 4 and not GameManager.has_tech(team, TechData.MASONRY):
		need += int(TechData.tech_def(TechData.MASONRY).get("cost", {}).get("stone", 0))
	elif age >= 4 and not GameManager.has_tech(team, TechData.TOWER_ENGINE):
		need += int(TechData.tech_def(TechData.TOWER_ENGINE).get("cost", {}).get("stone", 0))
	return need


func _target_age() -> int:
	if not BalanceSim.active:
		return AgeData.MAX_AGE
	match strategy:
		BalanceSim.STRAT_RUSH:
			return 2
		BalanceSim.STRAT_FC:
			return 3
		BalanceSim.STRAT_BOOM:
			return 4
		_:
			return 2


func _try_age_up() -> void:
	if age_researching or age >= AgeData.MAX_AGE:
		return
	if age >= _target_age():
		return
	## Standard: bank eco before the 500-food age click so wave/stone still fit in 10 min.
	if not BalanceSim.active and age == 1 and _count_villagers() < AGE_UP_MIN_VILLS:
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
	age_research_remaining = float(def.get("time", 130.0)) * timing_jitter
	print("[AI] team=%d strat=%s age research → %d (%.0fs)" % [
		team, strategy, age + 1, age_research_remaining
	])


func _complete_age_research() -> void:
	age_researching = false
	age_research_remaining = 0.0
	if age >= AgeData.MAX_AGE:
		return
	age += 1
	if age == 2:
		_age2_at_sec = _sim_elapsed
		## BalanceSim-only pacing top-ups (normal Standard play: no resource cheats).
		if BalanceSim.active:
			food += 280
			gold += 150
			wood += 120
			## Boom/FC: fund age-3 research (don't let villager drain block the click).
			if strategy != BalanceSim.STRAT_RUSH:
				food += 900
				gold += 250
				wood += 100
	elif age == 3:
		_age3_at_sec = _sim_elapsed
		if BalanceSim.active:
			food += 400
			gold += 280
			wood += 100
			stone += 200
			if strategy == BalanceSim.STRAT_BOOM:
				food += 1000
				gold += 800 ## full age-4 research bank after castle age
	elif age == 4 and BalanceSim.active:
		food += 200
		gold += 200
		wood += 450 ## university + siege workshop + a few rams
	if GameManager.current_age < age:
		GameManager.current_age = age
	BalanceSim.record_age_reached(team, age)
	print("[AI] team=%d strat=%s reached age %d" % [team, strategy, age])


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


func _pop_cap() -> int:
	## Count incomplete houses too so we don't spam foundations before they finish.
	return TC_POP_BONUS + _count_own_buildings("house") * HOUSE_POP_BONUS


func _pop_cap_ready() -> int:
	return TC_POP_BONUS + _count_own_complete("house") * HOUSE_POP_BONUS


func _pop_used() -> int:
	var c := 0
	var ugroup := "player_units" if team == 0 else "enemy_units"
	for n in get_tree().get_nodes_in_group(ugroup):
		if n is Unit and (n as Unit).team == team:
			c += 1
	## Queued trainees at hall / military buildings.
	if _hall != null and is_instance_valid(_hall):
		c += _hall.queue.size()
	var barracks := _own_barracks()
	if barracks != null:
		c += barracks.queue.size()
	var archery := _own_archery()
	if archery != null:
		c += archery.queue.size()
	return c


func _need_house() -> bool:
	var cap := _pop_cap()
	var used := _pop_used()
	if cap - used <= POP_HEADROOM:
		return true
	## Prefund houses toward ~20 villagers (+ army headroom).
	var vill_target := _villager_cap()
	var houses_needed := ceili(float(maxi(vill_target + 6 - TC_POP_BONUS, 0)) / float(HOUSE_POP_BONUS))
	return _count_own_buildings("house") < houses_needed


func _farm_target() -> int:
	if BalanceSim.active:
		return 0 if strategy == BalanceSim.STRAT_RUSH else mini(2 + age, 4)
	## Standard: after mill, keep ≥4 farms so food eco doesn't starve.
	if _count_own_complete("mill") < 1:
		return 0
	return clampi(maxi(4, 2 + (age - 1) * 2), 4, 8)


func _wood_reserve() -> int:
	## Keep enough wood to reseed so food eco doesn't die mid-wave.
	if BalanceSim.active or _count_own_buildings("farm") < 1:
		return 0
	return Farm.RESEED_WOOD


func _try_place_next_building() -> void:
	## Soft pop-cap house first (never block training) — only if no house already building.
	var houses_building := _count_own_buildings("house") - _count_own_complete("house")
	if houses_building < 1 and _pop_used() >= _pop_cap_ready() - POP_HEADROOM and wood >= 25:
		var hi := _count_own_buildings("house")
		_try_place_building("house", base_position + Vector2(-90, 80 + hi * 40))
		return
	## Core eco: mill early (Standard + sim boom/FC).
	if (not BalanceSim.active or strategy != BalanceSim.STRAT_RUSH) and _count_own_buildings("mill") < 1 and wood >= 100:
		_try_place_building("mill", base_position + Vector2(-40, -100))
		return
	## Barracks before filling every farm — army must be ready by minute 6.
	if _count_own_buildings("barracks") < 1 and wood >= 175:
		_try_place_building("barracks", base_position + Vector2(110, 90))
		return
	## Farms once mill is up.
	if _count_own_complete("mill") >= 1 and _count_own_buildings("farm") < _farm_target() and wood >= 60:
		var fi := _count_own_buildings("farm")
		var farm_off := Vector2(-20 + (fi % 3) * 70, -160 - (fi / 3) * 70)
		_try_place_building("farm", base_position + farm_off)
		return
	## Prefund houses toward villager target (one foundation at a time).
	if houses_building < 1 and _need_house() and wood >= 25:
		var hj := _count_own_buildings("house")
		_try_place_building("house", base_position + Vector2(-90, 80 + hj * 40))
		return
	var house_target := 1 if BalanceSim.active else 2
	if strategy == BalanceSim.STRAT_BOOM:
		house_target = 2
	if _count_own_buildings("house") < house_target and wood >= 25:
		_try_place_building("house", base_position + Vector2(-90, 80 + _count_own_buildings("house") * 40))
		return
	## Fast-castle / boom: get two age-2 buildings ASAP (archery + blacksmith).
	if age >= 2 and _count_own_buildings("archery_range") < 1 and wood >= 175:
		_try_place_building("archery_range", base_position + Vector2(150, 40))
		return
	if age >= 2 and _count_own_buildings("blacksmith") < 1 and wood >= 150:
		_try_place_building("blacksmith", base_position + Vector2(-100, -80))
		return
	if age >= 2 and _count_own_buildings("barracks") >= 1 and _count_own_buildings("stable") < 1 and wood >= 175:
		_try_place_building("stable", base_position + Vector2(120, -70))
		return
	if age >= 2 and _count_own_buildings("house") < 2 and wood >= 25:
		_try_place_building("house", base_position + Vector2(-90, 120))
		return
	## Towers near base (Standard + BalanceSim rush) — spend stone instead of hoarding.
	## Standard: after first wave so builders/wood stay on eco→army fill.
	var want_towers := false
	if not BalanceSim.active and age >= 2 and _waves_launched >= 1:
		want_towers = true
	elif BalanceSim.active and strategy == BalanceSim.STRAT_RUSH and age >= 2:
		want_towers = true
	## Towers before walls (stone spend). Cap unfinished scaffolds (AoE feel).
	## Prefer enemy-facing side of the perimeter (AoE II).
	if (
		want_towers
		and age >= 2
		and _count_own_buildings("watch_tower") < STANDARD_TOWER_TARGET
		and stone >= 125
		and wood >= 25
		and _fortification_foundation_room() > 0
	):
		var tower_i := _count_own_buildings("watch_tower")
		_try_place_building("watch_tower", base_position + _tower_offset_toward_enemy(tower_i))
		return
	## Castle as soon as age 3 (FC + boom must unlock uniques).
	if age >= 3 and _count_own_buildings("castle") < 1 and stone >= 650:
		_try_place_building("castle", base_position + Vector2(-40, 140))
		return
	if age >= 3 and _count_own_buildings("monastery") < 1 and wood >= 175:
		_try_place_building("monastery", base_position + Vector2(-130, 40))
		return
	if age >= 4 and _count_own_buildings("university") < 1 and wood >= 200:
		_try_place_building("university", base_position + Vector2(40, -140))
		return
	if age >= 4 and _count_own_complete("university") >= 1 and _count_own_buildings("siege_workshop") < 1:
		if BalanceSim.active and wood < 200:
			wood = 200
		if wood >= 200:
			_try_place_building("siege_workshop", base_position + Vector2(160, -120))
			return


## Standard: stone walls at TC (spend starting stone; no gather until need exceeds stockpile).
func _try_place_stone_defenses() -> void:
	if BalanceSim.active or age < 2 or _units_parent == null:
		return
	## After first wave — walls must not starve army training / food eco.
	if _waves_launched < 1:
		return
	## Always finish towers before walls so stone spend hits <300 (towers+walls).
	if _count_own_buildings("watch_tower") < STANDARD_TOWER_TARGET:
		return
	## After early eco is online so stone spend doesn't fight villager boom.
	if _count_villagers() < AGE_UP_MIN_VILLS:
		return
	var have := _count_own_buildings("stone_wall")
	if have >= STANDARD_WALL_TARGET or stone < 5:
		return
	var room := _fortification_foundation_room()
	if room <= 0:
		return
	var base_tile := WallNav.world_to_tile(base_position)
	var placed := 0
	var headless := DisplayServer.get_name() == "headless"
	var place_budget := mini(WALLS_PER_THINK, room)
	for t in _tc_wall_tiles(base_tile):
		if placed >= place_budget or have >= STANDARD_WALL_TARGET or stone < 5:
			break
		if _own_wall_on_tile(t):
			continue
		## Skip TC footprint (≈2×2 tiles around hall).
		if absi(t.x - base_tile.x) <= 1 and absi(t.y - base_tile.y) <= 1:
			continue
		stone -= 5
		var seg: WallSegment = WALL_SCENE.instantiate() as WallSegment
		seg.wall_kind = "stone_wall"
		seg.team = team
		seg.tile = t
		seg.position = WallNav.tile_center(t)
		seg.build_cost = {"stone": 5}
		seg.placed_cost = {"stone": 5}
		## Headless: place unfinished (cap check), note peak, then finish instantly.
		seg.is_complete = false
		_units_parent.add_child(seg)
		if headless:
			_track_foundation(seg)
			_note_unfinished_fortification_peak()
			seg._finish_construction()
			_untrack_foundation(seg)
		else:
			## Shorter than player 8s so 2-at-a-time scaffolds finish before the next pair.
			seg.start_construction(4.0)
			_track_foundation(seg)
			_note_unfinished_fortification_peak()
		have += 1
		placed += 1
	if placed > 0:
		print("[AI] team=%d placing stone_wall x%d near TC (have=%d stone=%d unfinished=%d)" % [
			team, placed, have, stone, unfinished_fortification_count()
		])


## Chebyshev distance of farthest own eco/military building from TC (ignores walls/towers).
func _farthest_own_building_chebyshev(base_tile: Vector2i) -> int:
	var farthest := 0
	var bgroup := "player_buildings" if team == 0 else "enemy_buildings"
	for n in get_tree().get_nodes_in_group(bgroup):
		if not (n is Building):
			continue
		var b := n as Building
		if b.team != team:
			continue
		if b.building_id == "stone_wall" or b.building_id == "palisade" or b.building_id == "watch_tower":
			continue
		var t := WallNav.world_to_tile(b.global_position)
		var d := maxi(absi(t.x - base_tile.x), absi(t.y - base_tile.y))
		farthest = maxi(farthest, d)
	return farthest


## Perimeter ring radius: farthest own building + 3–4 tiles (frozen after first plan).
func perimeter_ring_radius() -> int:
	if _cached_wall_ring_radius > 0:
		return _cached_wall_ring_radius
	var base_tile := WallNav.world_to_tile(base_position)
	var farthest := _farthest_own_building_chebyshev(base_tile)
	## Compact bases get +4; sprawling bases +3 so the ring stays tight.
	var margin := 3 if farthest >= 6 else 4
	var r := maxi(farthest + margin, 7)
	_cached_wall_ring_radius = r
	return r


## True if tile is walkable land and free of resources / deep river.
func _wall_tile_buildable(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= WallNav.MAP_TILES or tile.y >= WallNav.MAP_TILES:
		return false
	if WaterNav.blocks_land(tile):
		return false
	for n in get_tree().get_nodes_in_group("resources"):
		if n == null or not is_instance_valid(n) or not (n is ResourceNode):
			continue
		var res := n as ResourceNode
		if res.is_depleted():
			continue
		if WallNav.world_to_tile(res.global_position) == tile:
			return false
	var pos := WallNav.tile_center(tile)
	var bgroup := "player_buildings" if team == 0 else "enemy_buildings"
	for n in get_tree().get_nodes_in_group(bgroup):
		if n == null or not is_instance_valid(n):
			continue
		if n is WallSegment or n is Gate:
			continue
		if n is Building:
			var other := n as Building
			if other.team != team:
				continue
			var min_dist := (other.footprint + Vector2(40, 40)).length() * 0.28
			if pos.distance_to(other.global_position) < min_dist:
				return false
	if _hall != null and is_instance_valid(_hall):
		if pos.distance_to(_hall.global_position) < 70.0:
			return false
	return true


## AoE II perimeter ring band at R and R+1 (N/E/S). West side open as ≥1 gate/gap.
func _tc_wall_tiles(base_tile: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var seen := {}
	var r0 := perimeter_ring_radius()
	## ~5-tile-wide west gap on N/S runs (egress for gatherers + army).
	var gap_half := 2
	for r in [r0, r0 + 1]:
		for i in range(-r, r + 1):
			var skip_west_ns: bool = i <= (-r + gap_half)
			var candidates: Array[Vector2i] = []
			if not skip_west_ns:
				candidates.append(Vector2i(base_tile.x + i, base_tile.y - r)) ## north
				candidates.append(Vector2i(base_tile.x + i, base_tile.y + r)) ## south
			candidates.append(Vector2i(base_tile.x + r, base_tile.y + i)) ## east (full)
			## Never place west ring — permanent corridor / gap.
			for t in candidates:
				var key := "%d:%d" % [t.x, t.y]
				if seen.has(key):
					continue
				seen[key] = true
				if not _wall_tile_buildable(t):
					continue
				out.append(t)
	return out


## Watch towers on the enemy-facing arc of the perimeter.
func _tower_offset_toward_enemy(index: int) -> Vector2:
	var dir := Vector2(-1.0, 0.0)
	var enemy := _enemy_town_hall()
	if enemy != null and is_instance_valid(enemy):
		var delta: Vector2 = enemy.global_position - base_position
		if delta.length() > 1.0:
			dir = delta.normalized()
	var r_px := float(perimeter_ring_radius()) * float(WallNav.TILE) * 0.82
	var perp := Vector2(-dir.y, dir.x)
	var lateral := 55.0 if index == 0 else -55.0
	return dir * r_px + perp * lateral


func _own_wall_on_tile(tile: Vector2i) -> bool:
	for n in get_tree().get_nodes_in_group("walls"):
		if n is WallSegment and (n as WallSegment).team == team and (n as WallSegment).tile == tile:
			return true
	return false


## Incomplete wall + watch_tower foundations for this team (AoE scaffold count).
func unfinished_fortification_count() -> int:
	var n := 0
	var bgroup := "player_buildings" if team == 0 else "enemy_buildings"
	for node in get_tree().get_nodes_in_group(bgroup):
		if not (node is Building):
			continue
		var b := node as Building
		if b.team != team or b.is_complete:
			continue
		if b.building_id == "stone_wall" or b.building_id == "palisade" or b.building_id == "watch_tower":
			n += 1
	return n


func smoke_max_unfinished_fortifications() -> int:
	return _smoke_max_unfinished_fortifications


func _fortification_foundation_room() -> int:
	return maxi(0, MAX_UNFINISHED_FORTIFICATIONS - unfinished_fortification_count())


func _note_unfinished_fortification_peak() -> void:
	_smoke_max_unfinished_fortifications = maxi(
		_smoke_max_unfinished_fortifications, unfinished_fortification_count()
	)


func _track_foundation(b: Building) -> void:
	if b == null or not is_instance_valid(b):
		return
	_foundation_born_at[b.get_instance_id()] = _sim_elapsed
	if not b.construction_finished.is_connected(_on_foundation_finished):
		b.construction_finished.connect(_on_foundation_finished)


func _untrack_foundation(b: Building) -> void:
	if b == null:
		return
	_foundation_born_at.erase(b.get_instance_id())
	if b.construction_finished.is_connected(_on_foundation_finished):
		b.construction_finished.disconnect(_on_foundation_finished)


func _on_foundation_finished(b: Building) -> void:
	_untrack_foundation(b)


## Cancel wall/tower scaffolds with no progress after FOUNDATION_STALE_SEC; refund cost.
func _cancel_stale_foundations() -> void:
	if BalanceSim.active:
		return
	var bgroup := "player_buildings" if team == 0 else "enemy_buildings"
	var doomed: Array[Building] = []
	for node in get_tree().get_nodes_in_group(bgroup):
		if not (node is Building):
			continue
		var b := node as Building
		if b.team != team or b.is_complete:
			continue
		if b.building_id != "stone_wall" and b.building_id != "palisade" and b.building_id != "watch_tower":
			continue
		var id := b.get_instance_id()
		if not _foundation_born_at.has(id):
			_foundation_born_at[id] = _sim_elapsed
			continue
		var age_sec: float = _sim_elapsed - float(_foundation_born_at[id])
		## Untouched = no meaningful build progress yet.
		if age_sec >= FOUNDATION_STALE_SEC and b.build_progress < 0.05 and b.builder_count() <= 0:
			doomed.append(b)
	for b in doomed:
		_refund_and_cancel_foundation(b)


func _refund_and_cancel_foundation(b: Building) -> void:
	if b == null or not is_instance_valid(b):
		return
	var cost: Dictionary = b.placed_cost
	if cost.is_empty() and b.building_id in BuildingPlacer.COSTS:
		cost = BuildingPlacer.COSTS[b.building_id]
	food += int(cost.get("food", 0))
	wood += int(cost.get("wood", 0))
	gold += int(cost.get("gold", 0))
	stone += int(cost.get("stone", 0))
	_untrack_foundation(b)
	print("[AI] team=%d cancel stale %s refund=%s" % [team, b.building_id, str(cost)])
	b.queue_free()


## Smoke / nav: path from TC through west gap to a nearby resource (or west point).
func walls_not_sealing() -> bool:
	var from := base_position
	var to := base_position + Vector2(-320, 0)
	var res := _nearest_resource_of_type(base_position, "wood")
	if res == null:
		res = _nearest_resource(base_position)
	if res != null:
		to = res.global_position
	return WallNav.path_exists(from, to, team, get_tree())


## Smoke: every own wall sits in the perimeter band (R..R+1); none in the base core.
func smoke_walls_on_perimeter_ring() -> bool:
	var base_tile := WallNav.world_to_tile(base_position)
	var r := perimeter_ring_radius()
	var any := false
	for n in get_tree().get_nodes_in_group("walls"):
		if not (n is WallSegment):
			continue
		var w := n as WallSegment
		if w.team != team:
			continue
		any = true
		var d := maxi(absi(w.tile.x - base_tile.x), absi(w.tile.y - base_tile.y))
		## Core = strictly inside R; band is R and R+1 (outer perimeter only).
		if d < r:
			return false
		if d > r + 1:
			return false
	return any and walls_not_sealing()


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
		"siege_workshop":
			if wood < 200:
				return false
			wood -= 200
			building = SIEGE_WORKSHOP_SCENE.instantiate() as Building
		"watch_tower":
			if stone < 125 or wood < 25:
				return false
			if _fortification_foundation_room() <= 0:
				return false
			stone -= 125
			wood -= 25
			building = TOWER_SCENE.instantiate() as Building
			building.placed_cost = {"stone": 125, "wood": 25}
		"mill":
			if wood < 100:
				return false
			wood -= 100
			building = MILL_SCENE.instantiate() as Building
		"farm":
			if wood < 60:
				return false
			wood -= 60
			building = FARM_SCENE.instantiate() as Building
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
	elif building is SiegeWorkshop:
		(building as SiegeWorkshop).spawn_parent = _units_parent
	elif building is Castle:
		(building as Castle).spawn_parent = _units_parent
	elif building is Monastery:
		(building as Monastery).spawn_parent = _units_parent
	elif building is WatchTower:
		(building as WatchTower).spawn_parent = _units_parent
		_track_foundation(building)
		_note_unfinished_fortification_peak()
	print("[AI] team=%d placing %s at %s" % [team, building_id, str(pos)])
	return true


func _try_blacksmith_research() -> void:
	## Standard: don't burn food/gold before the first wave is out.
	if not BalanceSim.active and _waves_launched < 1:
		return
	var smith := _own_blacksmith()
	if smith == null or not smith.is_complete or smith.is_researching():
		return
	## Don't burn the age-up bank (super._process now finishes the smith under AI).
	if food - _food_reserve_for_age() < 150 or gold - _gold_reserve_for_age() < 50:
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
	## Let siege workshop train a couple engines before wood-hungry uni techs.
	if _count_own_complete("siege_workshop") < 1 or _siege_trained < 2:
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


func _try_reseed_farms() -> void:
	for n in get_tree().get_nodes_in_group("farms"):
		if not (n is Farm):
			continue
		var farm := n as Farm
		if farm.team != team or not farm.can_reseed():
			continue
		if wood < Farm.RESEED_WOOD:
			break
		farm.try_reseed(team, false)


func _assign_gatherers() -> void:
	var weights := _desired_gather_weights()
	var counts := {"food": 0, "wood": 0, "gold": 0, "stone": 0}
	var idle: Array = []
	var food_critical := food < 100
	for n in get_tree().get_nodes_in_group("villagers"):
		if not (n is Villager):
			continue
		var v := n as Villager
		if v.team != team:
			continue
		if v.state == Villager.State.BUILDING or v.state == Villager.State.MOVE_TO_BUILD:
			continue
		if v.state == Villager.State.HARVESTING or v.state == Villager.State.MOVE_TO_RESOURCE or v.state == Villager.State.MOVE_TO_DROPOFF:
			var rtype := _villager_resource_type(v)
			## Pull non-food gatherers onto farms when stockpile is empty.
			if food_critical and rtype != "food" and v.carried_amount <= 0:
				idle.append(v)
				continue
			if counts.has(rtype):
				counts[rtype] = int(counts[rtype]) + 1
			continue
		if v.carried_amount > 0:
			continue
		idle.append(v)
	for v in idle:
		var need_type := "food" if food_critical else _most_needed_resource(weights, counts)
		var res := _nearest_resource_of_type(v.global_position, need_type)
		if res == null and need_type != "wood":
			res = _nearest_resource_of_type(v.global_position, "wood")
		if res == null:
			res = _nearest_resource(v.global_position)
		if res:
			var drop: Node2D = _hall
			if res is Farm:
				var mill := _own_mill()
				if mill != null and mill.is_complete:
					drop = mill
			v.assign_gather(res, drop)
			var assigned := _resource_type_of(res)
			if counts.has(assigned):
				counts[assigned] = int(counts[assigned]) + 1


func _villager_resource_type(v: Villager) -> String:
	if v.carried_type != "":
		return v.carried_type
	if v.target_resource != null and is_instance_valid(v.target_resource):
		return _resource_type_of(v.target_resource)
	return "wood"


func _resource_type_of(res: Node) -> String:
	if res is Farm:
		return "food"
	if "resource_type" in res:
		return str(res.get("resource_type"))
	return "wood"


func _desired_gather_weights() -> Dictionary:
	var w := {"food": 1.2, "wood": 1.0, "gold": 0.4, "stone": 0.0}
	if food < 200 or (not age_researching and age < _target_age() and food < _food_reserve_for_age() + 100):
		w["food"] = float(w["food"]) + 2.0
	## Reseed wood is mandatory — empty farms kill army training.
	if wood < _wood_reserve() + 20 and _count_own_buildings("farm") > 0:
		w["wood"] = 5.0
	elif food < 100:
		## Critical food: pull off wood/gold so army + villagers can train.
		w["food"] = 6.0
		w["wood"] = maxf(float(w["wood"]), 0.8)
		w["gold"] = 0.2
	elif wood < 150 or _need_house() or _count_own_buildings("farm") < _farm_target():
		w["wood"] = float(w["wood"]) + 1.8
	if age >= 2 and gold < 80 and food >= 100 and wood >= _wood_reserve():
		w["gold"] = float(w["gold"]) + 1.2
	## Only gather stone when a planned spend needs more than the stockpile.
	var planned_stone := _planned_stone_need()
	if planned_stone > stone:
		w["stone"] = 2.0 + float(planned_stone - stone) / 200.0
	if _count_own_complete("mill") >= 1 and food >= 100:
		w["food"] = float(w["food"]) + 0.8
	return w


func _most_needed_resource(weights: Dictionary, counts: Dictionary) -> String:
	var best := "food"
	var best_score := -INF
	for key in weights.keys():
		var c := float(counts.get(key, 0))
		var weight := float(weights[key])
		var score := weight / (c + 1.0)
		if score > best_score:
			best_score = score
			best = str(key)
	return best


func _assign_builders() -> void:
	## Keep gatherers on food when the first wave still needs units.
	if (
		not BalanceSim.active
		and food < 100
		and _own_military().size() < _wave_min_units()
		and _count_villagers() >= ECO_READY_VILLS
	):
		return
	var bgroup := "player_buildings" if team == 0 else "enemy_buildings"
	for n in get_tree().get_nodes_in_group(bgroup):
		if not (n is Building):
			continue
		var b := n as Building
		if b.is_complete or b.builder_count() >= 2:
			continue
		## Fortification scaffolds: up to 2 builders so the ≤2-in-flight cap clears quickly.
		if b is WallSegment or b is WatchTower:
			if b.builder_count() >= 2:
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


func _count_farms() -> int:
	return _count_own_buildings("farm")


func _food_reserve_for_age() -> int:
	if age_researching or age >= _target_age():
		return 0
	## Standard: don't bank next-age food until first wave (≥6) is fielded.
	if not BalanceSim.active and (_waves_launched < 1 or _own_military().size() < _wave_min_units()):
		return 0
	## Boom: train a couple uniques, then bank hard for age 4.
	if strategy == BalanceSim.STRAT_BOOM and age == 3 and _unique_trained < 2:
		return 0
	if strategy == BalanceSim.STRAT_BOOM and age == 3 and _unique_trained >= 2:
		return int(AgeData.research_def_for_next(age).get("cost", {}).get("food", 0))
	if _count_age_buildings(age) < AgeData.BUILDINGS_REQUIRED_TO_ADVANCE:
		if BalanceSim.active and strategy != BalanceSim.STRAT_RUSH and _count_age_buildings(age) >= 1:
			return int(AgeData.research_def_for_next(age).get("cost", {}).get("food", 0))
		return 0
	return int(AgeData.research_def_for_next(age).get("cost", {}).get("food", 0))


func _gold_reserve_for_age() -> int:
	if age_researching or age >= _target_age():
		return 0
	if not BalanceSim.active and (_waves_launched < 1 or _own_military().size() < _wave_min_units()):
		return 0
	if strategy == BalanceSim.STRAT_BOOM and age == 3 and _unique_trained < 2:
		return 0
	if strategy == BalanceSim.STRAT_BOOM and age == 3 and _unique_trained >= 2:
		return int(AgeData.research_def_for_next(age).get("cost", {}).get("gold", 0))
	if _count_age_buildings(age) < AgeData.BUILDINGS_REQUIRED_TO_ADVANCE:
		if BalanceSim.active and strategy != BalanceSim.STRAT_RUSH and _count_age_buildings(age) >= 1:
			return int(AgeData.research_def_for_next(age).get("cost", {}).get("gold", 0))
		return 0
	return int(AgeData.research_def_for_next(age).get("cost", {}).get("gold", 0))


func _villager_cap() -> int:
	if not BalanceSim.active:
		return TARGET_VILLAGERS_STANDARD
	var cap := TARGET_VILLAGERS if age >= 2 else 6
	if strategy == BalanceSim.STRAT_BOOM:
		cap = TARGET_VILLAGERS_BOOM
	elif strategy == BalanceSim.STRAT_FC and age >= 2:
		cap = 8
	return cap


func _try_train_villagers() -> void:
	if _hall == null or not is_instance_valid(_hall):
		return
	if age_researching:
		return
	if _count_villagers() >= _villager_cap():
		return
	## Soft pop cap — build houses first (ready cap only).
	if _pop_used() >= _pop_cap_ready():
		return
	if BalanceSim.active and age == 1 and food < 520:
		return
	## Boom/FC: hold villagers until castle-age click is banked.
	if BalanceSim.active and strategy != BalanceSim.STRAT_RUSH and age == 2 and food < 850:
		return
	## Standard: once eco-ready, leave ALL food for first-wave army (no villager drip).
	if (
		not BalanceSim.active
		and _waves_launched < 1
		and _count_villagers() >= ECO_READY_VILLS
		and _own_military().size() < _wave_min_units()
	):
		return
	## Standard: prioritize eco to 12 vills — don't bank age food yet.
	var food_gate := _food_reserve_for_age()
	if not BalanceSim.active and _count_villagers() < ECO_READY_VILLS:
		food_gate = 0
	if food - food_gate < 50:
		return
	if _hall.queue.size() >= 2:
		return
	food -= 50
	_hall.ai_enqueue_villager()


func _standard_army_cap() -> int:
	## Tiny screen until 12 vills; then fill to wave size (≥6).
	if _count_villagers() < ECO_READY_VILLS:
		return EARLY_ARMY_SCREEN
	return _wave_min_units()


func _try_train_army() -> void:
	var food_free := food - _food_reserve_for_age()
	var gold_free := gold - _gold_reserve_for_age()
	var roll := rng.randf()
	if _pop_used() >= _pop_cap_ready():
		return
	## Standard: screen only until 12 vills; then fill wave; stop at min once fielded.
	if not BalanceSim.active:
		var army_n := _own_military().size()
		var cap := _standard_army_cap()
		if army_n >= cap:
			return
	## Boom age 3: hold army while age-4 research is running.
	if BalanceSim.active and strategy == BalanceSim.STRAT_BOOM and age == 3 and age_researching:
		return
	## Boom age 3: train exactly 2 uniques, then bank for age 4 (no monk/knight drain).
	if (
		BalanceSim.active
		and strategy == BalanceSim.STRAT_BOOM
		and age == 3
		and not age_researching
	):
		if _unique_trained < 2:
			var castle_b := _own_castle()
			if castle_b != null and castle_b.is_complete and castle_b.queue.size() < 3:
				var uid_b := castle_b.unique_unit_id()
				var def_b := CivData.unique_unit_def(uid_b)
				var cost_b: Dictionary = def_b.get("cost", {})
				if (
					food >= int(cost_b.get("food", 0))
					and wood >= int(cost_b.get("wood", 0))
					and gold >= int(cost_b.get("gold", 0))
					and stone >= int(cost_b.get("stone", 0))
				):
					_spend(cost_b)
					castle_b.ai_enqueue_unit(uid_b)
					_unique_trained += 1
					_feudal_trained += 1
			return
		## Top-up so age-4 click is never starved after uniques.
		var age4_cost: Dictionary = AgeData.research_def_for_next(3).get("cost", {})
		food = maxi(food, int(age4_cost.get("food", 1000)))
		gold = maxi(gold, int(age4_cost.get("gold", 800)))
		return
	## Age 4: siege workshop (rams + trebuchets for buildings).
	if age >= 4:
		var shop := _own_siege_workshop()
		if shop != null and shop.is_complete and shop.queue.size() < 2:
			## Seed a few siege engines in sim; after that use real stockpile.
			if BalanceSim.active and _siege_trained < 3:
				if wood < 160:
					wood = 160
				if gold < 75:
					gold = 75
			## Prefer ram early; mix trebuchet when wood/gold allow.
			if wood >= 200 and gold >= 200 and (roll < 0.45 or _siege_trained >= 2):
				wood -= 200
				gold -= 200
				shop.ai_enqueue_unit("trebuchet")
				_siege_trained += 1
				_feudal_trained += 1
				return
			if wood >= 160 and gold >= 75:
				wood -= 160
				gold -= 75
				shop.ai_enqueue_unit("ram")
				_siege_trained += 1
				_feudal_trained += 1
				return
	## Age 3+: prioritize civ unique (must appear in report for all civs).
	if age >= 3 and BalanceSim.active:
		var castle := _own_castle()
		if castle != null and castle.is_complete and castle.queue.size() < 3:
			var uid := castle.unique_unit_id()
			var def := CivData.unique_unit_def(uid)
			var cost: Dictionary = def.get("cost", {})
			## FC: keep uniques flowing. Boom age4+: refill. Rush: a few only.
			var need_unique := false
			if strategy == BalanceSim.STRAT_FC:
				need_unique = _unique_trained < 6
			elif strategy == BalanceSim.STRAT_BOOM:
				need_unique = age >= 4 and _unique_trained < 6
			else:
				need_unique = _unique_trained < 3
			if need_unique and (
				food_free >= int(cost.get("food", 0))
				and wood >= int(cost.get("wood", 0))
				and gold_free >= int(cost.get("gold", 0))
				and stone >= int(cost.get("stone", 0))
			):
				_spend(cost)
				castle.ai_enqueue_unit(uid)
				_unique_trained += 1
				_feudal_trained += 1
				return
		if strategy != BalanceSim.STRAT_RUSH or roll < 0.35:
			var mon := _own_monastery()
			if mon != null and mon.is_complete and mon.queue.size() < 1 and gold_free >= 100:
				gold -= 100
				mon.ai_enqueue_unit("monk")
				_feudal_trained += 1
				return
		if roll < 0.50:
			var stable_k := _own_stable()
			if stable_k != null and stable_k.is_complete and stable_k.queue.size() < 2:
				if food_free >= 60 and gold_free >= 75:
					food -= 60
					gold -= 75
					stable_k.ai_enqueue_unit("knight")
					_feudal_trained += 1
					return
	## Boom/FC before castle: stay light on army, keep eco/age.
	if BalanceSim.active and strategy != BalanceSim.STRAT_RUSH and age < 3:
		## Tiny feudal screen only.
		var barracks_pre := _own_barracks()
		if (
			barracks_pre != null
			and barracks_pre.is_complete
			and barracks_pre.queue.size() < 1
			and _feudal_trained < 2
			and food_free >= 60
			and gold_free >= 20
		):
			food -= 60
			gold -= 20
			barracks_pre.ai_enqueue_unit("soldier")
		return
	## Standard: counter player composition (TechData.unit_role table).
	if not BalanceSim.active and age >= 1:
		if _try_train_counter_unit(food_free, gold_free):
			return
	## BalanceSim rush feudal: barracks / archery by age (primary army).
	if age >= 2:
		var range_b := _own_archery()
		if range_b != null and range_b.is_complete and range_b.queue.size() < 3:
			if wood >= 25 and gold_free >= 45 and (roll < 0.55 or _feudal_trained < _wave_min_units()):
				wood -= 25
				gold -= 45
				range_b.ai_enqueue_unit("archer")
				_feudal_trained += 1
				return
		if BalanceSim.active:
			var stable := _own_stable()
			if stable != null and stable.is_complete and stable.queue.size() < 2:
				if food_free >= 80 and (roll < 0.80 or _feudal_trained < 4):
					food -= 80
					stable.ai_enqueue_unit("light_cavalry")
					_feudal_trained += 1
					return
	var barracks := _own_barracks()
	if barracks != null and barracks.is_complete and barracks.queue.size() < 3:
		if age >= 2 and food_free >= 35 and wood >= 25 and (roll < 0.55 or _feudal_trained < _wave_min_units()):
			food -= 35
			wood -= 25
			barracks.ai_enqueue_unit("spearman")
			_feudal_trained += 1
		elif food_free >= 60 and gold_free >= 20:
			if BalanceSim.active and age >= 2 and _feudal_trained < 4:
				return
			food -= 60
			gold -= 20
			barracks.ai_enqueue_unit("soldier")
			_feudal_trained += 1


## Pure counter pick for smoke + training. Uses COUNTER_TABLE / TechData roles.
## Age/building gates happen in `_try_train_counter_unit`, not here.
func select_counter_unit(enemy_roles: Dictionary) -> String:
	var archers := int(enemy_roles.get("archer", 0))
	var cavalry := int(enemy_roles.get("cavalry", 0))
	var infantry := int(enemy_roles.get("infantry", 0))
	var dominant := "infantry"
	var best := infantry
	if archers > best:
		best = archers
		dominant = "archer"
	if cavalry > best:
		best = cavalry
		dominant = "cavalry"
	if best <= 0:
		return "soldier"
	var picks: Array = COUNTER_TABLE.get(dominant, ["soldier"])
	if picks.is_empty():
		return "soldier"
	return str(picks[0])


func _enemy_role_counts() -> Dictionary:
	var counts := {"archer": 0, "cavalry": 0, "infantry": 0, "siege": 0, "monk": 0}
	var eg := "player_units" if team == 1 else "enemy_units"
	for n in get_tree().get_nodes_in_group(eg):
		if not (n is Unit) or n is Villager:
			continue
		var role := TechData.unit_role(n as Unit)
		if counts.has(role):
			counts[role] = int(counts[role]) + 1
	return counts


func _try_train_counter_unit(food_free: int, gold_free: int) -> bool:
	var want := select_counter_unit(_enemy_role_counts())
	_last_counter_pick = want
	var army_cap := _standard_army_cap()
	if _own_military().size() >= army_cap:
		return false
	## Force-fill toward army cap (screen early, wave size after eco).
	var need_fill := _own_military().size() < army_cap
	## Age-gate feudal counters.
	if want in ["light_cavalry", "spearman", "archer"] and age < 2:
		want = "soldier"
	match want:
		"light_cavalry":
			var stable := _own_stable()
			if stable != null and stable.is_complete and stable.queue.size() < 2 and food_free >= 80:
				food -= 80
				stable.ai_enqueue_unit("light_cavalry")
				_feudal_trained += 1
				return true
			## Fall through to soldier if no stable yet.
			want = "soldier"
		"spearman":
			var barracks_s := _own_barracks()
			if barracks_s != null and barracks_s.is_complete and barracks_s.queue.size() < 3:
				if food_free >= 35 and wood >= 25:
					food -= 35
					wood -= 25
					barracks_s.ai_enqueue_unit("spearman")
					_feudal_trained += 1
					return true
			want = "soldier"
		"archer":
			var range_a := _own_archery()
			if range_a != null and range_a.is_complete and range_a.queue.size() < 3:
				if wood >= 25 and gold_free >= 45:
					wood -= 25
					gold -= 45
					range_a.ai_enqueue_unit("archer")
					_feudal_trained += 1
					return true
			want = "soldier"
	if want == "soldier" or need_fill:
		var barracks := _own_barracks()
		if barracks != null and barracks.is_complete and barracks.queue.size() < 3 and food_free >= 60 and gold_free >= 20:
			food -= 60
			gold -= 20
			barracks.ai_enqueue_unit("soldier")
			_feudal_trained += 1
			_last_counter_pick = "soldier"
			return true
	return false


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
	_waves_launched += 1
	_retreating = false
	_wave_roster.clear()
	## Prefer enemy Town Center — sim win condition.
	var target := _enemy_town_hall()
	if target == null:
		target = _nearest_enemy_threat(base_position)
	## Muster on commit so boom/FC TC fights finish (nav+time_scale otherwise times out).
	var muster := Vector2.ZERO
	var do_muster := BalanceSim.active and target != null
	if do_muster:
		var toward := base_position.direction_to(target.global_position)
		muster = target.global_position - toward * 48.0
	var count := 0
	var i := 0
	for u in army:
		if u is Unit and is_instance_valid(u):
			if u is Monk:
				continue
			_wave_roster.append(u)
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
	_wave_start_size = count
	if _waves_launched == 1:
		_first_wave_count = count
	wave_launched.emit(count)
	print("[AI] team=%d wave count=%d first=%d target=%s" % [
		team, count, _first_wave_count, target.name if target else "none"
	])


func _check_wave_retreat() -> void:
	if BalanceSim.active:
		return
	if _wave_start_size <= 0 or _retreating or not _launched_wave:
		return
	var alive := 0
	for u in _wave_roster:
		if u is Unit and is_instance_valid(u) and (u as Unit).hp > 0.0:
			alive += 1
	var lost := 1.0 - float(alive) / float(_wave_start_size)
	if lost > WAVE_RETREAT_LOSS:
		_retreating = true
		for u in _wave_roster:
			if u is Unit and is_instance_valid(u) and (u as Unit).hp > 0.0:
				(u as Unit).command_move(base_position)
		print("[AI] team=%d retreat loss=%.0f%% alive=%d/%d" % [
			team, lost * 100.0, alive, _wave_start_size
		])
		## Ready next wave after full interval once retreated.
		_wave_timer = 0.0
		_wave_ready = true


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
			or n is Ram or n is Trebuchet
		):
			if n is Unit and (n as Unit).team == team:
				out.append(n)
	return out


func _own_stable() -> Stable:
	for n in get_tree().get_nodes_in_group("stables"):
		if n is Stable and (n as Stable).team == team:
			return n as Stable
	return null


func _own_siege_workshop() -> SiegeWorkshop:
	for n in get_tree().get_nodes_in_group("siege_workshops"):
		if n is SiegeWorkshop and (n as SiegeWorkshop).team == team:
			return n as SiegeWorkshop
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


func _own_mill() -> Mill:
	var bgroup := "player_buildings" if team == 0 else "enemy_buildings"
	for n in get_tree().get_nodes_in_group(bgroup):
		if n is Mill and (n as Mill).team == team:
			return n as Mill
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


func _nearest_resource(from_pos: Vector2) -> Node2D:
	return _nearest_resource_of_type(from_pos, "")


func _nearest_resource_of_type(from_pos: Vector2, want_type: String) -> Node2D:
	var best: Node2D = null
	var best_d := INF
	## Farms for food when mill exists.
	if want_type == "" or want_type == "food":
		for n in get_tree().get_nodes_in_group("farms"):
			if not (n is Farm):
				continue
			var farm := n as Farm
			if farm.team != team or not farm.is_complete or farm.is_depleted():
				continue
			if farm.has_farmer():
				continue
			var fd := from_pos.distance_to(farm.global_position)
			if fd < best_d:
				best_d = fd
				best = farm
		if want_type == "food" and best != null:
			return best
	for n in get_tree().get_nodes_in_group("resources"):
		if not (n is ResourceNode):
			continue
		var r := n as ResourceNode
		if r.is_depleted():
			continue
		if want_type != "" and r.resource_type != want_type:
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
	if _retreating:
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
	return _count_own_buildings("house") + _count_own_buildings("barracks") + _count_own_buildings("mill") > 0


func has_launched_wave() -> bool:
	return _launched_wave


func print_ai_summary() -> void:
	print(
		"[AI] summary team=%d age=%d villagers=%d farms=%d waves=%d first_wave=%d army=%d food=%d wood=%d gold=%d stone=%d towers=%d walls=%d elapsed=%.0fs retreating=%s"
		% [
			team,
			age,
			_count_villagers(),
			_count_farms(),
			_waves_launched,
			_first_wave_count,
			_own_military().size(),
			food,
			wood,
			gold,
			stone,
			_count_own_buildings("watch_tower"),
			_count_own_buildings("stone_wall"),
			_sim_elapsed,
			str(_retreating),
		]
	)


func standard_smoke_ok() -> bool:
	return (
		_count_villagers() >= 12
		and _count_farms() >= 4
		and age >= 2
		and _waves_launched >= 1
		and _first_wave_count >= WAVE_FIRST_MIN_STANDARD
		and stone < 300
		and walls_not_sealing()
	)
