extends Node

signal resources_changed
signal population_changed
signal age_changed
signal tech_researched(team: int, tech_id: String)

const POPULATION_HARD_CAP := 200

var food: int = 200
var wood: int = 200
var gold: int = 100
var stone: int = 0
var population: int = 0
## Starts at 0; Radnice/Dům přidávají +5 (strop 200).
var population_max: int = 0
var _current_age: int = 1
## Always emit age_changed so AgeLabel / research button stay in sync.
var current_age: int:
	get:
		return _current_age
	set(value):
		if _current_age == value:
			return
		_current_age = value
		age_changed.emit()

## Fáze 2 — civilizace (default Moravané vs Husité).
var player_civ: String = CivData.DEFAULT_PLAYER
var enemy_civ: String = CivData.DEFAULT_ENEMY

## Per-team researched tech ids (once per game / team).
var _researched: Dictionary = {0: {}, 1: {}}


func civ_for_team(team: int) -> String:
	return player_civ if team == 0 else enemy_civ


func get_civ_name(team: int = 0) -> String:
	return CivData.civ_name(civ_for_team(team))


func gather_rate_mult(team: int, resource_type: String) -> float:
	return CivData.gather_mult(civ_for_team(team), resource_type)


func adjust_building_cost(cost: Dictionary, team: int = 0) -> Dictionary:
	var out := cost.duplicate()
	var wood_m := CivData.wood_cost_mult(civ_for_team(team))
	if wood_m != 1.0 and out.has("wood"):
		out["wood"] = maxi(1, int(round(float(out["wood"]) * wood_m)))
	return out


func apply_civ_unit_bonuses(unit: Unit) -> void:
	if unit == null:
		return
	CivData.apply_unit_bonuses(unit, civ_for_team(unit.team))


func has_tech(team: int, tech_id: String) -> bool:
	var bag: Dictionary = _researched.get(team, {})
	return bool(bag.get(tech_id, false))


func mark_tech_researched(team: int, tech_id: String) -> void:
	if not _researched.has(team):
		_researched[team] = {}
	if has_tech(team, tech_id):
		return
	(_researched[team] as Dictionary)[tech_id] = true
	_apply_tech_to_team_units(team, tech_id)
	_apply_tech_to_team_buildings(team, tech_id)
	tech_researched.emit(team, tech_id)
	print("[TECH] team%d researched %s" % [team, tech_id])


func apply_researched_techs_to_unit(unit: Unit) -> void:
	if unit == null:
		return
	var bag: Dictionary = _researched.get(unit.team, {})
	for tech_id in bag.keys():
		if bag[tech_id]:
			_apply_tech_to_unit(unit, str(tech_id))


func apply_researched_techs_to_building(building: Building) -> void:
	if building == null:
		return
	var bag: Dictionary = _researched.get(building.team, {})
	for tech_id in bag.keys():
		if bag[tech_id]:
			_apply_tech_to_building(building, str(tech_id))


func _apply_tech_to_team_units(team: int, tech_id: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var group := "player_units" if team == 0 else "enemy_units"
	for n in tree.get_nodes_in_group(group):
		if n is Unit:
			_apply_tech_to_unit(n as Unit, tech_id)


func _apply_tech_to_team_buildings(team: int, tech_id: String) -> void:
	var tree := get_tree()
	if tree == null:
		return
	var group := "player_buildings" if team == 0 else "enemy_buildings"
	for n in tree.get_nodes_in_group(group):
		if n is Building:
			_apply_tech_to_building(n as Building, tech_id)


func _apply_tech_to_unit(unit: Unit, tech_id: String) -> void:
	var def := TechData.tech_def(tech_id)
	if def.is_empty():
		return
	var role := TechData.unit_role(unit)
	var affects: Array = def.get("affects", [])
	if role not in affects:
		return
	if def.has("melee_attack") and unit.attack_type == "melee":
		unit.attack_damage += float(def["melee_attack"])
	if def.has("pierce_attack") and unit.attack_type == "pierce":
		unit.attack_damage += float(def["pierce_attack"])
	if def.has("melee_armor"):
		unit.melee_armor += float(def["melee_armor"])
	if def.has("pierce_armor"):
		unit.pierce_armor += float(def["pierce_armor"])
	if def.has("attack_range"):
		unit.attack_range += float(def["attack_range"])


func _apply_tech_to_building(building: Building, tech_id: String) -> void:
	var def := TechData.tech_def(tech_id)
	if def.is_empty() or building == null:
		return
	if def.has("building_hp_mult"):
		building.apply_masonry_bonus(float(def["building_hp_mult"]))
	if building is WatchTower:
		var tower := building as WatchTower
		if def.has("tower_attack"):
			tower.apply_tower_attack_bonus(float(def["tower_attack"]), tech_id)
		if def.has("tower_range"):
			tower.apply_tower_range_bonus(float(def["tower_range"]), tech_id)


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
	resources_changed.emit()


func can_afford(cost: Dictionary) -> bool:
	return (
		food >= cost.get("food", 0)
		and wood >= cost.get("wood", 0)
		and gold >= cost.get("gold", 0)
		and stone >= cost.get("stone", 0)
	)


func spend(cost: Dictionary) -> bool:
	if not can_afford(cost):
		return false
	food -= cost.get("food", 0)
	wood -= cost.get("wood", 0)
	gold -= cost.get("gold", 0)
	stone -= cost.get("stone", 0)
	resources_changed.emit()
	return true


func can_add_population(n: int) -> bool:
	return population + n <= population_max


func change_population(delta: int) -> void:
	population = clampi(population + delta, 0, maxi(population_max, 0))
	population_changed.emit()


func add_population_cap(amount: int) -> void:
	population_max = mini(population_max + amount, POPULATION_HARD_CAP)
	population_changed.emit()


func get_age_name() -> String:
	return AgeData.age_name(current_age)


func is_building_unlocked(building_id: String) -> bool:
	return AgeData.is_building_unlocked(building_id, current_age)


func is_unit_unlocked(unit_id: String) -> bool:
	return AgeData.is_unit_unlocked(unit_id, current_age)


## Count complete player buildings introduced in `age` (excludes Radnice / DropOff).
func count_age_buildings(age: int, tree: SceneTree = null) -> int:
	var scene_tree := tree if tree else get_tree()
	if scene_tree == null:
		return 0
	var count := 0
	for n in scene_tree.get_nodes_in_group("player_buildings"):
		if n is DropOff:
			continue
		if not (n is Building):
			continue
		var b := n as Building
		if not b.is_complete:
			continue
		if b.building_id == "":
			continue
		if AgeData.building_unlock_age(b.building_id) == age:
			count += 1
	return count


func can_research_next_age(tree: SceneTree = null) -> bool:
	if current_age >= AgeData.MAX_AGE:
		return false
	var def := AgeData.research_def_for_next(current_age)
	if def.is_empty():
		return false
	if not can_afford(def.get("cost", {})):
		return false
	return count_age_buildings(current_age, tree) >= AgeData.BUILDINGS_REQUIRED_TO_ADVANCE


func advance_age() -> void:
	if current_age >= AgeData.MAX_AGE:
		return
	current_age += 1 # setter emits age_changed
	print("[AGE] advanced to %d (%s)" % [current_age, get_age_name()])
