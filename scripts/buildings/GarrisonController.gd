extends Node2D
class_name GarrisonController
## AoE II-style garrison for Radnice / Strážní věž / Hrad.
## Units inside are hidden; villagers + archers add arrows; slow heal while inside.

signal garrison_changed(count: int, capacity: int)

const CAPACITY_TC := 15
const CAPACITY_TOWER := 5
const CAPACITY_CASTLE := 20
const HEAL_HP_PER_SEC := 0.8
const ENTER_RANGE := 48.0
const EJECT_SPREAD := 36.0

## Host building / DropOff.
var host: Node = null
var capacity: int = CAPACITY_TC
var garrisoned: Array[Unit] = []


static func ensure(host_node: Node) -> GarrisonController:
	if host_node == null:
		return null
	var existing := host_node.get_node_or_null("Garrison") as GarrisonController
	if existing:
		existing.host = host_node
		existing.capacity = capacity_for(host_node)
		return existing
	var g := GarrisonController.new()
	g.name = "Garrison"
	g.host = host_node
	g.capacity = capacity_for(host_node)
	g.z_index = 60
	host_node.add_child(g)
	return g


static func of(host_node: Node) -> GarrisonController:
	if host_node == null:
		return null
	return host_node.get_node_or_null("Garrison") as GarrisonController


