extends Node

signal resources_changed
signal population_changed
signal age_changed

var food: int = 200
var wood: int = 200
var gold: int = 100
var stone: int = 0
var population: int = 3
var population_max: int = 15
var current_age: int = 1

func add_resource(type: String, amount: int) -> void:
	match type:
		"food": food += amount
		"wood": wood += amount
		"gold": gold += amount
		"stone": stone += amount
	resources_changed.emit()

func can_afford(cost: Dictionary) -> bool:
	return food >= cost.get("food", 0) and wood >= cost.get("wood", 0) and gold >= cost.get("gold", 0) and stone >= cost.get("stone", 0)

func spend(cost: Dictionary) -> void:
	if not can_afford(cost): return
	food -= cost.get("food", 0)
	wood -= cost.get("wood", 0)
	gold -= cost.get("gold", 0)
	stone -= cost.get("stone", 0)
	resources_changed.emit()

func change_population(delta: int) -> void:
	population = clampi(population + delta, 0, population_max)
	population_changed.emit()


func set_age(age: int) -> void:
	var next := clampi(age, 1, 4)
	if next == current_age:
		return
	current_age = next
	age_changed.emit()


func advance_age() -> bool:
	if current_age >= 4:
		return false
	set_age(current_age + 1)
	return true
