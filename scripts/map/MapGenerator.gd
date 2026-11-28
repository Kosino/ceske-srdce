extends RefCounted
class_name MapGenerator
## Deterministic seed-based resource layout. Mirror-fair around both TCs.


const TILE := 40
const MAP_TILES := 75
const TC_RADIUS_TILES := 12
const FOREST_TREES := 25
const BERRY_COUNT := 6
const GOLD_PATCH_TILES := 7
const GOLD_PER_TILE := 800
const STONE_PATCH_TILES := 5
const STONE_PER_TILE := 350
const TREE_AMOUNT := 100
const BERRY_AMOUNT := 100
const WORLD_FOREST_MIN := 6
const WORLD_FOREST_MAX := 8
const WORLD_MINE_MIN := 2
const WORLD_MINE_MAX := 3
const FISH_AMOUNT := 225
const FISH_SCHOOL_MIN := 3
const FISH_SCHOOL_MAX := 5
const RIVER_CENTER_X := 37

const RESOURCE_SCENE := preload("res://scenes/world/ResourceNode.tscn")

var seed_value: int = 1
var rng := RandomNumberGenerator.new()
var blocked: Dictionary = {} # Vector2i -> true
var spawned: Array[Dictionary] = [] # {type, pos, amount} for tests
var parent: Node2D
## River tiles painted by Map after generate (water + fords).
var river_paint: Array[Dictionary] = [] # {tile: Vector2i, kind: "water"|"ford"}


func generate(
	entities: Node2D,
	p_seed: int,
	player_tc: Vector2,
	enemy_tc: Vector2,
	extra_blocked: Array[Vector2i] = []
) -> void:
	parent = entities
	seed_value = p_seed
	rng.seed = p_seed
	blocked.clear()
	spawned.clear()
	river_paint.clear()
	WaterNav.clear()
	for t in extra_blocked:
		_block(t)
	_block_footprint(player_tc, 3)
	_block_footprint(enemy_tc, 3)

	_place_river()
	_place_fish_schools()

	_place_tc_pack(player_tc, false)
	_place_tc_pack(enemy_tc, true)

	# Even counts only so left/right mirrors stay fair (6 or 8 forests; 2 mines pairs).
	var forest_pairs := rng.randi_range(WORLD_FOREST_MIN / 2, WORLD_FOREST_MAX / 2)
	for _i in forest_pairs:
		_place_mirrored_forest()

	var mine_pairs := rng.randi_range(WORLD_MINE_MIN / 2, maxi(1, WORLD_MINE_MAX / 2))
	for _j in mine_pairs:
		var kind := "gold" if rng.randf() < 0.5 else "stone"
		_place_mirrored_mine(kind)


func resource_fingerprint() -> String:
	var parts: Array[String] = []
	for e in spawned:
		parts.append("%s:%.0f,%.0f:%d" % [e["type"], e["pos"].x, e["pos"].y, int(e["amount"])])
	parts.sort()
	return "|".join(parts)


func count_near(tc: Vector2, resource_type: String, radius_tiles: float = float(TC_RADIUS_TILES)) -> int:
	var r := radius_tiles * float(TILE)
	var n := 0
	for e in spawned:
		if str(e["type"]) != resource_type:
			continue
		if (e["pos"] as Vector2).distance_to(tc) <= r + 0.5:
			n += 1
	return n


## One meandering N–S river (2–4 tiles wide) with 1–2 walkable fords.
func _place_river() -> void:
	var width := rng.randi_range(2, 4)
	var ford_count := rng.randi_range(1, 2)
	# Ford Y positions between TCs band and south/north — avoid TC y≈17.
	var ford_ys: Array[int] = []
	var attempts := 0
	while ford_ys.size() < ford_count and attempts < 40:
		attempts += 1
		var fy := rng.randi_range(8, MAP_TILES - 9)
		if absi(fy - 17) < 6:
			continue
		var ok := true
		for existing in ford_ys:
			if absi(existing - fy) < 10:
				ok = false
				break
		if ok:
			ford_ys.append(fy)
	if ford_ys.is_empty():
		ford_ys.append(40)

	var cx := RIVER_CENTER_X
	for y in range(1, MAP_TILES - 1):
		# Gentle meander.
		var wobble := int(round(sin(float(y) * 0.18 + float(seed_value % 7)) * 2.0))
		var center := cx + wobble
		var half := width / 2
		var is_ford_row := false
		for fy in ford_ys:
			if absi(y - fy) <= 1:
				is_ford_row = true
				break
		for dx in range(-half, width - half):
			var t := Vector2i(center + dx, y)
			if not _in_bounds(t):
				continue
			# Keep TC clearings dry.
			if _near_any_tc(t, 10):
				continue
			if is_ford_row:
				WaterNav.set_ford(t)
				river_paint.append({"tile": t, "kind": "ford"})
			else:
				WaterNav.set_water(t)
				river_paint.append({"tile": t, "kind": "water"})
			_block(t)


