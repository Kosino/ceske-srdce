extends Node2D
class_name BuildingPlacer

signal building_placed(building: Building)

const HOUSE_SCENE := preload("res://scenes/buildings/House.tscn")
const BARRACKS_SCENE := preload("res://scenes/buildings/Barracks.tscn")
const ARCHERY_SCENE := preload("res://scenes/buildings/ArcheryRange.tscn")
const LUMBER_SCENE := preload("res://scenes/buildings/LumberCamp.tscn")
const MINING_SCENE := preload("res://scenes/buildings/MiningCamp.tscn")
const MILL_SCENE := preload("res://scenes/buildings/Mill.tscn")
const BLACKSMITH_SCENE := preload("res://scenes/buildings/Blacksmith.tscn")
const STABLE_SCENE := preload("res://scenes/buildings/Stable.tscn")
const CASTLE_SCENE := preload("res://scenes/buildings/Castle.tscn")
const WALL_SCENE := preload("res://scenes/buildings/WallSegment.tscn")
const GATE_SCENE := preload("res://scenes/buildings/Gate.tscn")
const TOWER_SCENE := preload("res://scenes/buildings/WatchTower.tscn")
const MONASTERY_SCENE := preload("res://scenes/buildings/Monastery.tscn")
const MARKET_SCENE := preload("res://scenes/buildings/Market.tscn")
const UNIVERSITY_SCENE := preload("res://scenes/buildings/University.tscn")
const SIEGE_WORKSHOP_SCENE := preload("res://scenes/buildings/SiegeWorkshop.tscn")

const GHOST_TEXTURES := {
	"house": preload("res://assets/sprites/buildings/house.png"),
	"barracks": preload("res://assets/sprites/buildings/barracks.png"),
	"archery_range": preload("res://assets/sprites/buildings/archery_range.png"),
	"lumber_camp": preload("res://assets/sprites/buildings/lumber_camp.png"),
	"mining_camp": preload("res://assets/sprites/buildings/mining_camp.png"),
	"mill": preload("res://assets/sprites/buildings/mill.png"),
	"blacksmith": preload("res://assets/sprites/buildings/blacksmith.png"),
	"stable": preload("res://assets/sprites/buildings/stable.png"),
	"castle": preload("res://assets/sprites/buildings/castle.png"),
	"palisade": preload("res://assets/sprites/buildings/palisade.png"),
	"stone_wall": preload("res://assets/sprites/buildings/stone_wall.png"),
	"gate": preload("res://assets/sprites/buildings/gate.png"),
	"watch_tower": preload("res://assets/sprites/buildings/watch_tower.png"),
	"monastery": preload("res://assets/sprites/buildings/monastery.png"),
	"market": preload("res://assets/sprites/buildings/market.png"),
	"university": preload("res://assets/sprites/buildings/university.png"),
	"siege_workshop": preload("res://assets/sprites/buildings/siege_workshop.png"),
}

## DESIGN costs and base build times (1 villager).
const COSTS := {
	"house": {"wood": 25},
	"barracks": {"wood": 175},
	"archery_range": {"wood": 175},
	"lumber_camp": {"wood": 100},
	"mining_camp": {"wood": 100},
	"mill": {"wood": 100},
	"blacksmith": {"wood": 150},
	"stable": {"wood": 175},
	"castle": {"stone": 650},
	"palisade": {"wood": 2},
	"stone_wall": {"stone": 5},
	"gate": {"stone": 30},
	"watch_tower": {"stone": 125, "wood": 25},
	"monastery": {"wood": 175},
	"market": {"wood": 175},
	"university": {"wood": 200},
	"siege_workshop": {"wood": 200},
}

const BUILD_TIMES := {
	"house": 25.0,
	"barracks": 50.0,
	"archery_range": 50.0,
	"lumber_camp": 25.0,
	"mining_camp": 25.0,
	"mill": 35.0,
	"blacksmith": 40.0,
	"stable": 45.0,
	"castle": 120.0,
	"palisade": 5.0,
	"stone_wall": 8.0,
	"gate": 10.0,
	"watch_tower": 40.0,
	"monastery": 40.0,
	"market": 60.0,
	"university": 60.0,
	"siege_workshop": 60.0,
}

