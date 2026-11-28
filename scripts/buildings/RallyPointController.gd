extends Node2D
class_name RallyPointController
## Rally flag for training buildings / Radnice. Newly trained units walk here;
## if rally is on a resource (or farm), villagers start gathering.


const FLAG_TEX: Texture2D = preload("res://assets/sprites/fx/rally_flag.png")

var has_rally: bool = false
var rally_world: Vector2 = Vector2.ZERO
var rally_target: Node2D = null
var _flag: Sprite2D


static func ensure(host: Node) -> RallyPointController:
	if host == null:
		return null
	var existing := host.get_node_or_null("RallyPoint") as RallyPointController
	if existing:
		return existing
	var r := RallyPointController.new()
	r.name = "RallyPoint"
	r.visible = false
	r.z_index = 50
	host.add_child(r)
	return r


static func of(host: Node) -> RallyPointController:
	if host == null:
		return null
	return host.get_node_or_null("RallyPoint") as RallyPointController


static func can_host(node: Node) -> bool:
	## Duck-type training buildings — avoid `is Barracks` etc. (circular class load
	## with training scripts that call RallyPointController.of / _apply_rally).
	if node == null or not is_instance_valid(node):
		return false
	if node is DropOff:
		return true
	return node.has_signal("unit_spawned") and node.has_method("get_queue_summary")


func _ready() -> void:
	_ensure_flag_sprite()


func _ensure_flag_sprite() -> void:
	if _flag != null and is_instance_valid(_flag):
		return
	_flag = get_node_or_null("Flag") as Sprite2D
	if _flag == null:
		_flag = Sprite2D.new()
		_flag.name = "Flag"
		add_child(_flag)
	_flag.texture = FLAG_TEX
	_flag.centered = true
	_flag.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Feet / stake base at rally world position.
	var h := float(FLAG_TEX.get_height()) if FLAG_TEX else 28.0
	_flag.offset = Vector2(0.0, -h * 0.5)


func has_flag_sprite() -> bool:
	_ensure_flag_sprite()
	return _flag != null and _flag.texture != null and _flag.texture == FLAG_TEX


func set_rally(world_pos: Vector2, target: Node2D = null) -> void:
	has_rally = true
	rally_world = world_pos
	if target != null and is_instance_valid(target):
		rally_target = target
	else:
		rally_target = null
	top_level = true
	global_position = world_pos
	_ensure_flag_sprite()
	visible = true


func clear_rally() -> void:
	has_rally = false
	rally_target = null
	visible = false


func apply_to_unit(unit: Node) -> void:
	if not has_rally or unit == null or not is_instance_valid(unit):
		return
	if rally_target != null and is_instance_valid(rally_target):
		if unit is Villager:
			(unit as Villager).assign_gather(rally_target)
			return
		if unit is Unit:
			(unit as Unit).command_move(rally_target.global_position)
			return
	if unit is Unit:
		(unit as Unit).command_move(rally_world)
	elif unit.has_method("command_move"):
		unit.command_move(rally_world)


func _draw() -> void:
	# Sprite2D flag replaces the old procedural polygon placeholder.
	pass