func _place_fish_schools() -> void:
	var water_list: Array[Vector2i] = []
	for t in WaterNav.water_tiles.keys():
		water_list.append(t as Vector2i)
	if water_list.is_empty():
		return
	var count := rng.randi_range(FISH_SCHOOL_MIN, FISH_SCHOOL_MAX)
	var placed := 0
	var tries := 0
	while placed < count and tries < 80:
		tries += 1
		var t: Vector2i = water_list[rng.randi_range(0, water_list.size() - 1)]
		if not WaterNav.is_water(t):
			continue
		# Spread schools apart.
		var too_close := false
		for e in spawned:
			if str(e.get("type", "")) != "fish":
				continue
			if (e["pos"] as Vector2).distance_to(_world_of(t)) < float(TILE * 6):
				too_close = true
				break
		if too_close:
			continue
		_spawn_fish(t)
		placed += 1


func _spawn_fish(tile: Vector2i) -> void:
	if parent == null:
		return
	var node: ResourceNode = RESOURCE_SCENE.instantiate() as ResourceNode
	node.resource_type = "food"
	node.is_fish_school = true
	node.amount_remaining = FISH_AMOUNT
	node.position = _world_of(tile)
	parent.add_child(node)
	spawned.append({"type": "fish", "pos": node.position, "amount": FISH_AMOUNT})


func _place_tc_pack(tc: Vector2, mirror_x: bool) -> void:
	# Relative offsets in tiles from TC (within 12). Mirror flips X for enemy fairness.
	var forest_off := _mirror(Vector2i(7, -5), mirror_x)
	var berry_off := _mirror(Vector2i(-6, 4), mirror_x)
	var gold_off := _mirror(Vector2i(5, 6), mirror_x)
	var stone_off := _mirror(Vector2i(-7, -3), mirror_x)
	_place_forest_at(_tile_of(tc) + forest_off, FOREST_TREES)
	_place_berries_at(_tile_of(tc) + berry_off, BERRY_COUNT)
	_place_mine_at(_tile_of(tc) + gold_off, "gold", GOLD_PATCH_TILES, GOLD_PER_TILE)
	_place_mine_at(_tile_of(tc) + stone_off, "stone", STONE_PATCH_TILES, STONE_PER_TILE)


func _place_mirrored_forest() -> void:
	var left := _rand_tile_in_band(8, 34, 8, MAP_TILES - 8)
	var tries := 0
	while (not _can_cluster(left, 4) or _near_any_tc(left, 22)) and tries < 40:
		left = _rand_tile_in_band(8, 34, 8, MAP_TILES - 8)
		tries += 1
	var right := Vector2i(MAP_TILES - 1 - left.x, left.y)
	_place_forest_at(left, FOREST_TREES)
	_place_forest_at(right, FOREST_TREES)


func _place_mirrored_mine(kind: String) -> void:
	var left := _rand_tile_in_band(10, 32, 10, MAP_TILES - 10)
	var tries := 0
	while (not _can_cluster(left, 3) or _near_any_tc(left, 22)) and tries < 40:
		left = _rand_tile_in_band(10, 32, 10, MAP_TILES - 10)
		tries += 1
	var right := Vector2i(MAP_TILES - 1 - left.x, left.y)
	var tiles := GOLD_PATCH_TILES if kind == "gold" else STONE_PATCH_TILES
	var amt := GOLD_PER_TILE if kind == "gold" else STONE_PER_TILE
	_place_mine_at(left, kind, tiles, amt)
	_place_mine_at(right, kind, tiles, amt)


