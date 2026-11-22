extends Object
class_name CivData
## Civilization ids + Schváleno bonuses. Unique units train at Castle (age 3).

const MORAVANE := "moravane"
const PREMYSLOVCI := "premyslovci"
const HUSITE := "husite"
const HABSBURKOVE := "habsburkove"

const DEFAULT_PLAYER := MORAVANE
const DEFAULT_ENEMY := HUSITE

const ALL_CIV_IDS := [MORAVANE, PREMYSLOVCI, HUSITE, HABSBURKOVE]

const INFANTRY_IDS := [
	"soldier", "spearman", "archer", "bojovnik_bradatice", "lancknecht",
]

## Schváleno 2026-11-22. Keys match DESIGN “hlavní síla”.
const CIVS := {
	MORAVANE: {
		"name": "Moravané",
		"unique_unit": "bojovnik_bradatice",
		"gather": {"wood": 1.15},
		"wood_cost": 0.90,
	},
	PREMYSLOVCI: {
		"name": "Přemyslovci",
		"unique_unit": "druzinik",
		"gather": {"gold": 1.15},
		"cavalry_damage": 1.10,
	},
	HUSITE: {
		"name": "Husité",
		"unique_unit": "valecny_vuz",
		"infantry_hp": 1.10,
		"infantry_damage": 1.05,
	},
	HABSBURKOVE: {
		"name": "Habsburkové",
		"unique_unit": "lancknecht",
		"gather": {"stone": 1.10},
		"infantry_hp": 1.15,
	},
}

## Castle unique unit defs (train 35 s). Historical notes live in DESIGN.md.
const UNIQUE_UNITS := {
	"bojovnik_bradatice": {
		"label": "Bojovník s bradaticí",
		"cost": {"food": 60, "gold": 30},
		"time": 35.0,
		"civ": MORAVANE,
	},
	"druzinik": {
		"label": "Družiník",
		"cost": {"food": 70, "gold": 70},
		"time": 35.0,
		"civ": PREMYSLOVCI,
	},
	"valecny_vuz": {
		"label": "Válečný vůz",
		"cost": {"wood": 110, "gold": 60},
		"time": 35.0,
		"civ": HUSITE,
	},
	"lancknecht": {
		"label": "Lancknecht",
		"cost": {"food": 55, "gold": 45},
		"time": 35.0,
		"civ": HABSBURKOVE,
	},
}


static func civ_name(civ_id: String) -> String:
	var def: Dictionary = CIVS.get(civ_id, {})
	return str(def.get("name", civ_id))


static func def_for(civ_id: String) -> Dictionary:
	return CIVS.get(civ_id, CIVS[DEFAULT_PLAYER])


static func unique_unit_id(civ_id: String) -> String:
	return str(def_for(civ_id).get("unique_unit", ""))


static func unique_unit_def(unit_id: String) -> Dictionary:
	return UNIQUE_UNITS.get(unit_id, {})


static func unique_unit_label(unit_id: String) -> String:
	return str(unique_unit_def(unit_id).get("label", unit_id))


static func gather_mult(civ_id: String, resource_type: String) -> float:
	var gather: Dictionary = def_for(civ_id).get("gather", {})
	return float(gather.get(resource_type, 1.0))


static func wood_cost_mult(civ_id: String) -> float:
	return float(def_for(civ_id).get("wood_cost", 1.0))


static func is_infantry(unit_id: String) -> bool:
	return unit_id in INFANTRY_IDS


static func apply_unit_bonuses(unit: Unit, civ_id: String) -> void:
	if unit == null:
		return
	var def := def_for(civ_id)
	var uid := unit.unit_id
	if is_infantry(uid):
		unit.max_hp *= float(def.get("infantry_hp", 1.0))
		unit.attack_damage *= float(def.get("infantry_damage", 1.0))
	if unit.is_cavalry:
		unit.attack_damage *= float(def.get("cavalry_damage", 1.0))


static func format_cost(cost: Dictionary) -> String:
	var parts: PackedStringArray = []
	if int(cost.get("food", 0)) > 0:
		parts.append("%d J" % int(cost["food"]))
	if int(cost.get("wood", 0)) > 0:
		parts.append("%d D" % int(cost["wood"]))
	if int(cost.get("gold", 0)) > 0:
		parts.append("%d Z" % int(cost["gold"]))
	if int(cost.get("stone", 0)) > 0:
		parts.append("%d K" % int(cost["stone"]))
	return ", ".join(parts) if not parts.is_empty() else "—"