const FOOTPRINTS := {
	"house": Vector2(56, 56),
	"barracks": Vector2(80, 80),
	"archery_range": Vector2(80, 80),
	"lumber_camp": Vector2(80, 80),
	"mining_camp": Vector2(80, 80),
	"mill": Vector2(72, 72),
	"blacksmith": Vector2(80, 80),
	"stable": Vector2(80, 80),
	"castle": Vector2(160, 160),
	"palisade": Vector2(40, 40),
	"stone_wall": Vector2(40, 40),
	"gate": Vector2(120, 40),
	"watch_tower": Vector2(40, 40),
	"monastery": Vector2(80, 80),
	"market": Vector2(80, 80),
	"university": Vector2(80, 80),
	"siege_workshop": Vector2(80, 80),
}

const WALL_TYPES := ["palisade", "stone_wall"]

## Extra prerequisites beyond age unlock.
const REQUIRES_BUILDING := {
	"stable": "barracks",
	"siege_workshop": "university",
}

@export var map_size: Vector2 = Vector2(3000, 3000)
@export var entities_path: NodePath = ^"../Units"

var placing_type: String = ""
var entities: Node2D
var _ghost: Sprite2D
var _wall_drag: bool = false
var _wall_start: Vector2i = Vector2i.ZERO
var _wall_preview: Array[Vector2i] = []
var _preview_cost_label: Label
var _next_chain_id: int = 1
var _gate_orientation: String = "h"


func _ready() -> void:
	add_to_group("building_placer")
	entities = get_node_or_null(entities_path)
	_ghost = Sprite2D.new()
	_ghost.centered = true
	_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ghost.z_index = 100
	_ghost.visible = false
	add_child(_ghost)
	_preview_cost_label = Label.new()
	_preview_cost_label.z_index = 101
	_preview_cost_label.visible = false
	_preview_cost_label.add_theme_font_size_override("font_size", 12)
	_preview_cost_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_preview_cost_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_preview_cost_label.add_theme_constant_override("outline_size", 3)
	add_child(_preview_cost_label)


func is_wall_type(building_type: String) -> bool:
	return building_type in WALL_TYPES


func begin_place(building_type: String) -> void:
	if building_type not in COSTS:
		return
	if not GameManager.is_building_unlocked(building_type):
		NotificationManager.show_message(
			"Zamčeno do věku %s." % AgeData.age_name(AgeData.building_unlock_age(building_type))
		)
		return
	if not _prereq_met(building_type):
		NotificationManager.show_message(_prereq_message(building_type))
		return
	placing_type = building_type
	_wall_drag = false
	_wall_preview.clear()
	_configure_ghost(building_type)
	_ghost.visible = not is_wall_type(building_type)
	_preview_cost_label.visible = true
	var cost := GameManager.adjust_building_cost(COSTS[building_type], 0)
	var hint := "táhni LMB" if is_wall_type(building_type) else "LMB položit"
	NotificationManager.show_message(
		"Stavba: %s (%s) — %s, RMB zrušit" % [building_type, CivData.format_cost(cost), hint]
	)


func cancel() -> void:
	placing_type = ""
	_wall_drag = false
	_wall_preview.clear()
	_ghost.visible = false
	_preview_cost_label.visible = false
	queue_redraw()