func _place_forest_at(center: Vector2i, count: int) -> void:
	## Organic blob via seeded per-tile noise + gaps (not a filled ring/grid).
	var scored: Array[Dictionary] = []
	var max_r := 6
	for dx in range(-max_r, max_r + 1):
		for dy in range(-max_r, max_r + 1):
			var t := center + Vector2i(dx, dy)
			if not _in_bounds(t) or _is_blocked(t):
				continue
			var dist := sqrt(float(dx * dx + dy * dy))
			var falloff := 1.0 - dist / float(max_r + 1)
			if falloff <= 0.08:
				continue
			var n := _tile_noise(t)
			# Gaps: reject noisy interior cells for irregular silhouette.
			if n > 0.28 + 0.62 * falloff:
				continue
			if n < 0.12 and falloff < 0.85:
				continue
			var score := falloff * 2.0 + (1.0 - n)
			scored.append({"t": t, "score": score})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["score"]) > float(b["score"])
	)
	var placed := 0
	for e in scored:
		if placed >= count:
			break
		var t: Vector2i = e["t"]
		if _is_blocked(t):
			continue
		_spawn_resource("wood", t, TREE_AMOUNT)
		placed += 1
	# Guarantee count with nearest free tiles (still skips blocked = paths/buildings).
	var radius := 0
	while placed < count and radius <= max_r + 2:
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				if placed >= count:
					return
				if absi(dx) != radius and absi(dy) != radius and radius > 0:
					continue
				var t2 := center + Vector2i(dx, dy)
				if not _in_bounds(t2) or _is_blocked(t2):
					continue
				_spawn_resource("wood", t2, TREE_AMOUNT)
				placed += 1
		radius += 1


func _tile_noise(tile: Vector2i) -> float:
	var h := int(seed_value) ^ (tile.x * 73856093) ^ (tile.y * 19349663)
	h = (h * 1103515245 + 12345) & 0x7fffffff
	return float(h % 10000) / 10000.0


func _place_berries_at(center: Vector2i, count: int) -> void:
	var offsets: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1),
		Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, 1),
		Vector2i(-1, 1), Vector2i(1, -1),
	]
	var placed := 0
	for o in offsets:
		if placed >= count:
			break
		var t := center + o
		if not _in_bounds(t) or _is_blocked(t):
			continue
		_spawn_resource("food", t, BERRY_AMOUNT)
		placed += 1


func _place_mine_at(center: Vector2i, kind: String, count: int, amount: int) -> void:
	var spiral: Array[Vector2i] = [
		Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
		Vector2i(2, 0), Vector2i(0, 2),
	]
	var placed := 0
	for o in spiral:
		if placed >= count:
			break
		var t := center + o
		if not _in_bounds(t) or _is_blocked(t):
			continue
		_spawn_resource(kind, t, amount)
		placed += 1


func _spawn_resource(kind: String, tile: Vector2i, amount: int) -> void:
	if parent == null or _is_blocked(tile):
		return
	var node: ResourceNode = RESOURCE_SCENE.instantiate() as ResourceNode
	node.resource_type = kind
	node.amount_remaining = amount
	node.position = _world_of(tile)
	parent.add_child(node)
	_block(tile)
	spawned.append({"type": kind, "pos": node.position, "amount": amount})


func _mirror(off: Vector2i, mirror_x: bool) -> Vector2i:
	return Vector2i(-off.x, off.y) if mirror_x else off


func _tile_of(world: Vector2) -> Vector2i:
	return Vector2i(int(floor(world.x / float(TILE))), int(floor(world.y / float(TILE))))


func _world_of(tile: Vector2i) -> Vector2:
	return Vector2(float(tile.x * TILE + TILE / 2), float(tile.y * TILE + TILE / 2))


func _block(tile: Vector2i) -> void:
	blocked[tile] = true


func _block_footprint(world: Vector2, radius_tiles: int) -> void:
	var c := _tile_of(world)
	for dx in range(-radius_tiles, radius_tiles + 1):
		for dy in range(-radius_tiles, radius_tiles + 1):
			_block(c + Vector2i(dx, dy))


func _is_blocked(tile: Vector2i) -> bool:
	return blocked.has(tile)


func _in_bounds(tile: Vector2i) -> bool:
	return tile.x >= 1 and tile.y >= 1 and tile.x < MAP_TILES - 1 and tile.y < MAP_TILES - 1


func _can_cluster(center: Vector2i, radius: int) -> bool:
	if not _in_bounds(center):
		return false
	var free := 0
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var t := center + Vector2i(dx, dy)
			if _in_bounds(t) and not _is_blocked(t):
				free += 1
	return free >= 8


func _near_any_tc(tile: Vector2i, radius: int) -> bool:
	# Approximate: avoid mid-map clusters too close to fixed TC tiles (22,17) / (52,17).
	var p := Vector2i(22, 17)
	var e := Vector2i(52, 17)
	return _chebyshev(tile, p) < radius or _chebyshev(tile, e) < radius


func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return maxi(absi(a.x - b.x), absi(a.y - b.y))


func _rand_tile_in_band(x0: int, x1: int, y0: int, y1: int) -> Vector2i:
	return Vector2i(rng.randi_range(x0, x1), rng.randi_range(y0, y1))
