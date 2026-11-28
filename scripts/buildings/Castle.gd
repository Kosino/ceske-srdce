extends Building
class_name Castle
## DESIGN: Hrad 650 K, 120 s, HP 4800, 160×160, věk 3. Šípy 8 pierce / 8 dlaždic. +10 pop. Unikátní jednotka.

signal queue_changed
signal unit_spawned(unit: Node2D)

const PROJECTILE_SCENE := preload("res://scenes/combat/Projectile.tscn")
const MAX_QUEUE := 5
const TRAIN_TIME := 35.0
const POP_BONUS := 10
const ATTACK_DAMAGE := 8.0
const ATTACK_RANGE := 8.0 * 40.0
const ATTACK_COOLDOWN := 1.1

const UNIT_SCENES := {
	"bojovnik_bradatice": preload("res://scenes/units/BojovnikBradatice.tscn"),
	"druzinik": preload("res://scenes/units/Druzinik.tscn"),
	"valecny_vuz": preload("res://scenes/units/ValecnyVuz.tscn"),
	"lancknecht": preload("res://scenes/units/Lancknecht.tscn"),
}

var queue: Array[String] = []
var train_remaining: float = 0.0
var spawn_parent: Node2D
var _attack_timer: float = 0.0
var _pop_granted: bool = false


func _ready() -> void:
	building_id = "castle"
	display_name = "Hrad"
	footprint = Vector2(160, 160)
	max_hp = 4800.0
	build_time = 120.0
	super._ready()
	add_to_group("castles")
	if is_complete and team == 0 and not _pop_granted:
		GameManager.add_population_cap(POP_BONUS)
		_pop_granted = true
	if is_complete:
		GarrisonController.ensure(self)


func _on_construction_finished() -> void:
	if team == 0 and not _pop_granted:
		GameManager.add_population_cap(POP_BONUS)
		_pop_granted = true
	GarrisonController.ensure(self)


func _process(delta: float) -> void:
	super._process(delta)
	if not is_complete:
		return
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_try_auto_attack()
	if queue.is_empty():
		return
	train_remaining -= delta
	if train_remaining <= 0.0:
		_complete_training()


func unique_unit_id() -> String:
	return CivData.unique_unit_id(GameManager.civ_for_team(team))


func unique_def() -> Dictionary:
	return CivData.unique_unit_def(unique_unit_id())


func enqueue_unique() -> bool:
	return enqueue_unit(unique_unit_id())


func enqueue_unit(unit_id: String) -> bool:
	if not is_complete:
		NotificationManager.show_message("Hrad ještě není dokončený.")
		return false
	var allowed := unique_unit_id()
	if unit_id != allowed:
		NotificationManager.show_message("Tato civilizace trénuje jen: %s." % CivData.unique_unit_label(allowed))
		return false
	if not GameManager.is_unit_unlocked(unit_id):
		NotificationManager.show_message(
			"Zamčeno do věku %s." % AgeData.age_name(AgeData.unit_unlock_age(unit_id))
		)
		return false
	if queue.size() >= MAX_QUEUE:
		NotificationManager.show_message("Fronta hradu je plná.")
		return false
	if not GameManager.can_add_population(1):
		NotificationManager.show_message("Nedostatek populace (postav Dům).")
		return false
	var def := CivData.unique_unit_def(unit_id)
	if def.is_empty():
		return false
	if not GameManager.spend(def["cost"]):
		NotificationManager.show_message("Nedostatek surovin na %s." % def.get("label", unit_id))
		return false
	GameManager.change_population(1)
	queue.append(unit_id)
	if queue.size() == 1:
		train_remaining = float(def.get("time", TRAIN_TIME))
		if DisplayServer.get_name() == "headless":
			train_remaining = minf(train_remaining, 1.2)
	queue_changed.emit()
	print("[PROD] castle queued %s (queue=%d)" % [unit_id, queue.size()])
	return true


## AI — caller paid from AI stockpile.
func ai_enqueue_unit(unit_id: String) -> bool:
	if not is_complete:
		return false
	if unit_id != unique_unit_id():
		return false
	if queue.size() >= MAX_QUEUE:
		return false
	var def := CivData.unique_unit_def(unit_id)
	if def.is_empty():
		return false
	var t := 1.2 if DisplayServer.get_name() == "headless" else float(def.get("time", TRAIN_TIME))
	queue.append(unit_id)
	if queue.size() == 1:
		train_remaining = t
	queue_changed.emit()
	print("[AI-PROD] castle queued %s" % unit_id)
	return true


func get_queue_summary() -> String:
	var base := "fronta prázdná" if queue.is_empty() else "fronta %d | %.1fs" % [queue.size(), maxf(train_remaining, 0.0)]
	var g := GarrisonController.of(self)
	if g:
		return "%s · %s" % [base, g.summary_line()]
	return base


func _complete_training() -> void:
	if queue.is_empty():
		return
	var unit_id: String = queue.pop_front()
	var unit := _instantiate_unit(unit_id)
	if unit == null:
		queue_changed.emit()
		return
	if unit is Unit:
		(unit as Unit).contribute_population = false
		(unit as Unit).team = team
	var parent := spawn_parent if spawn_parent else get_parent()
	unit.position = global_position + Vector2(0, footprint.y * 0.5 + 28.0)
	parent.add_child(unit)
	_apply_rally(unit)
	unit_spawned.emit(unit)
	var label := CivData.unique_unit_label(unit_id)
	print("[PROD] spawned %s at %s" % [unit_id, str(unit.position)])
	NotificationManager.show_message("Vycvičen %s." % label)
	queue_changed.emit()
	if not queue.is_empty():
		var next_id: String = queue[0]
		var def := CivData.unique_unit_def(next_id)
		if team != 0 and DisplayServer.get_name() == "headless":
			train_remaining = 1.2
		else:
			train_remaining = float(def.get("time", TRAIN_TIME))


func _apply_rally(unit: Node) -> void:
	var rally := get_node_or_null("RallyPoint")
	if rally != null and rally.has_method("apply_to_unit"):
		rally.call("apply_to_unit", unit)


func _instantiate_unit(unit_id: String) -> Node2D:
	if unit_id not in UNIT_SCENES:
		return null
	return UNIT_SCENES[unit_id].instantiate()


func _try_auto_attack() -> void:
	if _attack_timer > 0.0:
		return
	var target := _nearest_enemy()
	if target == null:
		return
	_attack_timer = ATTACK_COOLDOWN
	var garr := GarrisonController.of(self)
	var arrows := garr.total_arrows(1) if garr else 1
	var parent := spawn_parent if spawn_parent else get_parent()
	if parent == null:
		parent = get_tree().current_scene
	var origin := global_position + Vector2(0, -footprint.y * 0.25)
	for i in arrows:
		var proj: Projectile = PROJECTILE_SCENE.instantiate() as Projectile
		parent.add_child(proj)
		var aim := target.global_position + Vector2(float(i) * 3.0 - float(arrows) * 1.5, 0.0)
		proj.setup(origin, aim, ATTACK_DAMAGE, team, target)
	print("[COMBAT] castle loosed %d arrow(s) at %s" % [arrows, target.name])


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
	for g in groups:
		for n in tree.get_nodes_in_group(g):
			if not (n is Node2D) or not is_instance_valid(n):
				continue
			if n is Unit and (n as Unit).is_garrisoned:
				continue
			var d := global_position.distance_to((n as Node2D).global_position)
			if d <= best_d:
				best_d = d
				best = n as Node2D
	return best
