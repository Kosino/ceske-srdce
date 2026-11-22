extends Object
class_name WallNav
## Tile grid helpers for wall blocking / pathing. Tile = 40 px (DESIGN).

const TILE := 40
const MAP_TILES := 75


static func world_to_tile(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / float(TILE))), int(floor(p.y / float(TILE))))


static func tile_center(t: Vector2i) -> Vector2:
	return Vector2((float(t.x) + 0.5) * float(TILE), (float(t.y) + 0.5) * float(TILE))


static func snap_world(p: Vector2) -> Vector2:
	return tile_center(world_to_tile(p))


## Bresenham line inclusive — straight or 45° diagonal.
static func line_tiles(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var x0 := a.x
	var y0 := a.y
	var x1 := b.x
	var y1 := b.y
	var dx := absi(x1 - x0)
	var dy := absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx - dy
	while true:
		out.append(Vector2i(x0, y0))
		if x0 == x1 and y0 == y1:
			break
		var e2 := err * 2
		if e2 > -dy:
			err -= dy
			x0 += sx
		if e2 < dx:
			err += dx
			y0 += sy
	return out


static func occupancy_map(tree: SceneTree) -> Dictionary:
	## tile Vector2i -> Building (WallSegment or Gate)
	var map: Dictionary = {}
	if tree == null:
		return map
	for n in tree.get_nodes_in_group("walls"):
		if n is WallSegment and is_instance_valid(n):
			map[(n as WallSegment).tile] = n
	for n in tree.get_nodes_in_group("gates"):
		if n is Gate and is_instance_valid(n):
			var g := n as Gate
			for t in g.occupied_tiles():
				map[t] = g
	return map


static func blocks_team(building: Building, for_team: int) -> bool:
	if building == null or not is_instance_valid(building):
		return false
	if not building.is_complete:
		return false
	if building is Gate:
		# Own units pass; enemies blocked.
		return (building as Gate).team != for_team
	if building is WallSegment:
		return true
	return false


static func is_tile_blocked(tile: Vector2i, for_team: int, occ: Dictionary) -> bool:
	if tile.x < 0 or tile.y < 0 or tile.x >= MAP_TILES or tile.y >= MAP_TILES:
		return true
	if not occ.has(tile):
		return false
	return blocks_team(occ[tile] as Building, for_team)


## A* on tile grid. Returns world waypoints (tile centers) or empty if unreachable.
static func find_path(from: Vector2, to: Vector2, for_team: int, tree: SceneTree) -> Array[Vector2]:
	var occ := occupancy_map(tree)
	if occ.is_empty():
		return [] as Array[Vector2]
	var start := world_to_tile(from)
	var goal := world_to_tile(to)
	if is_tile_blocked(start, for_team, occ):
		# Step off wall tile if standing on one.
		start = _nearest_open(start, for_team, occ)
	if is_tile_blocked(goal, for_team, occ):
		goal = _nearest_open(goal, for_team, occ)
	if start == Vector2i(-1, -1) or goal == Vector2i(-1, -1):
		return [] as Array[Vector2]
	var came := _astar(start, goal, for_team, occ)
	if came.is_empty():
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
	path.append(to)
	return path


static func path_exists(from: Vector2, to: Vector2, for_team: int, tree: SceneTree) -> bool:
	var occ := occupancy_map(tree)
	if occ.is_empty():
		return true
	var start := world_to_tile(from)
	var goal := world_to_tile(to)
	if is_tile_blocked(goal, for_team, occ):
		goal = _nearest_open(goal, for_team, occ)
	if goal == Vector2i(-1, -1):
		return false
	var came := _astar(start, goal, for_team, occ)
	return not came.is_empty() or start == goal


static func nearest_blocking_segment(from: Vector2, to: Vector2, for_team: int, tree: SceneTree) -> Building:
	## Closest wall/gate on the straight line that blocks this team.
	var occ := occupancy_map(tree)
	var best: Building = null
	var best_d := INF
	for t in line_tiles(world_to_tile(from), world_to_tile(to)):
		if not occ.has(t):
			continue
		var b: Building = occ[t] as Building
		if not blocks_team(b, for_team):
			continue
		var d := from.distance_to(b.global_position)
		if d < best_d:
			best_d = d
			best = b
	if best:
		return best
	# Fallback: any nearest blocking wall.
	for b in occ.values():
		if not blocks_team(b as Building, for_team):
			continue
		var d2 := from.distance_to((b as Building).global_position)
		if d2 < best_d:
			best_d = d2
			best = b as Building
	return best


static func _nearest_open(tile: Vector2i, for_team: int, occ: Dictionary) -> Vector2i:
	if not is_tile_blocked(tile, for_team, occ):
		return tile
	for r in range(1, 6):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var t := Vector2i(tile.x + dx, tile.y + dy)
				if not is_tile_blocked(t, for_team, occ):
					return t
	return Vector2i(-1, -1)


static func _astar(start: Vector2i, goal: Vector2i, for_team: int, occ: Dictionary) -> Dictionary:
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
			if is_tile_blocked(nxt, for_team, occ):
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
