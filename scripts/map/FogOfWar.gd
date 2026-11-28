extends Node2D
class_name FogOfWar
## AoE II-style fog: unexplored black, explored dark grey, in-sight clear.
## Soft-edged ImageTexture overlay (2× + blur + linear filter). AI ignores fog. F9 disables.


const TILE := 40
const MAP_TILES := 75
const OVERLAY_SCALE := 2 ## 2× fog tex → soft edges with blur + linear filter.
const UPDATE_INTERVAL := 0.2 ## ~5×/s
const STATE_UNEXPLORED := 0
const STATE_EXPLORED := 1
const STATE_VISIBLE := 2

## Dark grey overlay over explored-out-of-sight (buildings/resources stay readable).
const COLOR_UNEXPLORED := Color(0.0, 0.0, 0.0, 1.0)
const COLOR_EXPLORED := Color(0.08, 0.08, 0.1, 0.72)
const COLOR_VISIBLE := Color(0.0, 0.0, 0.0, 0.0)

var fog_enabled: bool = true
## Per-tile fog memory (0 unexplored / 1 explored / 2 visible).
var _states: Array[int] = []
var _image: Image
var _texture: ImageTexture
var _sprite: Sprite2D
var _accum: float = 0.0
## Enemy unit instance_id → last forced visibility (so we restore when fog off).
var _enemy_vis: Dictionary = {}
## Enemy buildings sighted at least once (last-known stays visible in explored grey).
var _seen_buildings: Dictionary = {}


func _ready() -> void:
	add_to_group("fog_of_war")
	z_index = 80
	name = "FogOfWar"
	_states.clear()
	_states.resize(MAP_TILES * MAP_TILES)
	for i in _states.size():
		_states[i] = STATE_UNEXPLORED
	var side := MAP_TILES * OVERLAY_SCALE
	_image = Image.create(side, side, false, Image.FORMAT_RGBA8)
	_image.fill(COLOR_UNEXPLORED)
	_texture = ImageTexture.create_from_image(_image)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = _texture
	# Linear + 2× softens tile boundaries (no stair-step fog).
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.scale = Vector2(float(TILE) / float(OVERLAY_SCALE), float(TILE) / float(OVERLAY_SCALE))
	_sprite.position = Vector2.ZERO
	add_child(_sprite)
	# First paint after entities spawn (Map awaits physics then spawns).
	call_deferred("force_update")


func _process(delta: float) -> void:
	if not fog_enabled:
		if _sprite.visible:
			_sprite.visible = false
			_reveal_all_enemies()
		return
	_sprite.visible = true
	_accum += delta
	if _accum < UPDATE_INTERVAL:
		return
	_accum = 0.0
	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key := event as InputEventKey
		if key.keycode == KEY_F9 or key.physical_keycode == KEY_F9:
			fog_enabled = not fog_enabled
			if fog_enabled:
				_accum = UPDATE_INTERVAL
				force_update()
			else:
				_sprite.visible = false
				_reveal_all_enemies()
			get_viewport().set_input_as_handled()


func force_update() -> void:
	_rebuild()


func uses_soft_edges() -> bool:
	return (
		_sprite != null
		and _sprite.texture_filter == CanvasItem.TEXTURE_FILTER_LINEAR
		and _image != null
		and _image.get_width() >= MAP_TILES * OVERLAY_SCALE
	)


func tile_state(tx: int, ty: int) -> int:
	if tx < 0 or ty < 0 or tx >= MAP_TILES or ty >= MAP_TILES:
		return STATE_UNEXPLORED
	return int(_states[ty * MAP_TILES + tx])


func world_to_tile(world: Vector2) -> Vector2i:
	return Vector2i(int(floor(world.x / float(TILE))), int(floor(world.y / float(TILE))))


func is_world_visible(world: Vector2) -> bool:
	if not fog_enabled:
		return true
	var t := world_to_tile(world)
	return tile_state(t.x, t.y) == STATE_VISIBLE


