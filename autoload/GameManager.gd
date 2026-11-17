extends Node

signal resources_changed
signal population_changed
signal age_changed

const POPULATION_HARD_CAP := 200

var food: int = 200
var wood: int = 200
var gold: int = 100
var stone: int = 0
var population: int = 0
## Starts at 0; Radnice/Dům přidávají +5 (strop 200).
var population_max: int = 0
var current_age: int = 1


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


func advance_age() -> void:
	if current_age >= 4:
		return
	current_age += 1
	age_changed.emit()
