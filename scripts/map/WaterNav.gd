extends Object
class_name WaterNav
## River / ford tile helpers. Deep water blocks land units; boats need water (or ford).


const TILE := 40
const MAP_TILES := 75

## Deep water tiles (impassable for land). Vector2i -> true
static var water_tiles: Dictionary = {}
## Shallow ford tiles (walkable for land AND boats). Vector2i -> true
static var ford_tiles: Dictionary = {}


static func clear() -> void:
	water_tiles.clear()
	ford_tiles.clear()


static func set_water(tile: Vector2i) -> void:
	if ford_tiles.has(tile):
		return
	water_tiles[tile] = true


static func set_ford(tile: Vector2i) -> void:
	water_tiles.erase(tile)
	ford_tiles[tile] = true


static func is_water(tile: Vector2i) -> bool:
	return water_tiles.has(tile)


static func is_ford(tile: Vector2i) -> bool:
	return ford_tiles.has(tile)


static func is_aquatic(tile: Vector2i) -> bool:
	return water_tiles.has(tile) or ford_tiles.has(tile)


static func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / float(TILE))), int(floor(p.y / float(TILE))))


static func tile_center(t: Vector2i) -> Vector2:
	return Vector2((float(t.x) + 0.5) * float(TILE), (float(t.y) + 0.5) * float(TILE))


static func blocks_land(tile: Vector2i) -> bool:
	return water_tiles.has(tile)


static func blocks_boat(tile: Vector2i) -> bool:
	## Boats travel on deep water and fords; land is blocked.
	return not is_aquatic(tile)


static func has_water() -> bool:
	return not water_tiles.is_empty() or not ford_tiles.is_empty()


static func shore_tiles_near(tile: Vector2i) -> bool:
	## True if tile is land adjacent to aquatic.
	if is_aquatic(tile):
		return false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if is_aquatic(tile + d):
			return true
	return false


## Footprint straddles land + water (dock placement).
static func footprint_on_shore(world_pos: Vector2, footprint: Vector2) -> bool:
	var half := footprint * 0.5
	var min_t := world_to_tile(world_pos - half + Vector2(1, 1))
	var max_t := world_to_tile(world_pos + half - Vector2(1, 1))
	var has_land := false
	var has_water := false
	for x in range(min_t.x, max_t.x + 1):
		for y in range(min_t.y, max_t.y + 1):
			var t := Vector2i(x, y)
			if is_aquatic(t):
				has_water = true
			else:
				has_land = true
	return has_land and has_water


static func find_path_land(from: Vector2, to: Vector2, for_team: int, tree: SceneTree) -> Array[Vector2]:
	var occ := WallNav.occupancy_map(tree) if tree else {}
	return _find_path(from, to, for_team, occ, false)


static func find_path_boat(from: Vector2, to: Vector2) -> Array[Vector2]:
	return _find_path(from, to, 0, {}, true)


static func path_exists_land(from: Vector2, to: Vector2, for_team: int, tree: SceneTree) -> bool:
	if not has_water() and (tree == null or WallNav.occupancy_map(tree).is_empty()):
		return true
	var path := find_path_land(from, to, for_team, tree)
	return not path.is_empty()


static func path_exists_boat(from: Vector2, to: Vector2) -> bool:
	var path := find_path_boat(from, to)
	return not path.is_empty()


static func _tile_blocked_land(tile: Vector2i, for_team: int, occ: Dictionary) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= MAP_TILES or tile.y >= MAP_TILES:
		return true
	if blocks_land(tile):
		return true
	if occ.has(tile):
		return WallNav.blocks_team(occ[tile] as Building, for_team)
	return false


static func _tile_blocked_boat(tile: Vector2i) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= MAP_TILES or tile.y >= MAP_TILES:
		return true
	return blocks_boat(tile)


static func _find_path(
	from: Vector2,
	to: Vector2,
	for_team: int,
	occ: Dictionary,
	boat: bool
) -> Array[Vector2]:
	var start := world_to_tile(from)
	var goal := world_to_tile(to)
	var goal_snapped := false
	if boat:
		if _tile_blocked_boat(start):
			start = _nearest_open_boat(start)
		if _tile_blocked_boat(goal):
			goal = _nearest_open_boat(goal)
			goal_snapped = true
	else:
		if _tile_blocked_land(start, for_team, occ):
			start = _nearest_open_land(start, for_team, occ)
		if _tile_blocked_land(goal, for_team, occ):
			goal = _nearest_open_land(goal, for_team, occ)
			goal_snapped = true
	if start == Vector2i(-1, -1) or goal == Vector2i(-1, -1):
		return [] as Array[Vector2]
	var came := _astar(start, goal, for_team, occ, boat)
	if came.is_empty() and start != goal:
		return [] as Array[Vector2]
	var tiles: Array[Vector2i] = []
	var cur := goal
	while cur != start:
		tiles.push_front(cur)
		if not came.has(cur):
			return [] as Array[Vector2]
		cur = came[cur]
	var path: Array[Vector2] = []
	for t in tiles:
		path.append(tile_center(t))
	# Never append an impassable original target (e.g. deep water for land units).
	if goal_snapped:
		path.append(tile_center(goal))
	else:
		path.append(to)
	return path


static func _nearest_open_land(tile: Vector2i, for_team: int, occ: Dictionary) -> Vector2i:
	if not _tile_blocked_land(tile, for_team, occ):
		return tile
	for r in range(1, 8):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var t := Vector2i(tile.x + dx, tile.y + dy)
				if not _tile_blocked_land(t, for_team, occ):
					return t
	return Vector2i(-1, -1)


static func _nearest_open_boat(tile: Vector2i) -> Vector2i:
	if not _tile_blocked_boat(tile):
		return tile
	for r in range(1, 10):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var t := Vector2i(tile.x + dx, tile.y + dy)
				if not _tile_blocked_boat(t):
					return t
	return Vector2i(-1, -1)


static func _astar(
	start: Vector2i,
	goal: Vector2i,
	for_team: int,
	occ: Dictionary,
	boat: bool
) -> Dictionary:
	if start == goal:
		return {start: start}
	var open: Array[Vector2i] = [start]
	var came: Dictionary = {}
	var g_score: Dictionary = {start: 0}
	var f_score: Dictionary = {start: _h(start, goal)}
	var closed: Dictionary = {}
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	while not open.is_empty():
		var current := _pop_best(open, f_score)
		if current == goal:
			return came
		closed[current] = true
		for d in dirs:
			var nxt := current + d
			if boat:
				if _tile_blocked_boat(nxt):
					continue
			else:
				if _tile_blocked_land(nxt, for_team, occ):
					continue
			if closed.has(nxt):
				continue
			var step := 14 if d.x != 0 and d.y != 0 else 10
			var tentative: int = int(g_score.get(current, 999999)) + step
			if tentative < int(g_score.get(nxt, 999999)):
				came[nxt] = current
				g_score[nxt] = tentative
				f_score[nxt] = tentative + _h(nxt, goal)
				if not open.has(nxt):
					open.append(nxt)
	return {}


static func _h(a: Vector2i, b: Vector2i) -> int:
	return (absi(a.x - b.x) + absi(a.y - b.y)) * 10


static func _pop_best(open: Array[Vector2i], f_score: Dictionary) -> Vector2i:
	var best_i := 0
	var best_f: int = int(f_score.get(open[0], 999999))
	for i in range(1, open.size()):
		var f: int = int(f_score.get(open[i], 999999))
		if f < best_f:
			best_f = f
			best_i = i
	var t: Vector2i = open[best_i]
	open.remove_at(best_i)
	return t
