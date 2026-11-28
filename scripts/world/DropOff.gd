extends Node2D
class_name DropOff

signal destroyed(hall: DropOff)
signal queue_changed
signal research_changed

const VILLAGER_SCENE := preload("res://scenes/units/Villager.tscn")
## DESIGN: Vesničan 50 J, 25 s.
const VILLAGER_COST := {"food": 50}
const VILLAGER_TIME := 25.0
const MAX_QUEUE := 5

@export var team: int = 0
@export var dropoff_radius: float = 48.0
@export var building_name: String = "Radnice"
## DESIGN: Radnice HP 2400, +5 populace.
@export var max_hp: float = 2400.0
@export var population_bonus: int = 5
@export var accepted_resources: PackedStringArray = ["food", "wood", "gold", "stone"]

var hp: float
var queue: Array[String] = []
var train_remaining: float = 0.0
var spawn_parent: Node2D
## Age research occupies Radnice; blocks villager training while active.
var researching_age: bool = false
var research_remaining: float = 0.0
var research_target_age: int = 0


func _ready() -> void:
	hp = max_hp
	add_to_group("dropoffs")
	add_to_group("town_halls")
	_anchor_visual()
	if team == 0:
		add_to_group("player_town_hall")
		add_to_group("player_buildings")
		GameManager.add_population_cap(population_bonus)
	else:
		add_to_group("enemy_town_hall")
		add_to_group("enemy_buildings")
		building_name = "Nepřátelská radnice"
	_apply_team_visual()
	if has_node("Label"):
		$Label.text = building_name


func _anchor_visual() -> void:
	var visual := get_node_or_null("Visual") as Sprite2D
	if visual == null or visual.texture == null:
		return
	visual.centered = true
	visual.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Virtual footprint 80×80 — bottom of sprite on footprint bottom.
	visual.offset = Vector2(0.0, 40.0 - float(visual.texture.get_height()) * 0.5)


func _apply_team_visual() -> void:
	var visual := get_node_or_null("Visual") as Sprite2D
	if visual == null:
		return
	TeamColors.apply(visual, team, true)


func accepts(resource_type: String) -> bool:
	return resource_type in accepted_resources


func _process(delta: float) -> void:
	## Age research (player Radnice) + villager queues for any team (AI uses ai_enqueue).
	if researching_age:
		if team != 0:
			return
		research_remaining -= delta
		if research_remaining <= 0.0:
			_complete_age_research()
		return
	if queue.is_empty():
		return
	## Player hall only trains via GameManager path; AI halls via ai_enqueue_villager.
	if team != 0 and not _has_ai_controller():
		return
	train_remaining -= delta
	if train_remaining <= 0.0:
		_complete_training()


func _has_ai_controller() -> bool:
	for n in get_tree().get_nodes_in_group("ai_controllers"):
		if n is SimpleEnemyAI and (n as SimpleEnemyAI).team == team:
			return true
	return false


func enqueue_villager() -> bool:
	if team != 0:
		return false
	if researching_age:
		NotificationManager.show_message("Radnice zkoumá věk — nelze trénovat.")
		return false
	if not GameManager.is_unit_unlocked("villager"):
		NotificationManager.show_message("Vesničan je zamčený věkem.")
		return false
	if queue.size() >= MAX_QUEUE:
		NotificationManager.show_message("Fronta radnice je plná.")
		return false
	if not GameManager.can_add_population(1):
		NotificationManager.show_message("Nedostatek populace (postav Dům).")
		return false
	if not GameManager.spend(VILLAGER_COST):
		NotificationManager.show_message("Nedostatek surovin na vesničana.")
		return false
	GameManager.change_population(1)
	queue.append("villager")
	if queue.size() == 1:
		train_remaining = VILLAGER_TIME
	queue_changed.emit()
	print("[PROD] queued villager (queue=%d)" % queue.size())
	return true


## AI — caller already paid from AI stockpile.
func ai_enqueue_villager() -> bool:
	if researching_age:
		return false
	if queue.size() >= MAX_QUEUE:
		return false
	queue.append("villager")
	if queue.size() == 1:
		train_remaining = 1.2 if DisplayServer.get_name() == "headless" else VILLAGER_TIME
	queue_changed.emit()
	print("[AI-PROD] queued villager team=%d (queue=%d)" % [team, queue.size()])
	return true