func is_world_explored(world: Vector2) -> bool:
	if not fog_enabled:
		return true
	var t := world_to_tile(world)
	return tile_state(t.x, t.y) != STATE_UNEXPLORED


## True when an enemy unit/building may be clicked / attacked / shown on minimap.
func is_enemy_targetable(node: Node) -> bool:
	if not fog_enabled:
		return true
	if node == null or not is_instance_valid(node) or not (node is Node2D):
		return false
	var n := node as Node2D
	if node is Unit:
		return is_world_visible(n.global_position)
	# Buildings / TCs: in sight now, or last-known after first sighting in explored fog.
	return is_enemy_building_revealed(n)


func is_enemy_building_revealed(node: Node2D) -> bool:
	if not fog_enabled:
		return true
	if node == null or not is_instance_valid(node):
		return false
	var id := node.get_instance_id()
	if is_world_visible(node.global_position):
		return true
	# Last-known: once sighted, stay visible while the tile remains explored.
	if bool(_seen_buildings.get(id, false)) and is_world_explored(node.global_position):
		return true
	return false


func sight_radius_px(node: Node) -> float:
	## LOS in tiles × 40: villager/soldiers 4, archer/cav 6, buildings 6, TC/castle 8, tower 9.
	if node is WatchTower:
		return 9.0 * float(TILE)
	if node is Castle:
		return 8.0 * float(TILE)
	if node is DropOff:
		return 8.0 * float(TILE)
	if node is Building:
		return 6.0 * float(TILE)
	if node is Unit:
		var u := node as Unit
		if "sight_range" in u and float(u.sight_range) > 0.0:
			# Prefer explicit unit sight when set (LightCavalry already 6 tiles).
			# Normalize known roles when default 200 px would be wrong.
			if u is Archer or u is LightCavalry or u is Knight:
				return 6.0 * float(TILE)
			if u is Villager or u is Soldier or u is Spearman or u is Monk:
				return 4.0 * float(TILE)
			if u.is_cavalry:
				return 6.0 * float(TILE)
			# Other military (unique infantry, siege): soldier-like 4.
			if u.can_attack:
				return 4.0 * float(TILE)
			return 4.0 * float(TILE)
		return 4.0 * float(TILE)
	return 0.0


func _rebuild() -> void:
	var tree := get_tree()
	if tree == null:
		return
	# Demote previous VISIBLE → EXPLORED (keep explored memory).
	for i in _states.size():
		if _states[i] == STATE_VISIBLE:
			_states[i] = STATE_EXPLORED

	for n in tree.get_nodes_in_group("player_units"):
		_paint_sight(n)
	for n in tree.get_nodes_in_group("player_buildings"):
		_paint_sight(n)
	for n in tree.get_nodes_in_group("player_town_hall"):
		_paint_sight(n)

	_upload_texture()
	_apply_enemy_unit_visibility(tree)
	_apply_enemy_building_visibility(tree)


func _paint_sight(node: Node) -> void:
	if not is_instance_valid(node) or not (node is Node2D):
		return
	if node is Building and not (node as Building).is_complete:
		return
	var radius := sight_radius_px(node)
	if radius <= 0.0:
		return
	var pos := (node as Node2D).global_position
	var center := world_to_tile(pos)
	var r_tiles := int(ceil(radius / float(TILE)))
	var r_sq := radius * radius
	for dy in range(-r_tiles, r_tiles + 1):
		for dx in range(-r_tiles, r_tiles + 1):
			var tx := center.x + dx
			var ty := center.y + dy
			if tx < 0 or ty < 0 or tx >= MAP_TILES or ty >= MAP_TILES:
				continue
			var tile_center := Vector2((float(tx) + 0.5) * float(TILE), (float(ty) + 0.5) * float(TILE))
			if pos.distance_squared_to(tile_center) > r_sq:
				continue
			_states[ty * MAP_TILES + tx] = STATE_VISIBLE