static func can_host(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node is DropOff:
		return true
	if node is WatchTower or node is Castle:
		var b := node as Building
		return b.is_complete
	return false


static func capacity_for(node: Node) -> int:
	if node is DropOff:
		return CAPACITY_TC
	if node is WatchTower:
		return CAPACITY_TOWER
	if node is Castle:
		return CAPACITY_CASTLE
	return 0


static func can_garrison_unit(unit: Unit) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if unit.is_garrisoned:
		return false
	if unit.is_cavalry or unit.buildings_only:
		return false
	# Monks / siege-like: only infantry, archers, villagers.
	if unit is Monk or unit is Ram or unit is Trebuchet:
		return false
	return true


static func contributes_arrow(unit: Unit) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	return unit is Villager or unit is Archer or unit.unit_id == "villager" or unit.unit_id == "archer"


func _ready() -> void:
	if host == null:
		host = get_parent()
	capacity = capacity_for(host)
	if host and not host.is_in_group("garrison_hosts"):
		host.add_to_group("garrison_hosts")
	set_process(true)
	queue_redraw()


func _process(delta: float) -> void:
	_prune()
	_heal_garrison(delta)
	queue_redraw()


func count() -> int:
	_prune()
	return garrisoned.size()


func room() -> int:
	return maxi(0, capacity - count())


func is_full() -> bool:
	return room() <= 0


func arrow_bonus() -> int:
	_prune()
	var n := 0
	for u in garrisoned:
		if contributes_arrow(u):
			n += 1
	return n


## Total arrows this host should loose (base + garrison bonus).
func total_arrows(base_arrows: int = 1) -> int:
	return maxi(0, base_arrows) + arrow_bonus()


func try_enter(unit: Unit) -> bool:
	if unit == null or not is_instance_valid(unit):
		return false
	if not can_garrison_unit(unit):
		return false
	if host == null or not is_instance_valid(host):
		return false
	if "team" in host and int(host.get("team")) != unit.team:
		return false
	if host is Building and not (host as Building).is_complete:
		return false
	_prune()
	if garrisoned.has(unit):
		return true
	if is_full():
		NotificationManager.show_message("Posádka je plná (%d)." % capacity)
		return false
	_hide_unit(unit)
	garrisoned.append(unit)
	unit.is_garrisoned = true
	unit.garrison_host = host
	unit._garrison_target = null
	garrison_changed.emit(count(), capacity)
	queue_redraw()
	print("[GARRISON] enter %s -> %s (%d/%d)" % [unit.name, _host_label(), count(), capacity])
	return true


func eject_all(to_rally: bool = true) -> int:
	_prune()
	var units := garrisoned.duplicate()
	garrisoned.clear()
	var rally := RallyPointController.of(host) if to_rally else null
	var i := 0
	for u in units:
		if u == null or not is_instance_valid(u):
			continue
		_reveal_unit(u, i)
		if rally != null and rally.has_rally:
			rally.apply_to_unit(u)
		elif u is Unit:
			var dest := _eject_position(i)
			(u as Unit).command_move(dest)
		i += 1
	garrison_changed.emit(count(), capacity)
	queue_redraw()
	if i > 0:
		print("[GARRISON] eject %d from %s" % [i, _host_label()])
		NotificationManager.show_message("Vyprázdněno: %d" % i)
	return i


func eject_unit(unit: Unit, to_rally: bool = false) -> bool:
	if unit == null or not garrisoned.has(unit):
		return false
	garrisoned.erase(unit)
	_reveal_unit(unit, 0)
	if to_rally:
		var rally := RallyPointController.of(host)
		if rally != null and rally.has_rally:
			rally.apply_to_unit(unit)
		else:
			unit.command_move(_eject_position(0))
	garrison_changed.emit(count(), capacity)
	queue_redraw()
	return true


func _hide_unit(unit: Unit) -> void:
	SelectionManager.notify_unit_removed(unit)
	unit.command_stop()
	unit.visible = false
	unit.set_selected(false)
	unit.collision_layer = 0
	unit.collision_mask = 0
	unit.process_mode = Node.PROCESS_MODE_DISABLED
	# Keep in tree; remove from combat targeting groups while inside.
	if unit.is_in_group("player_units"):
		unit.remove_from_group("player_units")
	if unit.is_in_group("enemy_units"):
		unit.remove_from_group("enemy_units")


func _reveal_unit(unit: Unit, index: int) -> void:
	unit.is_garrisoned = false
	unit.garrison_host = null
	unit._garrison_target = null
	unit.process_mode = Node.PROCESS_MODE_INHERIT
	unit.visible = true
	unit._setup_wall_collision()
	unit.global_position = _eject_position(index)
	unit._register_team_groups_soft()
	unit.queue_redraw()


func _eject_position(index: int) -> Vector2:
	var origin := Vector2.ZERO
	if host is Node2D:
		origin = (host as Node2D).global_position
	var foot := Vector2(80, 80)
	if host is Building:
		foot = (host as Building).footprint
	elif host is DropOff:
		foot = Vector2(80, 80)
	var angle := float(index) * TAU / 8.0
	var radius := foot.length() * 0.35 + EJECT_SPREAD
	return origin + Vector2(cos(angle), sin(angle)) * radius + Vector2(0, foot.y * 0.25)


func _heal_garrison(delta: float) -> void:
	if garrisoned.is_empty():
		return
	var amount := HEAL_HP_PER_SEC * delta
	for u in garrisoned:
		if u == null or not is_instance_valid(u):
			continue
		if u.hp >= u.max_hp - 0.01:
			continue
		u.hp = minf(u.max_hp, u.hp + amount)


func _prune() -> void:
	var kept: Array[Unit] = []
	for u in garrisoned:
		if u != null and is_instance_valid(u):
			kept.append(u)
	if kept.size() != garrisoned.size():
		garrisoned = kept
		garrison_changed.emit(count(), capacity)


func _host_label() -> String:
	if host is DropOff:
		return (host as DropOff).building_name
	if host is Building:
		return (host as Building).display_name
	return "budova"


func summary_line() -> String:
	return "Posádka: %d/%d" % [count(), capacity]


func _draw() -> void:
	_prune()
	if count() <= 0:
		return
	# Count badge above HP bar (local space; parent is building origin).
	var y := -70.0
	if host is Building:
		y = -(host as Building).footprint.y * 0.5 - 22.0
	elif host is DropOff:
		var visual := host.get_node_or_null("Visual") as Sprite2D
		if visual and visual.texture:
			y = visual.offset.y - float(visual.texture.get_height()) * 0.5 - 18.0
		else:
			y = -72.0
	var txt := "%d/%d" % [count(), capacity]
	var font := ThemeDB.fallback_font
	var fs := 12
	var sz := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
	var bg := Rect2(Vector2(-sz.x * 0.5 - 4.0, y - 2.0), Vector2(sz.x + 8.0, sz.y + 4.0))
	draw_rect(bg, Color(0.05, 0.08, 0.12, 0.75))
	draw_string(font, Vector2(-sz.x * 0.5, y + sz.y - 2.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.95, 0.92, 0.7))


func on_host_destroyed() -> void:
	## Eject without rally (building is dying).
	eject_all(false)
