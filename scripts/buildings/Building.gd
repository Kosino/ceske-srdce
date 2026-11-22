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


func _refresh_label() -> void:
	if has_node("Label"):
		if is_complete:
			$Label.text = display_name
		else:
			$Label.text = "%s %d%%" % [display_name, int(build_progress * 100.0)]


func _draw() -> void:
	var bar_w := footprint.x * 0.8
	var origin := Vector2(-bar_w * 0.5, -footprint.y * 0.5 - 10.0)
	draw_rect(Rect2(origin, Vector2(bar_w, 4.0)), Color(0.1, 0.1, 0.1, 0.8))
	if is_complete:
		var ratio := clampf(hp / maxf(max_hp, 1.0), 0.0, 1.0)
		draw_rect(Rect2(origin, Vector2(bar_w * ratio, 4.0)), Color(0.85, 0.25, 0.2, 0.95))
	else:
		draw_rect(Rect2(origin, Vector2(bar_w * build_progress, 4.0)), Color(0.95, 0.85, 0.2, 0.95))


func take_damage(amount: float) -> void:
	hp -= amount
	queue_redraw()
	if hp <= 0.0:
		die()


func die() -> void:
	destroyed.emit(self)
	print("[COMBAT] building destroyed team=%d id=%s" % [team, building_id])
	queue_free()