extends Node2D
class_name FogOfWar
## AoE II-style fog: unexplored black, explored dark grey, in-sight clear.
## One ImageTexture overlay (not a node per tile). AI ignores fog. F9 disables.


const TILE := 40
const MAP_TILES := 75
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


func _ready() -> void:
	add_to_group("fog_of_war")
	z_index = 80
	name = "FogOfWar"
	_states.clear()
	_states.resize(MAP_TILES * MAP_TILES)
	for i in _states.size():
		_states[i] = STATE_UNEXPLORED
	_image = Image.create(MAP_TILES, MAP_TILES, false, Image.FORMAT_RGBA8)
	_image.fill(COLOR_UNEXPLORED)
	_texture = ImageTexture.create_from_image(_image)
	_sprite = Sprite2D.new()
	_sprite.centered = false
	_sprite.texture = _texture
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.scale = Vector2(TILE, TILE)
	_sprite.position = Vector2.ZERO
	add_child(_sprite)
	# First paint after entities spawn (Map awaits physics then spawns).
	call_deferred("force_update")


func _process(delta: float) -> void:
	if not fog_enabled:
		if _sprite.visible:
			_sprite.visible = false
			_reveal_all_enemy_units()
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
				_reveal_all_enemy_units()
			get_viewport().set_input_as_handled()


func force_update() -> void:
	_rebuild()


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


func _paint_sight(node: Node) -> void:
	if not (node is Node2D) or not is_instance_valid(node):
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
			_image.set_pixel(x, y, c)
	_texture.update(_image)


func _apply_enemy_unit_visibility(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group("enemy_units"):
		if not (n is CanvasItem) or not is_instance_valid(n):
			continue
		var unit := n as Node2D
		var show := is_world_visible(unit.global_position)
		_enemy_vis[unit.get_instance_id()] = show
		(unit as CanvasItem).visible = show


func _reveal_all_enemy_units() -> void:
	var tree := get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("enemy_units"):
		if n is CanvasItem and is_instance_valid(n):
			(n as CanvasItem).visible = true
	_enemy_vis.clear()