func place_at(building_type: String, world_pos: Vector2) -> Building:
	if building_type not in COSTS:
		return null
	if is_wall_type(building_type):
		return null
	if building_type == "gate":
		return place_gate_at(world_pos)
	if not GameManager.is_building_unlocked(building_type):
		NotificationManager.show_message(
			"Zamčeno do věku %s." % AgeData.age_name(AgeData.building_unlock_age(building_type))
		)
		return null
	if not _prereq_met(building_type):
		NotificationManager.show_message(_prereq_message(building_type))
		return null
	var pos := world_pos
	if building_type == "watch_tower":
		pos = WallNav.snap_world(world_pos)
	if not _can_place(building_type, pos):
		return null
	var cost := GameManager.adjust_building_cost(COSTS[building_type], 0)
	if not GameManager.spend(cost):
		NotificationManager.show_message("Nedostatek surovin.")
		return null
	var building := _instantiate_building(building_type)
	if building == null or entities == null:
		return null
	building.position = pos
	building.is_complete = false
	building.build_progress = 0.0
	building.placed_cost = cost.duplicate()
	if building is WatchTower:
		(building as WatchTower).build_cost = cost.duplicate()
		(building as WatchTower).spawn_parent = entities
	elif "build_cost" in building:
		building.set("build_cost", cost.duplicate())
	entities.add_child(building)
	if building is Barracks:
		(building as Barracks).spawn_parent = entities
	elif building is ArcheryRange:
		(building as ArcheryRange).spawn_parent = entities
	elif building is Stable:
		(building as Stable).spawn_parent = entities
	elif building is SiegeWorkshop:
		(building as SiegeWorkshop).spawn_parent = entities
	elif building is Castle:
		(building as Castle).spawn_parent = entities
	elif building is Monastery:
		(building as Monastery).spawn_parent = entities
	var build_t: float = float(BUILD_TIMES.get(building_type, building.build_time))
	building.start_construction(build_t)
	_assign_builders(building)
	print("[BUILD] placed %s under construction (%.0fs) at %s" % [building_type, build_t, str(pos)])
	building_placed.emit(building)
	NotificationManager.show_message("Zakládám: %s" % building.display_name)
	return building


func place_wall_line(building_type: String, tiles: Array[Vector2i]) -> Array:
	var placed: Array = []
	if not is_wall_type(building_type) or tiles.is_empty():
		return placed
	var per := GameManager.adjust_building_cost(COSTS[building_type], 0)
	var chain := _next_chain_id
	_next_chain_id += 1
	var idx := 0
	for t in tiles:
		if not _can_place_wall_tile(t):
			continue
		if not GameManager.spend(per):
			NotificationManager.show_message("Nedostatek surovin — řada přerušena.")
			break
		var seg: WallSegment = WALL_SCENE.instantiate() as WallSegment
		seg.wall_kind = building_type
		seg.build_cost = per.duplicate()
		seg.placed_cost = per.duplicate()
		seg.team = 0
		seg.tile = t
		seg.chain_id = chain
		seg.chain_index = idx
		seg.position = WallNav.tile_center(t)
		seg.is_complete = false
		seg.build_progress = 0.0
		entities.add_child(seg)
		var build_t: float = float(BUILD_TIMES[building_type])
		seg.start_construction(build_t)
		placed.append(seg)
		building_placed.emit(seg)
		idx += 1
	if not placed.is_empty():
		_assign_builders_sequential(placed)
		NotificationManager.show_message("Zakládám zeď: %d segmentů" % placed.size())
	return placed


func place_gate_at(world_pos: Vector2, orientation: String = "") -> Building:
	if not GameManager.is_building_unlocked("gate"):
		NotificationManager.show_message(
			"Zamčeno do věku %s." % AgeData.age_name(AgeData.building_unlock_age("gate"))
		)
		return null
	var ori := orientation if orientation != "" else _gate_orientation
	var anchor := WallNav.world_to_tile(world_pos)
	# Prefer replacing existing wall run of 3.
	var run := _find_wall_run_near(anchor)
	if not run.is_empty():
		anchor = run["anchor"]
		ori = run["orientation"]
		_remove_wall_tiles(run["tiles"])
	else:
		# Fresh gate: need 3 free tiles.
		var tiles := _gate_tiles(anchor, ori)
		for t in tiles:
			if not _can_place_wall_tile(t) and not _tile_has_own_wall(t):
				NotificationManager.show_message("Brána potřebuje 3 volná / zeďová pole.")
				return null
		_remove_wall_tiles(tiles)
	var cost := GameManager.adjust_building_cost(COSTS["gate"], 0)
	if not GameManager.spend(cost):
		NotificationManager.show_message("Nedostatek surovin.")
		return null
	var gate: Gate = GATE_SCENE.instantiate() as Gate
	gate.team = 0
	gate.orientation = ori
	gate.anchor_tile = anchor
	gate.build_cost = cost.duplicate()
	gate.placed_cost = cost.duplicate()
	gate.position = _gate_center(anchor, ori)
	gate.is_complete = false
	gate.build_progress = 0.0
	entities.add_child(gate)
	gate.start_construction(float(BUILD_TIMES["gate"]))
	_assign_builders(gate)
	building_placed.emit(gate)
	NotificationManager.show_message("Zakládám: Brána")
	return gate


