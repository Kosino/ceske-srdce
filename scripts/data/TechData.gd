extends Object
class_name TechData
## Blacksmith (and future) research definitions.


const FORGING := "forging"
const CHAIN_MAIL := "chain_mail"
const FLETCHING := "fletching"

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

const BLACKSMITH_ORDER := [FORGING, CHAIN_MAIL, FLETCHING]


static func tech_name(tech_id: String) -> String:
	return str(BLACKSMITH_TECHS.get(tech_id, {}).get("name", tech_id))


static func tech_def(tech_id: String) -> Dictionary:
	return BLACKSMITH_TECHS.get(tech_id, {})


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