func start_age_research(time_override: float = -1.0) -> bool:
	if team != 0:
		return false
	if researching_age:
		NotificationManager.show_message("Výzkum věku už běží.")
		return false
	if GameManager.current_age >= AgeData.MAX_AGE:
		NotificationManager.show_message("Už jsi v posledním věku.")
		return false
	if not queue.is_empty():
		NotificationManager.show_message("Nejdřív vyprázdni frontu radnice.")
		return false
	var have := GameManager.count_age_buildings(GameManager.current_age)
	if have < AgeData.BUILDINGS_REQUIRED_TO_ADVANCE:
		NotificationManager.show_message(
			"Potřebuješ %d budovy z věku %s (máš %d)." % [
				AgeData.BUILDINGS_REQUIRED_TO_ADVANCE,
				GameManager.get_age_name(),
				have,
			]
		)
		return false
	var def := AgeData.research_def_for_next(GameManager.current_age)
	if def.is_empty():
		return false
	var cost: Dictionary = def.get("cost", {})
	if not GameManager.spend(cost):
		NotificationManager.show_message("Nedostatek surovin na výzkum věku.")
		return false
	researching_age = true
	research_target_age = AgeData.next_age(GameManager.current_age)
	research_remaining = time_override if time_override > 0.0 else float(def.get("time", 130.0))
	research_changed.emit()
	queue_changed.emit()
	print("[AGE] research started -> %d (%.1fs)" % [research_target_age, research_remaining])
	NotificationManager.show_message("Výzkum: %s" % AgeData.age_name(research_target_age))
	return true


func get_queue_summary() -> String:
	if researching_age:
		return "věk %.1fs" % maxf(research_remaining, 0.0)
	if queue.is_empty():
		return "fronta prázdná"
	return "fronta %d | %.1fs" % [queue.size(), maxf(train_remaining, 0.0)]


func _complete_age_research() -> void:
	researching_age = false
	research_remaining = 0.0
	var target := research_target_age
	research_target_age = 0
	research_changed.emit()
	queue_changed.emit()
	if GameManager.current_age < target:
		GameManager.advance_age()
		AudioManager.play_sfx("age_advance")
	NotificationManager.show_message("Nový věk: %s" % GameManager.get_age_name())


func _complete_training() -> void:
	if queue.is_empty():
		return
	queue.pop_front()
	var villager: Villager = VILLAGER_SCENE.instantiate() as Villager
	villager.contribute_population = false
	villager.team = team
	var parent := spawn_parent if spawn_parent else get_parent()
	villager.position = global_position + Vector2(0, 56.0)
	parent.add_child(villager)
	# Ensure selectable after spawn (team groups from Unit._ready).
	if villager.team == 0 and not villager.is_in_group("player_units"):
		villager.add_to_group("player_units")
	_apply_rally(villager)
	print("[PROD] spawned villager at %s groups_ok=%s" % [str(villager.position), villager.is_in_group("player_units")])
	NotificationManager.show_message("Vycvičen vesničan.")
	queue_changed.emit()
	if not queue.is_empty():
		train_remaining = VILLAGER_TIME


func _apply_rally(unit: Node) -> void:
	var rally := get_node_or_null("RallyPoint")
	if rally != null and rally.has_method("apply_to_unit"):
		rally.call("apply_to_unit", unit)


func _hp_fill_color() -> Color:
	return Color(0.2, 0.85, 0.25, 0.95) if team == 0 else Color(0.9, 0.2, 0.15, 0.95)


func _draw() -> void:
	var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
	var bar_y := -58.0
	var visual := get_node_or_null("Visual") as Sprite2D
	if visual and visual.texture:
		bar_y = visual.offset.y - float(visual.texture.get_height()) * 0.5 - 8.0
	draw_rect(Rect2(Vector2(-40.0, bar_y), Vector2(80.0, 5.0)), Color(0.1, 0.1, 0.1, 0.8))
	draw_rect(Rect2(Vector2(-40.0, bar_y), Vector2(80.0 * ratio, 5.0)), _hp_fill_color())


func take_damage(amount: float, _dmg_type: String = "melee") -> void:
	hp -= amount
	queue_redraw()
	if team == 0:
		AudioManager.play_under_attack()
	if hp <= 0.0:
		die()


func die() -> void:
	destroyed.emit(self)
	AudioManager.play_sfx("building_destroyed")
	print("[COMBAT] radnice destroyed team=%d" % team)
	queue_free()
