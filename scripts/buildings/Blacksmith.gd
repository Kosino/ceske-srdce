extends Building
class_name Blacksmith
## Kovárna — research queue size 1. Techs once per team.

signal research_changed

## Schváleno: 150 D, 40 s, HP 1800, 80×80.

var researching_tech: String = ""
var research_remaining: float = 0.0


func _ready() -> void:
	building_id = "blacksmith"
	display_name = "Kovárna"
	footprint = Vector2(80, 80)
	max_hp = 1800.0
	build_time = 40.0
	super._ready()
	add_to_group("blacksmiths")
	set_process(true)


func _process(delta: float) -> void:
	if researching_tech == "":
		return
	research_remaining -= delta
	if research_remaining <= 0.0:
		_complete_research()
	else:
		research_changed.emit()


func is_researching() -> bool:
	return researching_tech != ""


func research_progress_line() -> String:
	if researching_tech == "":
		return ""
	return "%s — %.0fs" % [TechData.tech_name(researching_tech), maxf(research_remaining, 0.0)]


func can_enqueue(tech_id: String) -> bool:
	if not is_complete:
		return false
	if tech_id not in TechData.BLACKSMITH_TECHS:
		return false
	if GameManager.has_tech(team, tech_id):
		return false
	if researching_tech != "":
		return false
	var cost: Dictionary = TechData.tech_def(tech_id).get("cost", {})
	if team == 0:
		return GameManager.can_afford(cost)
	return _ai_can_afford(cost)


func enqueue_tech(tech_id: String) -> bool:
	if GameManager.has_tech(team, tech_id):
		NotificationManager.show_message("Už vyzkoumáno: %s" % TechData.tech_name(tech_id))
		return false
	if researching_tech != "":
		NotificationManager.show_message("Kovárna už zkoumá.")
		return false
	if not can_enqueue(tech_id):
		NotificationManager.show_message("Nedostatek surovin.")
		return false
	var def := TechData.tech_def(tech_id)
	var cost: Dictionary = def.get("cost", {})
	if team == 0:
		if not GameManager.spend(cost):
			return false
	else:
		if not _ai_spend(cost):
			return false
	researching_tech = tech_id
	research_remaining = float(def.get("time", 40.0))
	if DisplayServer.get_name() == "headless":
		research_remaining = minf(research_remaining, 0.35)
	research_changed.emit()
	NotificationManager.show_message("Výzkum: %s" % TechData.tech_name(tech_id))
	print("[TECH] started %s team=%d" % [tech_id, team])
	return true


func _complete_research() -> void:
	var done := researching_tech
	researching_tech = ""
	research_remaining = 0.0
	if done != "":
		GameManager.mark_tech_researched(team, done)
		NotificationManager.show_message("Hotovo: %s" % TechData.tech_name(done))
	research_changed.emit()


func _ai_can_afford(cost: Dictionary) -> bool:
	var ai := get_tree().get_first_node_in_group("enemy_ai") as SimpleEnemyAI
	if ai == null:
		return false
	return (
		ai.food >= int(cost.get("food", 0))
		and ai.wood >= int(cost.get("wood", 0))
		and ai.gold >= int(cost.get("gold", 0))
	)


func _ai_spend(cost: Dictionary) -> bool:
	var ai := get_tree().get_first_node_in_group("enemy_ai") as SimpleEnemyAI
	if ai == null or not _ai_can_afford(cost):
		return false
	ai.food -= int(cost.get("food", 0))
	ai.wood -= int(cost.get("wood", 0))
	ai.gold -= int(cost.get("gold", 0))
	return true