func _upload_texture() -> void:
	# Paint logical tiles into 2× overlay; LINEAR filter blends boundaries (no stair-steps).
	for y in MAP_TILES:
		for x in MAP_TILES:
			var st := int(_states[y * MAP_TILES + x])
			var c: Color
			match st:
				STATE_VISIBLE:
					c = COLOR_VISIBLE
				STATE_EXPLORED:
					c = COLOR_EXPLORED
				_:
					c = COLOR_UNEXPLORED
			# Soft edge: average with orthogonal neighbours into the half-texels.
			var ox := x * OVERLAY_SCALE
			var oy := y * OVERLAY_SCALE
			_image.set_pixel(ox, oy, _edge_color(x, y, c, -1, -1))
			_image.set_pixel(ox + 1, oy, _edge_color(x, y, c, 1, -1))
			_image.set_pixel(ox, oy + 1, _edge_color(x, y, c, -1, 1))
			_image.set_pixel(ox + 1, oy + 1, _edge_color(x, y, c, 1, 1))
	_texture.update(_image)


func _edge_color(tx: int, ty: int, base: Color, dx: int, dy: int) -> Color:
	## Blend this tile with its neighbour toward (dx,dy) so 2× texels soften borders.
	var nx := tx + (1 if dx > 0 else -1)
	var ny := ty + (1 if dy > 0 else -1)
	var cx := _state_color(tx, ny) if dy != 0 else base
	var cy := _state_color(nx, ty) if dx != 0 else base
	# Corner sample: mix self with the two orthogonal neighbours.
	return Color(
		(base.r + cx.r + cy.r) / 3.0,
		(base.g + cx.g + cy.g) / 3.0,
		(base.b + cx.b + cy.b) / 3.0,
		(base.a + cx.a + cy.a) / 3.0
	)


func _state_color(tx: int, ty: int) -> Color:
	var st := tile_state(tx, ty)
	match st:
		STATE_VISIBLE:
			return COLOR_VISIBLE
		STATE_EXPLORED:
			return COLOR_EXPLORED
		_:
			return COLOR_UNEXPLORED


func _apply_enemy_unit_visibility(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group("enemy_units"):
		if not is_instance_valid(n) or not (n is CanvasItem):
			continue
		var unit := n as Node2D
		var show := is_world_visible(unit.global_position)
		_enemy_vis[unit.get_instance_id()] = show
		(unit as CanvasItem).visible = show


func _apply_enemy_building_visibility(tree: SceneTree) -> void:
	var seen_ids: Dictionary = {}
	for group_name in ["enemy_buildings", "enemy_town_hall"]:
		for n in tree.get_nodes_in_group(group_name):
			if not is_instance_valid(n) or not (n is CanvasItem):
				continue
			var b := n as Node2D
			var id := b.get_instance_id()
			if seen_ids.has(id):
				continue
			seen_ids[id] = true
			if n is Building and not (n as Building).is_complete:
				(n as CanvasItem).visible = false
				continue
			# First sighting marks last-known; newly built in grey stays hidden until sighted.
			if is_world_visible(b.global_position):
				_seen_buildings[id] = true
				(n as CanvasItem).visible = true
			elif bool(_seen_buildings.get(id, false)) and is_world_explored(b.global_position):
				(n as CanvasItem).visible = true
			else:
				(n as CanvasItem).visible = false


func _reveal_all_enemies() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("enemy_units"):
		if is_instance_valid(n) and n is CanvasItem:
			(n as CanvasItem).visible = true
	for group_name in ["enemy_buildings", "enemy_town_hall"]:
		for n in tree.get_nodes_in_group(group_name):
			if is_instance_valid(n) and n is CanvasItem:
				(n as CanvasItem).visible = true
	_enemy_vis.clear()
