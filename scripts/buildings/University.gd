extends Building
class_name University
## Univerzita — NÁVRH: 200 D, 60 s, 2100 HP, 80×80, věk 4. Research queue size 1.

signal research_changed

var researching_tech: String = ""
var research_remaining: float = 0.0


func _ready() -> void:
	building_id = "university"
	display_name = "Univerzita"
	footprint = Vector2(80, 80)
	max_hp = 2100.0
	build_time = 60.0
	super._ready()
	add_to_group("universities")
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
	if not TechData.is_university_tech(tech_id):
		return false
	if GameManager.has_tech(team, tech_id):
		return false
	if researching_tech != "":
		return false
	var cost: Dictionary = TechData.tech_def(tech_id).get("cost", {})
	if _ai_for_team() != null:
		return _ai_can_afford(cost)
	if team == 0:
		return GameManager.can_afford(cost)
	return _ai_can_afford(cost)


func enqueue_tech(tech_id: String) -> bool:
	if GameManager.has_tech(team, tech_id):
		NotificationManager.show_message("Už vyzkoumáno: %s" % TechData.tech_name(tech_id))
		return false
	if researching_tech != "":
		NotificationManager.show_message("Univerzita už zkoumá.")
		return false
	if not can_enqueue(tech_id):
		NotificationManager.show_message("Nedostatek surovin.")
		return false
	var def := TechData.tech_def(tech_id)
	var cost: Dictionary = def.get("cost", {})
	if _ai_for_team() != null:
		if not _ai_spend(cost):
			return false
	elif team == 0:
		if not GameManager.spend(cost):
			return false
	else:
		if not _ai_spend(cost):
			return false
	researching_tech = tech_id
	research_remaining = float(def.get("time", 50.0))
	if DisplayServer.get_name() == "headless":
		research_remaining = minf(research_remaining, 0.35)
	research_changed.emit()
	NotificationManager.show_message("Výzkum: %s" % TechData.tech_name(tech_id))
	print("[TECH] university started %s team=%d" % [tech_id, team])
	return true


func _complete_research() -> void:
	var done := researching_tech
	researching_tech = ""
	research_remaining = 0.0
	if done != "":
		GameManager.mark_tech_researched(team, done)
		NotificationManager.show_message("Hotovo: %s" % TechData.tech_name(done))
	research_changed.emit()


func _ai_for_team() -> SimpleEnemyAI:
	for n in get_tree().get_nodes_in_group("ai_controllers"):
		if n is SimpleEnemyAI and (n as SimpleEnemyAI).team == team:
			return n as SimpleEnemyAI
	return null


func _ai_can_afford(cost: Dictionary) -> bool:
	var ai := _ai_for_team()
	if ai == null:
		return false
	return (
		ai.food >= int(cost.get("food", 0))
		and ai.wood >= int(cost.get("wood", 0))
		and ai.gold >= int(cost.get("gold", 0))
		and ai.stone >= int(cost.get("stone", 0))
	)


func _ai_spend(cost: Dictionary) -> bool:
	var ai := _ai_for_team()
	if ai == null or not _ai_can_afford(cost):
		return false
	ai.food -= int(cost.get("food", 0))
	ai.wood -= int(cost.get("wood", 0))
	ai.gold -= int(cost.get("gold", 0))
	ai.stone -= int(cost.get("stone", 0))
	return true
