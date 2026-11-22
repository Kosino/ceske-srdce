extends Object
class_name CivData
## Civilization ids + NÁVRH bonuses. Unique units are data-only for now.

const MORAVANE := "moravane"
const PREMYSLOVCI := "premyslovci"
const HUSITE := "husite"
const HABSBURKOVE := "habsurkove"

const DEFAULT_PLAYER := MORAVANE
const DEFAULT_ENEMY := HUSITE

const INFANTRY_IDS := ["soldier", "spearman", "archer"]

## NÁVRH — Honza schvaluje čísla. Keys match DESIGN “hlavní síla”.
const CIVS := {
	MORAVANE: {
		"name": "Moravané",
		"unique_unit": "velmoz",
		"gather": {"wood": 1.15},
		"wood_cost": 0.90,
	},
	PREMYSLOVCI: {
		"name": "Přemyslovci",
		"unique_unit": "svatovaclavsky_rytir",
		"gather": {"gold": 1.15},
		"cavalry_damage": 1.10,
	},
	HUSITE: {
		"name": "Husité",
		"unique_unit": "husitsky_vuz",
		"infantry_hp": 1.10,
		"infantry_damage": 1.05,
	},
	HABSBURKOVE: {
		"name": "Habsburkové",
		"unique_unit": "cisarska_garda",
		"infantry_hp": 1.15,
	},
}


static func civ_name(civ_id: String) -> String:
	var def: Dictionary = CIVS.get(civ_id, {})
	return str(def.get("name", civ_id))


static func def_for(civ_id: String) -> Dictionary:
	return CIVS.get(civ_id, CIVS[DEFAULT_PLAYER])


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
