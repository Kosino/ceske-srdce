extends Node2D
class_name Building

signal destroyed(building: Building)
signal construction_finished(building: Building)

const CONSTRUCTION_TEX := preload("res://assets/sprites/buildings/construction_site.png")

@export var team: int = 0
@export var building_id: String = ""
@export var display_name: String = "Budova"
@export var max_hp: float = 500.0
@export var footprint: Vector2 = Vector2(72, 72)
## DESIGN base build time for 1 villager (seconds).
@export var build_time: float = 25.0

var hp: float
var is_complete: bool = true
var build_progress: float = 1.0
var _builders: Dictionary = {} # instance_id -> Villager
var _final_texture: Texture2D
var _visual: Sprite2D
## Cost paid to place (for repair = 25% of this over full HP).
var placed_cost: Dictionary = {}
var _repairers: Dictionary = {} # instance_id -> Villager
## UI focus — fortifications hide name/HP unless selected/hovered/damaged.
var ui_selected: bool = false
var ui_hovered: bool = false
## Zednictví (+10% HP) applied once per building.
var masonry_applied: bool = false


func _ready() -> void:
	_visual = get_node_or_null("Visual") as Sprite2D
	if _visual and _visual.texture:
		_final_texture = _visual.texture
	if is_complete:
		hp = max_hp
		build_progress = 1.0
		_show_final_visual()
	else:
		hp = maxf(max_hp * 0.1, 1.0)
		build_progress = 0.0
		_show_construction_visual()
	add_to_group("buildings")
	if team == 0:
		add_to_group("player_buildings")
	else:
		add_to_group("enemy_buildings")
	_refresh_label()
	GameManager.apply_researched_techs_to_building(self)


## University Zednictví: multiply max HP (and current HP) once.
func apply_masonry_bonus(mult: float) -> void:
	if masonry_applied or mult <= 1.0:
		return
	masonry_applied = true
	var ratio := 1.0
	if max_hp > 0.0:
		ratio = hp / max_hp
	max_hp = max_hp * mult
	hp = max_hp * ratio
	queue_redraw()


func start_construction(time_sec: float = -1.0) -> void:
	if time_sec > 0.0:
		build_time = time_sec
	is_complete = false
	build_progress = 0.0
	hp = maxf(max_hp * 0.1, 1.0)
	_show_construction_visual()
	_builders.clear()
	if is_in_group("dropoffs"):
		remove_from_group("dropoffs")
	_refresh_label()
	queue_redraw()


func is_under_construction() -> bool:
	return not is_complete


func register_builder(villager: Node) -> void:
	if is_complete or villager == null:
		return
	_builders[villager.get_instance_id()] = villager


func unregister_builder(villager: Node) -> void:
	if villager == null:
		return
	_builders.erase(villager.get_instance_id())


func builder_count() -> int:
	_prune_builders()
	return _builders.size()


func _process(delta: float) -> void:
	if is_complete:
		return
	var n := builder_count()
	if n <= 0:
		return
	# AoE2-like: time with n villagers = 3t/(n+2) → rate = (n+2)/(3t)
	var rate := float(n + 2) / (3.0 * maxf(build_time, 0.01))
	build_progress = minf(1.0, build_progress + rate * delta)
	hp = max_hp * lerpf(0.1, 1.0, build_progress)
	_refresh_label()
	queue_redraw()
	if build_progress >= 1.0:
		_finish_construction()


func _finish_construction() -> void:
	is_complete = true
	build_progress = 1.0
	hp = max_hp
	_show_final_visual()
	for id in _builders.keys():
		var v = _builders[id]
		if is_instance_valid(v) and v.has_method("notify_build_finished"):
			v.notify_build_finished(self)
	_builders.clear()
	_refresh_label()
	queue_redraw()
	_on_construction_finished()
	construction_finished.emit(self)
	print("[BUILD] completed %s" % display_name)
	NotificationManager.show_message("Dokončeno: %s" % display_name)


## Override in subclasses for pop/drop-off/unlock.
func _on_construction_finished() -> void:
	pass


func _show_construction_visual() -> void:
	modulate = Color(1, 1, 1, 1)
	if _visual == null:
		return
	_visual.texture = CONSTRUCTION_TEX
	_anchor_sprite(_visual, CONSTRUCTION_TEX)


func _show_final_visual() -> void:
	modulate = Color(1, 1, 1, 1)
	if _visual == null:
		return
	if _final_texture:
		_visual.texture = _final_texture
	_anchor_sprite(_visual, _visual.texture)