func _gate_tiles(anchor: Vector2i, ori: String) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in range(3):
		out.append(anchor + (Vector2i(0, i) if ori == "v" else Vector2i(i, 0)))
	return out


func _gate_center(anchor: Vector2i, ori: String) -> Vector2:
	var tiles := _gate_tiles(anchor, ori)
	var acc := Vector2.ZERO
	for t in tiles:
		acc += WallNav.tile_center(t)
	return acc / float(tiles.size())


func _find_wall_run_near(near: Vector2i) -> Dictionary:
	var occ := WallNav.occupancy_map(get_tree())
	# Horizontal run covering near.x.. 
	for start_x in range(near.x - 2, near.x + 1):
		var tiles_h: Array[Vector2i] = []
		var ok_h := true
		for i in range(3):
			var t := Vector2i(start_x + i, near.y)
			if not occ.has(t) or not (occ[t] is WallSegment):
				ok_h = false
				break
			if (occ[t] as WallSegment).team != 0:
				ok_h = false
				break
			tiles_h.append(t)
		if ok_h:
			return {"anchor": Vector2i(start_x, near.y), "orientation": "h", "tiles": tiles_h}
	for start_y in range(near.y - 2, near.y + 1):
		var tiles_v: Array[Vector2i] = []
		var ok_v := true
		for i in range(3):
			var t := Vector2i(near.x, start_y + i)
			if not occ.has(t) or not (occ[t] is WallSegment):
				ok_v = false
				break
			if (occ[t] as WallSegment).team != 0:
				ok_v = false
				break
			tiles_v.append(t)
		if ok_v:
			return {"anchor": Vector2i(near.x, start_y), "orientation": "v", "tiles": tiles_v}
	return {}


func _remove_wall_tiles(tiles: Array) -> void:
	var occ := WallNav.occupancy_map(get_tree())
	for t in tiles:
		if occ.has(t) and occ[t] is WallSegment:
			(occ[t] as WallSegment).queue_free()


func _tile_has_own_wall(t: Vector2i) -> bool:
	var occ := WallNav.occupancy_map(get_tree())
	return occ.has(t) and occ[t] is WallSegment and (occ[t] as WallSegment).team == 0


func _assign_builders(building: Building) -> void:
	var assigned := false
	for u in SelectionManager.selected_units:
		if u is Villager and is_instance_valid(u):
			(u as Villager).assign_build(building)
			assigned = true
	if assigned:
		return
	var best: Villager = null
	var best_d := 220.0
	for n in get_tree().get_nodes_in_group("villagers"):
		if not (n is Villager):
			continue
		var v := n as Villager
		if v.team != 0:
			continue
		var d := v.global_position.distance_to(building.global_position)
		if d < best_d:
			best_d = d
			best = v
	if best:
		best.assign_build(building)


func _assign_builders_sequential(segments: Array) -> void:
	## One villager builds chain in order; extras help first unfinished.
	if segments.is_empty():
		return
	var villagers: Array[Villager] = []
	for u in SelectionManager.selected_units:
		if u is Villager and is_instance_valid(u):
			villagers.append(u as Villager)
	if villagers.is_empty():
		_assign_builders(segments[0] as Building)
		# Store chain so first villager continues.
		var v0 := _nearest_idle_villager((segments[0] as Building).global_position)
		if v0:
			v0.assign_build_chain(segments)
		return
	villagers[0].assign_build_chain(segments)
	for i in range(1, villagers.size()):
		villagers[i].assign_build(segments[0] as Building)


func _nearest_idle_villager(pos: Vector2) -> Villager:
	var best: Villager = null
	var best_d := 400.0
	for n in get_tree().get_nodes_in_group("villagers"):
		if not (n is Villager):
			continue
		var v := n as Villager
		if v.team != 0:
			continue
		var d := v.global_position.distance_to(pos)
		if d < best_d:
			best_d = d
			best = v
	return best


