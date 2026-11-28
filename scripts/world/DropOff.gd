extends Node2D
class_name DropOff

signal destroyed(hall: DropOff)
signal queue_changed
signal research_changed
signal bell_changed(active: bool)

const VILLAGER_SCENE := preload("res://scenes/units/Villager.tscn")
const PROJECTILE_SCENE := preload("res://scenes/combat/Projectile.tscn")
## DESIGN: Vesničan 50 J, 25 s.
const VILLAGER_COST := {"food": 50}
const VILLAGER_TIME := 25.0
const MAX_QUEUE := 5
## T-35: TC arrows from garrisoned villagers/archers only (base 0).
const ATTACK_DAMAGE := 5.0
const ATTACK_RANGE := 7.0 * 40.0
const ATTACK_COOLDOWN := 1.0
const BELL_RADIUS := 25.0 * 40.0

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
var _attack_timer: float = 0.0
## Town Bell: villagers run to nearest garrison; second press restores work.
var bell_active: bool = false
var _bell_snapshots: Dictionary = {} # instance_id -> Dictionary


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
	GarrisonController.ensure(self)


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
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_try_auto_attack()
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


func garrison() -> GarrisonController:
	return GarrisonController.of(self)


func garrison_summary() -> String:
	var g := garrison()
	return g.summary_line() if g else ""


func toggle_town_bell() -> void:
	if team != 0:
		return
	if bell_active:
		_bell_return_to_work()
	else:
		_bell_call_villagers()


func _bell_call_villagers() -> void:
	_bell_snapshots.clear()
	var tree := get_tree()
	if tree == null:
		return
	var called := 0
	for n in tree.get_nodes_in_group("villagers"):
		if not (n is Villager):
			continue
		var v := n as Villager
		if v.team != team or v.is_garrisoned:
			continue
		if global_position.distance_to(v.global_position) > BELL_RADIUS:
			continue
		_bell_snapshots[v.get_instance_id()] = v.capture_work_snapshot()
		var host := _nearest_garrison_host_for(v)
		if host == null:
			continue
		v.command_garrison(host)
		called += 1
	bell_active = true
	bell_changed.emit(true)
	NotificationManager.show_message("Zvonek: vesničané se ukrývají (%d)." % called)
	print("[BELL] call villagers=%d" % called)


func _bell_return_to_work() -> void:
	var tree := get_tree()
	var restored := 0
	# Eject garrisoned villagers that we called, then restore work.
	for host_n in tree.get_nodes_in_group("garrison_hosts"):
		if "team" in host_n and int(host_n.get("team")) != team:
			continue
		var g := GarrisonController.of(host_n)
		if g == null:
			continue
		var inside := g.garrisoned.duplicate()
		for u in inside:
			if u is Villager and _bell_snapshots.has(u.get_instance_id()):
				g.eject_unit(u as Unit, false)
	for id in _bell_snapshots.keys():
		var snap: Dictionary = _bell_snapshots[id]
		var found: Villager = null
		for n in tree.get_nodes_in_group("villagers"):
			if n is Villager and n.get_instance_id() == int(id):
				found = n as Villager
				break
		if found == null or not is_instance_valid(found) or found.is_garrisoned:
			continue
		found.restore_work_snapshot(snap)
		restored += 1
	_bell_snapshots.clear()
	bell_active = false
	bell_changed.emit(false)
	NotificationManager.show_message("Zvonek: zpět k práci (%d)." % restored)
	print("[BELL] return villagers=%d" % restored)


func _nearest_garrison_host_for(unit: Unit) -> Node:
	var best: Node = null
	var best_d := INF
	var tree := get_tree()
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("garrison_hosts"):
		if not is_instance_valid(n):
			continue
		if "team" in n and int(n.get("team")) != unit.team:
			continue
		if not GarrisonController.can_host(n):
			continue
		var g := GarrisonController.ensure(n)
		if g == null or g.is_full():
			continue
		if not (n is Node2D):
			continue
		var d := unit.global_position.distance_to((n as Node2D).global_position)
		if d < best_d:
			best_d = d
			best = n
	return best


func _try_auto_attack() -> void:
	if _attack_timer > 0.0:
		return
	var g := garrison()
	var arrows := g.total_arrows(0) if g else 0
	if arrows <= 0:
		return
	var target := _nearest_enemy()
	if target == null:
		return
	_attack_timer = ATTACK_COOLDOWN
	_loose_arrows(target, arrows)


func _loose_arrows(target: Node2D, count: int) -> void:
	var parent := spawn_parent if spawn_parent else get_parent()
	if parent == null:
		parent = get_tree().current_scene
	var origin := global_position + Vector2(0, -36.0)
	for i in count:
		var proj: Projectile = PROJECTILE_SCENE.instantiate() as Projectile
		parent.add_child(proj)
		var aim := target.global_position + Vector2(float(i) * 3.0 - float(count) * 1.5, float(i % 3) * 2.0)
		proj.setup(origin, aim, ATTACK_DAMAGE, team, target)
	print("[COMBAT] radnice loosed %d arrow(s) at %s" % [count, target.name])


func _nearest_enemy() -> Node2D:
	var best: Node2D = null
	var best_d := ATTACK_RANGE
	var groups: Array
	if team == 0:
		groups = ["enemy_units", "enemy_buildings", "enemy_town_hall"]
	else:
		groups = ["player_units", "player_buildings", "player_town_hall"]
	var tree := get_tree()
	if tree == null:
		return null
	for grp in groups:
		for n in tree.get_nodes_in_group(grp):
			if not (n is Node2D) or not is_instance_valid(n):
				continue
			if n is Unit and (n as Unit).is_garrisoned:
				continue
			var d := global_position.distance_to((n as Node2D).global_position)
			if d <= best_d:
				best_d = d
				best = n as Node2D
	return best


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
	var gar := garrison_summary()
	var base := ""
	if researching_age:
		base = "věk %.1fs" % maxf(research_remaining, 0.0)
	elif queue.is_empty():
		base = "fronta prázdná"
	else:
		base = "fronta %d | %.1fs" % [queue.size(), maxf(train_remaining, 0.0)]
	if gar != "":
		return "%s · %s" % [base, gar]
	return base


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
	var g := garrison()
	if g:
		g.on_host_destroyed()
	destroyed.emit(self)
	AudioManager.play_sfx("building_destroyed")
	print("[COMBAT] radnice destroyed team=%d" % team)
	queue_free()
