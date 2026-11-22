extends Object
class_name AgeData
## Single unlock / research table for ages. Ages 1–3 content; 4 mostly data-only.

const MAX_AGE := 4
const BUILDINGS_REQUIRED_TO_ADVANCE := 2

const AGE_NAMES := {
	1: "Velká Morava",
	2: "Přemyslovci",
	3: "Husitství",
	4: "Habsburkové",
}

## Research to reach the keyed age (from previous). Costs/times = NÁVRH (AoE2-like).
const AGE_RESEARCH := {
	2: {"cost": {"food": 500}, "time": 130.0},
	3: {"cost": {"food": 800, "gold": 200}, "time": 160.0},
	4: {"cost": {"food": 1000, "gold": 800}, "time": 190.0},
}

## Min age required to place / train. Ages 3–4 reserved for future content.
const BUILDING_UNLOCK_AGE := {
	"house": 1,
	"lumber_camp": 1,
	"mining_camp": 1,
	"mill": 1,
	"barracks": 1,
	"archery_range": 2,
	"blacksmith": 2,
	"stable": 2, # requires Barracks (checked in BuildingPlacer)
	"castle": 3,
	# Age 3+ placeholders (data-only; no scenes yet):
	"monastery": 3,
	"university": 4,
}

const UNIT_UNLOCK_AGE := {
	"villager": 1,
	"soldier": 1,
	"spearman": 2,
	"archer": 2,
	"light_cavalry": 2,
	"knight": 3,
	"bojovnik_bradatice": 3,
	"druzinik": 3,
	"valecny_vuz": 3,
	"lancknecht": 3,
	# Age 3+ placeholders (data-only):
	"monk": 3,
	"siege": 4,
}


static func age_name(age: int) -> String:
	return str(AGE_NAMES.get(age, "Věk %d" % age))


static func next_age(current: int) -> int:
	return mini(current + 1, MAX_AGE)


static func research_def_for_next(current: int) -> Dictionary:
	var target := next_age(current)
	if target <= current:
		return {}
	return AGE_RESEARCH.get(target, {})


static func building_unlock_age(building_id: String) -> int:
	return int(BUILDING_UNLOCK_AGE.get(building_id, 1))


static func unit_unlock_age(unit_id: String) -> int:
	return int(UNIT_UNLOCK_AGE.get(unit_id, 1))


static func is_building_unlocked(building_id: String, age: int) -> bool:
	if building_id not in BUILDING_UNLOCK_AGE:
		return false
	return age >= building_unlock_age(building_id)


static func is_unit_unlocked(unit_id: String, age: int) -> bool:
	if unit_id not in UNIT_UNLOCK_AGE:
		return false
	return age >= unit_unlock_age(unit_id)