func _process(_delta: float) -> void:
	if placing_type == "":
		return
	var mouse := get_global_mouse_position()
	if is_wall_type(placing_type):
		var cur := WallNav.world_to_tile(mouse)
		if _wall_drag:
			_wall_preview = WallNav.line_tiles(_wall_start, cur)
		else:
			_wall_preview = [cur] as Array[Vector2i]
		_update_wall_preview_label()
		queue_redraw()
		return
	if placing_type == "gate" or placing_type == "watch_tower":
		mouse = WallNav.snap_world(mouse)
	_ghost.global_position = mouse
	_ghost.visible = true
	var cost2 := GameManager.adjust_building_cost(COSTS[placing_type], 0)
	_preview_cost_label.visible = true
	_preview_cost_label.global_position = mouse + Vector2(-30, FOOTPRINTS[placing_type].y * 0.5 + 4.0)
	_preview_cost_label.text = CivData.format_cost(cost2)
	var ok2 := _can_place(placing_type, mouse) and GameManager.can_afford(cost2)
	_ghost.modulate = Color(0.35, 1.0, 0.45, 0.45) if ok2 else Color(1.0, 0.35, 0.35, 0.45)


func _update_wall_preview_label() -> void:
	var n := _wall_preview.size()
	var per := GameManager.adjust_building_cost(COSTS[placing_type], 0)
	var total: Dictionary = {}
	for k in per.keys():
		total[k] = int(per[k]) * n
	_preview_cost_label.visible = true
	if n > 0:
		_preview_cost_label.global_position = WallNav.tile_center(_wall_preview[n / 2]) + Vector2(-40, 28)
	_preview_cost_label.text = "%d× %s" % [n, CivData.format_cost(total)]


func _draw() -> void:
	if placing_type == "":
		return
	if not is_wall_type(placing_type):
		return
	var tex: Texture2D = GHOST_TEXTURES.get(placing_type)
	var per := GameManager.adjust_building_cost(COSTS[placing_type], 0)
	var afford_n := _max_affordable_tiles(per)
	for i in _wall_preview.size():
		var t: Vector2i = _wall_preview[i]
		var pos := WallNav.tile_center(t)
		var local2 := to_local(pos)
		var ok2 := _can_place_wall_tile(t) and i < afford_n
		var col := Color(1, 1, 1, 0.55) if ok2 else Color(1.0, 0.35, 0.35, 0.45)
		if tex:
			draw_texture(tex, local2 - Vector2(tex.get_width(), tex.get_height()) * 0.5, col)
		else:
			var r2 := Rect2(local2 - Vector2(18, 18), Vector2(36, 36))
			draw_rect(r2, col, true)


func _max_affordable_tiles(per: Dictionary) -> int:
	var n := 999
	for k in per.keys():
		var have := 0
		match str(k):
			"food":
				have = GameManager.food
			"wood":
				have = GameManager.wood
			"gold":
				have = GameManager.gold
			"stone":
				have = GameManager.stone
		var need := int(per[k])
		if need <= 0:
			continue
		n = mini(n, int(have / need))
	return maxi(n, 0)


func _unhandled_input(event: InputEvent) -> void:
	if placing_type == "":
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			cancel()
			get_viewport().set_input_as_handled()
			return
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if is_wall_type(placing_type):
				if mb.pressed:
					_wall_drag = true
					_wall_start = WallNav.world_to_tile(get_global_mouse_position())
					_wall_preview = [_wall_start] as Array[Vector2i]
					queue_redraw()
				else:
					if _wall_drag:
						var end := WallNav.world_to_tile(get_global_mouse_position())
						var tiles := WallNav.line_tiles(_wall_start, end)
						place_wall_line(placing_type, tiles)
						cancel()
					_wall_drag = false
				get_viewport().set_input_as_handled()
				return
			if mb.pressed:
				var built := place_at(placing_type, get_global_mouse_position())
				if built:
					cancel()
				get_viewport().set_input_as_handled()