func _anchor_sprite(sprite: Sprite2D, tex: Texture2D) -> void:
	if sprite == null or tex == null:
		return
	sprite.centered = true
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.offset = Vector2(0.0, footprint.y * 0.5 - float(tex.get_height()) * 0.5)


func _prune_builders() -> void:
	var dead: Array = []
	for id in _builders.keys():
		var v = _builders[id]
		if not is_instance_valid(v):
			dead.append(id)
	for id in dead:
		_builders.erase(id)


## Override on fortifications (walls/gates): only when selected/hovered.
func should_show_name_label() -> bool:
	return true


## Override on fortifications: only when damaged, selected, hovered, or building.
func should_show_hp_bar() -> bool:
	return true


func set_ui_selected(value: bool) -> void:
	if ui_selected == value:
		return
	ui_selected = value
	_refresh_label()
	queue_redraw()


func set_ui_hovered(value: bool) -> void:
	if ui_hovered == value:
		return
	ui_hovered = value
	_refresh_label()
	queue_redraw()


func _refresh_label() -> void:
	if not has_node("Label"):
		return
	var lab := $Label as Label
	if not should_show_name_label():
		lab.visible = false
		return
	lab.visible = true
	if is_complete:
		lab.text = display_name
	else:
		lab.text = "%s %d%%" % [display_name, int(build_progress * 100.0)]


func _hp_fill_color() -> Color:
	return Color(0.2, 0.85, 0.25, 0.95) if team == 0 else Color(0.9, 0.2, 0.15, 0.95)


func _draw() -> void:
	if not should_show_hp_bar():
		return
	var bar_w := footprint.x * 0.8
	var origin := Vector2(-bar_w * 0.5, -footprint.y * 0.5 - 10.0)
	draw_rect(Rect2(origin, Vector2(bar_w, 4.0)), Color(0.1, 0.1, 0.1, 0.8))
	if is_complete:
		var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
		draw_rect(Rect2(origin, Vector2(bar_w * ratio, 4.0)), _hp_fill_color())
	else:
		draw_rect(Rect2(origin, Vector2(bar_w * build_progress, 4.0)), Color(0.95, 0.85, 0.2, 0.95))


func take_damage(amount: float, _dmg_type: String = "melee") -> void:
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		die()


func needs_repair() -> bool:
	return is_complete and hp < max_hp - 0.5


func repair_cost_dict() -> Dictionary:
	## Full-repair cost = 25% of build cost.
	var base: Dictionary = placed_cost
	if base.is_empty() and building_id in BuildingPlacer.COSTS:
		base = BuildingPlacer.COSTS[building_id]
	var out: Dictionary = {}
	for k in base.keys():
		out[k] = maxi(0, int(ceil(float(base[k]) * 0.25)))
	return out


func register_repairer(villager: Node) -> void:
	if villager == null or not needs_repair():
		return
	_repairers[villager.get_instance_id()] = villager


func unregister_repairer(villager: Node) -> void:
	if villager == null:
		return
	_repairers.erase(villager.get_instance_id())


## Restore up to `amount` HP, spending proportional resources from team 0 stockpile.
## Returns HP actually restored.
func apply_repair(amount: float) -> float:
	if not needs_repair() or amount <= 0.0:
		return 0.0
	var room := max_hp - hp
	var want := minf(amount, room)
	var full_cost := repair_cost_dict()
	# Per-HP fractional cost; spend ceil of each tick's share for team 0.
	var spent: Dictionary = {}
	for k in full_cost.keys():
		var share := float(full_cost[k]) * (want / maxf(max_hp, 1.0))
		var pay := int(ceil(share)) if share > 0.001 else 0
		if pay > 0:
			spent[k] = pay
	if team == 0 and not spent.is_empty():
		if not GameManager.can_afford(spent):
			# Try 1 HP with minimal spend.
			spent.clear()
			for k in full_cost.keys():
				if int(full_cost[k]) > 0:
					spent[k] = 1
					break
			if spent.is_empty() or not GameManager.can_afford(spent):
				return 0.0
		GameManager.spend(spent)
	hp = minf(max_hp, hp + want)
	queue_redraw()
	return want


func die() -> void:
	destroyed.emit(self)
	print("[COMBAT] building destroyed team=%d id=%s" % [team, building_id])
	queue_free()