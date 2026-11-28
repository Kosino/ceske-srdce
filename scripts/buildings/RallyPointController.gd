extends Node2D
class_name RallyPointController
## Rally flag for training buildings / Radnice. Newly trained units walk here;
## if rally is on a resource (or farm), villagers start gathering.


var has_rally: bool = false
var rally_world: Vector2 = Vector2.ZERO
var rally_target: Node2D = null


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
	return (
		node is DropOff
		or node is Barracks
		or node is ArcheryRange
		or node is Stable
		or node is Castle
		or node is Monastery
		or node is SiegeWorkshop
	)


func set_rally(world_pos: Vector2, target: Node2D = null) -> void:
	has_rally = true
	rally_world = world_pos
	if target != null and is_instance_valid(target):
		rally_target = target
	else:
		rally_target = null
	top_level = true
	global_position = world_pos
	visible = true
	queue_redraw()


func clear_rally() -> void:
	has_rally = false
	rally_target = null
	visible = false
	queue_redraw()


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
	if not has_rally or not visible:
		return
	# Small placeholder flag (art pipeline can replace later).
	draw_line(Vector2(0, 2), Vector2(0, -20), Color(0.32, 0.2, 0.08), 2.0)
	var pts := PackedVector2Array([Vector2(1, -20), Vector2(16, -14), Vector2(1, -8)])
	draw_colored_polygon(pts, Color(0.88, 0.18, 0.14, 0.95))
	draw_circle(Vector2(0, 2), 3.0, Color(0.15, 0.15, 0.15, 0.9))