func _instantiate_building(building_type: String) -> Building:
	match building_type:
		"house":
			return HOUSE_SCENE.instantiate() as Building
		"barracks":
			return BARRACKS_SCENE.instantiate() as Building
		"archery_range":
			return ARCHERY_SCENE.instantiate() as Building
		"lumber_camp":
			return LUMBER_SCENE.instantiate() as Building
		"mining_camp":
			return MINING_SCENE.instantiate() as Building
		"mill":
			return MILL_SCENE.instantiate() as Building
		"blacksmith":
			return BLACKSMITH_SCENE.instantiate() as Building
		"stable":
			return STABLE_SCENE.instantiate() as Building
		"castle":
			return CASTLE_SCENE.instantiate() as Building
		"watch_tower":
			return TOWER_SCENE.instantiate() as Building
		"gate":
			return GATE_SCENE.instantiate() as Building
		"monastery":
			return MONASTERY_SCENE.instantiate() as Building
		"market":
			return MARKET_SCENE.instantiate() as Building
		"university":
			return UNIVERSITY_SCENE.instantiate() as Building
		"siege_workshop":
			return SIEGE_WORKSHOP_SCENE.instantiate() as Building
		_:
			return null


func _prereq_message(building_type: String) -> String:
	match str(REQUIRES_BUILDING.get(building_type, "")):
		"university":
			return "Nejdřív postav Univerzitu."
		_:
			return "Nejdřív postav Kasárnu."


func _prereq_met(building_type: String) -> bool:
	if building_type not in REQUIRES_BUILDING:
		return true
	var need: String = str(REQUIRES_BUILDING[building_type])
	var tree := get_tree()
	if tree == null:
		return false
	for n in tree.get_nodes_in_group("player_buildings"):
		if n is Building and (n as Building).building_id == need and (n as Building).is_complete:
			return true
	if need == "barracks":
		for n in tree.get_nodes_in_group("barracks"):
			if n is Building and (n as Building).team == 0 and (n as Building).is_complete:
				return true
	if need == "university":
		for n in tree.get_nodes_in_group("universities"):
			if n is Building and (n as Building).team == 0 and (n as Building).is_complete:
				return true
	return false


func _configure_ghost(building_type: String) -> void:
	var tex: Texture2D = GHOST_TEXTURES.get(building_type)
	var footprint: Vector2 = FOOTPRINTS[building_type]
	_ghost.texture = tex
	_ghost.centered = true
	if tex:
		_ghost.offset = Vector2(0.0, footprint.y * 0.5 - float(tex.get_height()) * 0.5)
	_ghost.modulate = Color(1, 1, 1, 0.45)


func _can_place_wall_tile(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= WallNav.MAP_TILES or tile.y >= WallNav.MAP_TILES:
		return false
	var occ := WallNav.occupancy_map(get_tree())
	if occ.has(tile):
		return false
	var pos := WallNav.tile_center(tile)
	if entities == null:
		return true
	for child in entities.get_children():
		if child is Building and not (child is WallSegment) and not (child is Gate):
			var other := child as Building
			var min_dist := (other.footprint + Vector2(40, 40)).length() * 0.28
			if pos.distance_to(other.global_position) < min_dist:
				return false
		elif child is DropOff:
			if pos.distance_to(child.global_position) < 70.0:
				return false
	return true


func _can_place(building_type: String, world_pos: Vector2) -> bool:
	var size: Vector2 = FOOTPRINTS[building_type]
	var half := size * 0.5
	if world_pos.x - half.x < 0.0 or world_pos.y - half.y < 0.0:
		return false
	if world_pos.x + half.x > map_size.x or world_pos.y + half.y > map_size.y:
		return false
	if building_type == "watch_tower":
		return _can_place_wall_tile(WallNav.world_to_tile(world_pos))
	if entities == null:
		return true
	for child in entities.get_children():
		if child is Building:
			var other := child as Building
			var min_dist := (other.footprint + size).length() * 0.35
			if world_pos.distance_to(other.global_position) < min_dist:
				return false
		elif child is DropOff:
			if world_pos.distance_to(child.global_position) < 90.0:
				return false
	return true
