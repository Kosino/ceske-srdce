extends Object
class_name TechData
## Blacksmith + University research definitions.


const FORGING := "forging"
const CHAIN_MAIL := "chain_mail"
const FLETCHING := "fletching"

const MASONRY := "masonry"
const BALLISTICS := "ballistics"
const TOWER_ENGINE := "tower_engine"

const BLACKSMITH_TECHS := {
	FORGING: {
		"name": "Kovářství",
		"cost": {"food": 150},
		"time": 50.0,
		"melee_attack": 1.0,
		"affects": ["infantry", "cavalry"],
	},
	CHAIN_MAIL: {
		"name": "Kroužková zbroj",
		"cost": {"food": 100},
		"time": 40.0,
		"melee_armor": 1.0,
		"pierce_armor": 1.0,
		"affects": ["infantry"],
	},
	FLETCHING: {
		"name": "Kalené hroty",
		"cost": {"food": 100, "gold": 50},
		"time": 40.0,
		"pierce_attack": 1.0,
		"affects": ["archer"],
	},
}

## Univerzita — NÁVRH AoE II-like (Fáze 4).
const UNIVERSITY_TECHS := {
	MASONRY: {
		"name": "Zednictví",
		"cost": {"wood": 150, "stone": 175},
		"time": 60.0,
		"building_hp_mult": 1.10,
	},
	BALLISTICS: {
		"name": "Balistika",
		"cost": {"wood": 300, "gold": 175},
		"time": 60.0,
		## Simplified: +1 tile range for archers + towers (lead-target later).
		"attack_range": 40.0,
		"tower_range": 40.0,
		"affects": ["archer"],
	},
	TOWER_ENGINE: {
		"name": "Strojní věž",
		"cost": {"wood": 200, "stone": 100},
		"time": 50.0,
		"tower_attack": 2.0,
		"tower_range": 40.0,
	},
}

const BLACKSMITH_ORDER := [FORGING, CHAIN_MAIL, FLETCHING]
const UNIVERSITY_ORDER := [MASONRY, BALLISTICS, TOWER_ENGINE]


static func tech_name(tech_id: String) -> String:
	return str(tech_def(tech_id).get("name", tech_id))


static func tech_def(tech_id: String) -> Dictionary:
	if BLACKSMITH_TECHS.has(tech_id):
		return BLACKSMITH_TECHS[tech_id]
	if UNIVERSITY_TECHS.has(tech_id):
		return UNIVERSITY_TECHS[tech_id]
	return {}


static func is_blacksmith_tech(tech_id: String) -> bool:
	return BLACKSMITH_TECHS.has(tech_id)


static func is_university_tech(tech_id: String) -> bool:
	return UNIVERSITY_TECHS.has(tech_id)


static func unit_role(unit: Unit) -> String:
	if unit == null:
		return ""
	if unit is Archer or unit.unit_id == "archer" or unit.unit_id == "valecny_vuz":
		return "archer"
	if unit.is_cavalry:
		return "cavalry"
	if unit is Villager:
		return "villager"
	# Soldier / Spearman / unique infantry.
	return "infantry"
