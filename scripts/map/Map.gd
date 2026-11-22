extends Node2D

const VILLAGER_SCENE := preload("res://scenes/units/Villager.tscn")
const RESOURCE_SCENE := preload("res://scenes/world/ResourceNode.tscn")
const DROPOFF_SCENE := preload("res://scenes/world/DropOff.tscn")
const SOLDIER_SCENE := preload("res://scenes/units/Soldier.tscn")
const ARCHER_SCENE := preload("res://scenes/units/Archer.tscn")
const BARRACKS_SCENE := preload("res://scenes/buildings/Barracks.tscn")
const PROJECTILE_SCENE := preload("res://scenes/combat/Projectile.tscn")

const TEX_GRASS_1 := preload("res://assets/sprites/terrain/grass_1.png")
const TEX_GRASS_2 := preload("res://assets/sprites/terrain/grass_2.png")
const TEX_DIRT := preload("res://assets/sprites/terrain/dirt.png")

const TILE := 40
const MAP_TILES := 75 # 3000 / 40
const SOURCE_GRASS_1 := 0
const SOURCE_GRASS_2 := 1
const SOURCE_DIRT := 2
const PLAYER_TC_POS := Vector2(900, 700)
const ENEMY_TC_POS := Vector2(2100, 700)
const MAP_SEED := 4242

@onready var units: Node2D = $Units
@onready var building_placer: BuildingPlacer = $BuildingPlacer
@onready var victory: VictoryController = $VictoryController

var map_generator: MapGenerator
var _dirt_tiles: Array[Vector2i] = []


func _ready() -> void:
	_setup_terrain()
	await get_tree().physics_frame
	await get_tree().physics_frame
	_spawn_core_demo()
	# Smoke tests only in headless — keeps normal play FPS clean.
	if DisplayServer.get_name() == "headless":
		await _run_friendly_target_smoke()
		await _run_gather_rmb_smoke()
		await _run_construction_smoke()
		await _run_projectile_smoke()
		await _run_archer_barracks_block_smoke()
		await _run_age_research_smoke()
		await _run_age_gate_smoke()
		await _run_age_locked_building_smoke()
		await _run_age2_to_age3_gate_smoke()
		await _run_age_ui_sync_smoke()
		await _run_civ_bonus_smoke()
		await _run_formation_smoke()
		await _run_ai_economy_smoke()
		await _run_hud_layout_smoke()
		await _run_victory_smoke()
		await _run_defeat_smoke()
		await _run_camera_minimap_smoke()
		await _run_map_mines_smoke()
		await _run_blacksmith_tech_smoke()
		await _run_stable_cavalry_smoke()
		await _run_castle_unique_smoke()
		await _run_walls_towers_smoke()
		print("[TEST] all headless smokes finished")
		get_tree().quit(0)
		return
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--hud-shot"):
		await prepare_hud_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--victory-shot"):
		await prepare_victory_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--camera-shot"):
		await prepare_camera_minimap_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--mines-shot"):
		await prepare_mines_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--blacksmith-shot"):
		await prepare_blacksmith_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--stable-shot"):
		await prepare_stable_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--castle-shot"):
		await prepare_castle_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--art-shot"):
		await prepare_art_pass_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--walls-shot"):
		await prepare_walls_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--art-v2-shot"):
		await prepare_art_v2_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--formation-shot"):
		await prepare_formation_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--ai-shot"):
		await prepare_ai_screenshot()
	else:
		await _sample_windowed_fps()
	NotificationManager.show_message("Start: Radnice + vesničané + zdroje. F3 debug.")


## Castle + stable + walls + cavalry (sprites v2).
func prepare_art_v2_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	for n in get_tree().get_nodes_in_group("player_town_hall"):
		if n is Node2D:
			(n as Node2D).visible = false
			(n as Node2D).position = Vector2(-4000, -4000)
	for n in get_tree().get_nodes_in_group("villagers"):
		if n is Villager and (n as Villager).team == 0:
			(n as Villager).visible = false
			(n as Villager).position = Vector2(-4000, -4000)
	GameManager.current_age = 3
	var origin := Vector2(820, 600)
	var castle: Castle = preload("res://scenes/buildings/Castle.tscn").instantiate() as Castle
	castle.team = 0
	castle.is_complete = true
	castle.spawn_parent = units
	castle.position = origin + Vector2(0, -40)
	units.add_child(castle)
	var stable: Stable = preload("res://scenes/buildings/Stable.tscn").instantiate() as Stable
	stable.team = 0
	stable.is_complete = true
	stable.spawn_parent = units
	stable.position = origin + Vector2(220, 40)
	units.add_child(stable)
	# Stone wall — gate — stone wall (continuous line).
	var wall_y := 120.0
	var line_x := 340.0
	for i in range(2):
		var left: WallSegment = preload("res://scenes/buildings/WallSegment.tscn").instantiate() as WallSegment
		left.wall_kind = "stone_wall"
		left.team = 0
		left.is_complete = true
		left.position = origin + Vector2(line_x + float(i) * 40.0, wall_y)
		units.add_child(left)
	var gate: Gate = preload("res://scenes/buildings/Gate.tscn").instantiate() as Gate
	gate.team = 0
	gate.orientation = "h"
	gate.is_complete = true
	gate.position = origin + Vector2(line_x + 120.0, wall_y)
	units.add_child(gate)
	for i in range(2):
		var right: WallSegment = preload("res://scenes/buildings/WallSegment.tscn").instantiate() as WallSegment
		right.wall_kind = "stone_wall"
		right.team = 0
		right.is_complete = true
		right.position = origin + Vector2(line_x + 200.0 + float(i) * 40.0, wall_y)
		units.add_child(right)
	# Short palisade north of the line.
	for i in range(3):
		var p: WallSegment = preload("res://scenes/buildings/WallSegment.tscn").instantiate() as WallSegment
		p.wall_kind = "palisade"
		p.team = 0
		p.is_complete = true
		p.position = origin + Vector2(line_x + 40.0 + float(i) * 40.0, wall_y - 78.0)
		units.add_child(p)
	# Tower snug behind the wall (just north of gate).
	var tower: WatchTower = preload("res://scenes/buildings/WatchTower.tscn").instantiate() as WatchTower
	tower.team = 0
	tower.is_complete = true
	tower.spawn_parent = units
	tower.position = origin + Vector2(line_x + 120.0, wall_y - 52.0)
	units.add_child(tower)
	var cav_defs: Array = [
		[preload("res://scenes/units/LightCavalry.tscn"), Vector2(100, 180)],
		[preload("res://scenes/units/Knight.tscn"), Vector2(180, 180)],
		[preload("res://scenes/units/Druzinik.tscn"), Vector2(260, 180)],
	]
	for row in cav_defs:
		var u: Unit = (row[0] as PackedScene).instantiate() as Unit
		u.team = 0
		u.contribute_population = false
		u.position = origin + (row[1] as Vector2)
		units.add_child(u)
	await get_tree().physics_frame
	for n in get_tree().get_nodes_in_group("walls") + get_tree().get_nodes_in_group("gates"):
		if n is Building:
			(n as Building)._refresh_label()
			(n as Building).queue_redraw()
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(0.85)
		cam.center_at(origin + Vector2(280, 60))
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame
	_save_shot("art_v2.png", 3)


## Palisade + stone wall–gate–wall + tower snug behind.
func prepare_walls_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	# Clear demo TC / villagers so labels don't clutter the fortification shot.
	for n in get_tree().get_nodes_in_group("player_town_hall"):
		if n is Node2D:
			(n as Node2D).visible = false
			(n as Node2D).position = Vector2(-4000, -4000)
	for n in get_tree().get_nodes_in_group("villagers"):
		if n is Villager and (n as Villager).team == 0:
			(n as Villager).visible = false
			(n as Villager).position = Vector2(-4000, -4000)
	GameManager.current_age = 2
	GameManager.add_resource("wood", 50)
	GameManager.add_resource("stone", 200)
	var origin := Vector2(1000, 700)
	# Palisade strip (behind / north).
	for i in range(6):
		var p: WallSegment = preload("res://scenes/buildings/WallSegment.tscn").instantiate() as WallSegment
		p.wall_kind = "palisade"
		p.team = 0
		p.is_complete = true
		p.position = origin + Vector2(float(i) * 40.0, -70.0)
		units.add_child(p)
	# Stone wall — gate — stone wall (continuous line).
	for i in range(2):
		var left: WallSegment = preload("res://scenes/buildings/WallSegment.tscn").instantiate() as WallSegment
		left.wall_kind = "stone_wall"
		left.team = 0
		left.is_complete = true
		left.position = origin + Vector2(float(i) * 40.0, 40.0)
		units.add_child(left)
	var gate: Gate = preload("res://scenes/buildings/Gate.tscn").instantiate() as Gate
	gate.team = 0
	gate.orientation = "h"
	gate.is_complete = true
	gate.position = origin + Vector2(120.0, 40.0)
	units.add_child(gate)
	for i in range(2):
		var right: WallSegment = preload("res://scenes/buildings/WallSegment.tscn").instantiate() as WallSegment
		right.wall_kind = "stone_wall"
		right.team = 0
		right.is_complete = true
		right.position = origin + Vector2(200.0 + float(i) * 40.0, 40.0)
		units.add_child(right)
	# Watch tower snug behind the wall (just north of gate).
	var tower: WatchTower = preload("res://scenes/buildings/WatchTower.tscn").instantiate() as WatchTower
	tower.team = 0
	tower.is_complete = true
	tower.spawn_parent = units
	tower.position = origin + Vector2(120.0, -10.0)
	units.add_child(tower)
	# Hide tower world label for this shot (caption below via SelectionInfo style — none).
	if tower.has_node("Label"):
		(tower.get_node("Label") as Label).visible = false
	await get_tree().physics_frame
	# Ensure fortifications don't show name/HP spam.
	for n in get_tree().get_nodes_in_group("walls") + get_tree().get_nodes_in_group("gates"):
		if n is Building:
			(n as Building)._refresh_label()
			(n as Building).queue_redraw()
	await get_tree().physics_frame
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(1.2)
		cam.center_at(origin + Vector2(120, 10))
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame
	_save_shot("walls.png", 0)


## All buildings side-by-side + labeled units (art pass). No TC overlap.
func prepare_art_pass_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	# Hide default demo TC / villagers so Barracks isn't stacked on Radnice.
	for n in get_tree().get_nodes_in_group("player_town_hall"):
		if n is Node2D:
			(n as Node2D).visible = false
			(n as Node2D).position = Vector2(-4000, -4000)
	for n in get_tree().get_nodes_in_group("villagers"):
		if n is Villager and (n as Villager).team == 0:
			(n as Villager).visible = false
			(n as Villager).position = Vector2(-4000, -4000)
	GameManager.current_age = 3
	GameManager.player_civ = CivData.MORAVANE
	GameManager.add_population_cap(40)
	# Spaced strip well clear of default TC spawn.
	var origin := Vector2(520, 420)
	var building_defs: Array = [
		[preload("res://scenes/buildings/House.tscn"), Vector2(0, 40)],
		[BARRACKS_SCENE, Vector2(140, 20)],
		[preload("res://scenes/buildings/Stable.tscn"), Vector2(300, 30)],
		[preload("res://scenes/buildings/LumberCamp.tscn"), Vector2(460, 30)],
		[preload("res://scenes/buildings/MiningCamp.tscn"), Vector2(620, 30)],
		[preload("res://scenes/buildings/Blacksmith.tscn"), Vector2(780, 10)],
		[preload("res://scenes/buildings/Castle.tscn"), Vector2(980, -30)],
	]
	for row in building_defs:
		var b: Building = (row[0] as PackedScene).instantiate() as Building
		b.team = 0
		b.position = origin + (row[1] as Vector2)
		b.is_complete = true
		if b is Castle:
			(b as Castle).spawn_parent = units
		units.add_child(b)
	await get_tree().physics_frame
	var unit_rows: Array = [
		[preload("res://scenes/units/Villager.tscn"), "Vesničan"],
		[SOLDIER_SCENE, "Zbrojnoš"],
		[preload("res://scenes/units/Spearman.tscn"), "Kopiník"],
		[ARCHER_SCENE, "Lučištník"],
		[preload("res://scenes/units/LightCavalry.tscn"), "Lehký jezdec"],
		[preload("res://scenes/units/Knight.tscn"), "Rytíř"],
		[preload("res://scenes/units/BojovnikBradatice.tscn"), "Bradatice"],
		[preload("res://scenes/units/Druzinik.tscn"), "Družiník"],
		[preload("res://scenes/units/ValecnyVuz.tscn"), "Válečný vůz"],
		[preload("res://scenes/units/Lancknecht.tscn"), "Lancknecht"],
	]
	var u_origin := origin + Vector2(20, 220)
	var i := 0
	for row in unit_rows:
		var u: Unit = (row[0] as PackedScene).instantiate() as Unit
		u.team = 0
		u.contribute_population = false
		var pos := u_origin + Vector2(float(i) * 72.0, 0.0)
		u.position = pos
		units.add_child(u)
		var lab := Label.new()
		lab.text = str(row[1])
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lab.position = Vector2(-36, 28)
		lab.size = Vector2(72, 18)
		lab.add_theme_font_size_override("font_size", 11)
		lab.add_theme_color_override("font_color", Color(1, 1, 1, 1))
		lab.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
		lab.add_theme_constant_override("outline_size", 3)
		u.add_child(lab)
		i += 1
	await get_tree().physics_frame
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(0.75)
		cam.center_at(origin + Vector2(520, 100))
	await get_tree().create_timer(0.6).timeout
	await get_tree().process_frame
	_save_shot("art_pass.png", unit_rows.size())


## Castle + unique unit (feature in action).
func prepare_castle_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	GameManager.current_age = 3
	GameManager.player_civ = CivData.MORAVANE
	GameManager.add_resource("food", 200)
	GameManager.add_resource("gold", 100)
	GameManager.add_resource("stone", 700)
	var castle: Castle = preload("res://scenes/buildings/Castle.tscn").instantiate() as Castle
	castle.team = 0
	castle.position = PLAYER_TC_POS + Vector2(220, 20)
	castle.is_complete = true
	castle.spawn_parent = units
	units.add_child(castle)
	await get_tree().physics_frame
	var unique: BojovnikBradatice = preload("res://scenes/units/BojovnikBradatice.tscn").instantiate() as BojovnikBradatice
	unique.team = 0
	unique.contribute_population = false
	unique.position = castle.global_position + Vector2(50, 90)
	units.add_child(unique)
	var enemy: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	enemy.team = 1
	enemy.contribute_population = false
	enemy.position = unique.global_position + Vector2(110, 10)
	units.add_child(enemy)
	await get_tree().physics_frame
	SelectionManager.select_building(castle)
	unique.command_attack(enemy)
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(1.0)
		cam.center_at((unique.global_position + castle.global_position) * 0.5)
	await get_tree().create_timer(0.9).timeout
	await get_tree().process_frame
	_save_shot("castle.png", 0)


## Stable + cavalry moving/fighting (feature in action).
func prepare_stable_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	GameManager.current_age = 2
	GameManager.add_resource("food", 300)
	GameManager.add_resource("wood", 200)
	var barracks: Barracks = BARRACKS_SCENE.instantiate() as Barracks
	barracks.team = 0
	barracks.position = PLAYER_TC_POS + Vector2(120, -40)
	barracks.is_complete = true
	barracks.spawn_parent = units
	units.add_child(barracks)
	var stable: Stable = preload("res://scenes/buildings/Stable.tscn").instantiate() as Stable
	stable.team = 0
	stable.position = PLAYER_TC_POS + Vector2(200, 40)
	stable.is_complete = true
	stable.spawn_parent = units
	units.add_child(stable)
	await get_tree().physics_frame
	var cav: LightCavalry = preload("res://scenes/units/LightCavalry.tscn").instantiate() as LightCavalry
	cav.team = 0
	cav.contribute_population = false
	cav.position = stable.global_position + Vector2(40, 50)
	units.add_child(cav)
	var enemy: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	enemy.team = 1
	enemy.contribute_population = false
	enemy.position = cav.global_position + Vector2(120, 20)
	units.add_child(enemy)
	await get_tree().physics_frame
	SelectionManager.select_building(stable)
	cav.command_attack(enemy)
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(1.0)
		cam.center_at((cav.global_position + stable.global_position) * 0.5)
	await get_tree().create_timer(0.9).timeout
	await get_tree().process_frame
	_save_shot("stable.png", 0)


## Blacksmith selected with research running (feature in action).
func prepare_blacksmith_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	GameManager.current_age = 2
	GameManager.add_resource("food", 200)
	var smith: Blacksmith = preload("res://scenes/buildings/Blacksmith.tscn").instantiate() as Blacksmith
	smith.team = 0
	smith.position = PLAYER_TC_POS + Vector2(140, 40)
	smith.is_complete = true
	units.add_child(smith)
	await get_tree().physics_frame
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(1.05)
		cam.center_at(smith.global_position)
	SelectionManager.select_building(smith)
	smith.enqueue_tech(TechData.FORGING)
	# Keep research visible (don't finish yet).
	smith.research_remaining = maxf(smith.research_remaining, 28.0)
	await get_tree().create_timer(0.6).timeout
	await get_tree().process_frame
	_save_shot("blacksmith.png", 0)


## Gold + stone mines with villagers mining (no overlapping world labels).
func prepare_mines_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	# Ensure world resource labels stay hidden.
	for n in get_tree().get_nodes_in_group("resources"):
		if n is ResourceNode:
			var lab := (n as ResourceNode).get_node_or_null("Label") as Label
			if lab:
				lab.visible = false
	var gold: ResourceNode = null
	var stone: ResourceNode = null
	for n in get_tree().get_nodes_in_group("gold_mines"):
		if n is ResourceNode and (n as ResourceNode).global_position.distance_to(PLAYER_TC_POS) < 12.0 * float(TILE):
			gold = n as ResourceNode
			break
	for n in get_tree().get_nodes_in_group("stone_mines"):
		if n is ResourceNode and (n as ResourceNode).global_position.distance_to(PLAYER_TC_POS) < 12.0 * float(TILE):
			stone = n as ResourceNode
			break
	var villagers: Array[Villager] = []
	for n in get_tree().get_nodes_in_group("player_units"):
		if n is Villager and (n as Villager).team == 0:
			villagers.append(n as Villager)
	while villagers.size() < 4:
		var v: Villager = VILLAGER_SCENE.instantiate() as Villager
		v.contribute_population = false
		v.position = PLAYER_TC_POS + Vector2(40, 40)
		units.add_child(v)
		villagers.append(v)
		await get_tree().physics_frame
	var focus := gold.global_position if gold else PLAYER_TC_POS
	if gold and stone:
		focus = (gold.global_position + stone.global_position) * 0.5
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(0.95)
		cam.center_at(focus)
	if gold:
		for i in mini(2, villagers.size()):
			villagers[i].global_position = gold.global_position + Vector2(18.0 + float(i) * 12.0, 8.0)
			villagers[i].assign_gather(gold)
	if stone and villagers.size() >= 3:
		for i in range(2, mini(4, villagers.size())):
			villagers[i].global_position = stone.global_position + Vector2(16.0 + float(i - 2) * 12.0, 8.0)
			villagers[i].assign_gather(stone)
	var pick: Array = []
	for i in mini(4, villagers.size()):
		pick.append(villagers[i])
	SelectionManager.select_multiple(pick)
	# Hover focus shows amount in SelectionInfo without world labels.
	if gold:
		SelectionManager.set_hovered_resource(gold)
	await get_tree().create_timer(1.0).timeout
	await get_tree().process_frame
	_save_shot("map_mines.png", pick.size())


## Camera moved + minimap frame visible (feature in action).
func prepare_camera_minimap_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	var cam := get_node_or_null("Camera2D") as RTSCamera
	var mini := get_node_or_null("UI/Minimap") as Minimap
	await get_tree().create_timer(0.3).timeout
	if cam:
		cam.set_zoom_clamped(0.85)
		cam.center_at(Vector2(1500, 1100))
	if mini:
		# Click-equivalent pan so the frame sits clearly elsewhere on the minimap.
		mini.move_camera_to_minimap(Vector2(110, 95))
	await get_tree().create_timer(0.4).timeout
	await get_tree().process_frame
	_save_shot("camera_minimap.png", 0)


## Windowed screenshot of victory overlay (enemy hall + units cleared).
func prepare_victory_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	var ai := get_node_or_null("SimpleEnemyAI") as SimpleEnemyAI
	if ai:
		ai.set_process(false)
	var victory := get_node_or_null("VictoryController") as VictoryController
	await get_tree().create_timer(0.4).timeout
	for n in get_tree().get_nodes_in_group("enemy_units"):
		if is_instance_valid(n):
			n.queue_free()
	await get_tree().physics_frame
	var enemy_hall := get_tree().get_first_node_in_group("enemy_town_hall") as DropOff
	if enemy_hall:
		enemy_hall.take_damage(enemy_hall.max_hp + 10.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if victory:
		victory.force_check()
	# Unpause so the viewport can present the overlay for capture.
	get_tree().paused = false
	await get_tree().create_timer(0.4, true, false, true).timeout
	await get_tree().process_frame
	_save_shot("victory.png", 0)


## Windowed screenshot of AoE-like HUD with a villager selected (build buttons).
func prepare_hud_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	var cam := get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.position = Vector2(900, 700)
		cam.zoom = Vector2(1.0, 1.0)
	await get_tree().create_timer(0.6).timeout
	var villager := get_tree().get_first_node_in_group("villagers") as Villager
	if villager and villager.team == 0:
		SelectionManager.select_single(villager)
	await get_tree().create_timer(0.8).timeout
	await get_tree().process_frame
	_save_shot("hud.png", 1)


## Windowed screenshot: 5 soldiers in Řada PERPENDICULAR to east march; hide DebugPanel.
func prepare_formation_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	var cam := get_node_or_null("Camera2D") as Camera2D
	var squad: Array = []
	# Stage already on perpendicular (N–S) so mid-walk still reads as Řada, not along-path.
	var origin := Vector2(820, 760)
	for i in 5:
		var s: Soldier = SOLDIER_SCENE.instantiate() as Soldier
		s.team = 0
		s.contribute_population = false
		s.position = origin + Vector2(0.0, float(i - 2) * 36.0)
		units.add_child(s)
		squad.append(s)
	await get_tree().physics_frame
	SelectionManager.select_multiple(squad)
	SelectionManager.set_formation(FormationData.LINE)
	SelectionManager.issue_move(Vector2(1080, 760)) # march east → line stays N–S
	await get_tree().create_timer(2.6).timeout
	var mid := Vector2.ZERO
	var n := 0
	for u in squad:
		if is_instance_valid(u):
			mid += (u as Node2D).global_position
			n += 1
	if n > 0:
		mid /= float(n)
	if cam:
		cam.position = mid + Vector2(20.0, 0.0)
		cam.zoom = Vector2(1.2, 1.2)
	await get_tree().process_frame
	await get_tree().process_frame
	_save_shot("pixel_art_line_perp.png", squad.size())


func prepare_ai_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	var cam := get_node_or_null("Camera2D") as Camera2D
	var ai := get_node_or_null("SimpleEnemyAI") as SimpleEnemyAI
	if cam and ai:
		cam.position = ai.base_position
		cam.zoom = Vector2(0.85, 0.85)
	await get_tree().create_timer(8.0).timeout
	if cam and ai:
		cam.position = ai.base_position + Vector2(-80, 40)
	await get_tree().process_frame
	_save_shot("pixel_art_ai_economy.png", 0)


func _save_shot(filename: String, squad_n: int) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 2:
		push_error("[SHOT] empty image")
		get_tree().quit(1)
		return
	var dir := "res://docs/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/%s" % [dir, filename]
	var save_err := img.save_png(path)
	if save_err != OK:
		push_error("[SHOT] save failed %s" % save_err)
		get_tree().quit(1)
		return
	print("[SHOT] saved %s %dx%d squad=%d" % [
		ProjectSettings.globalize_path(path), img.get_width(), img.get_height(), squad_n
	])
	get_tree().quit(0)



func _sample_windowed_fps() -> void:
	## Brief FPS sample for GamingRig verification (skipped in headless).
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("[FPS] renderer=%s adapter=%s display=%s" % [
		RenderingServer.get_current_rendering_method(),
		RenderingServer.get_video_adapter_name(),
		DisplayServer.get_name(),
	])
	await get_tree().create_timer(0.5).timeout
	var sum := 0.0
	var mn := 9999.0
	var mx := 0.0
	var n := 0
	var t0 := Time.get_ticks_msec()
	for _i in range(120):
		await get_tree().process_frame
		var fps := float(Engine.get_frames_per_second())
		if fps <= 0.0:
			continue
		sum += fps
		mn = minf(mn, fps)
		mx = maxf(mx, fps)
		n += 1
	var wall := maxf(float(Time.get_ticks_msec() - t0), 1.0) / 1000.0
	if n > 0:
		print("[FPS] windowed avg=%.1f min=%.1f max=%.1f wall=%.1f n=%d" % [
			sum / float(n), mn, mx, float(n) / wall, n
		])


func _setup_terrain() -> void:
	var old := get_node_or_null("Ground")
	if old:
		old.queue_free()

	var layer := TileMapLayer.new()
	layer.name = "Terrain"
	layer.z_index = -10
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.tile_set = _build_terrain_tileset()
	add_child(layer)
	move_child(layer, 0)

	# Per-tile seeded scatter (no big grass blocks); hash mix, no per-cell RNG reseed.
	for x in MAP_TILES:
		for y in MAP_TILES:
			var h := (x * 73856093) ^ (y * 19349663) ^ 4242
			var source_id := SOURCE_GRASS_1 if (h & 1) == 0 else SOURCE_GRASS_2
			layer.set_cell(Vector2i(x, y), source_id, Vector2i.ZERO)

	_dirt_tiles.clear()
	_paint_dirt_spur(layer, Vector2i(int(PLAYER_TC_POS.x) / TILE, int(PLAYER_TC_POS.y) / TILE), false)
	_paint_dirt_spur(layer, Vector2i(int(ENEMY_TC_POS.x) / TILE, int(ENEMY_TC_POS.y) / TILE), true)


func _paint_dirt_spur(layer: TileMapLayer, hall: Vector2i, mirror_x: bool) -> void:
	## 1-tile dirt south of TC, then spur toward nearby forest (mirrored for enemy).
	for i in range(2, 6):
		_set_dirt(layer, hall + Vector2i(0, i))
	var spur_y := 4
	var sx := -1 if mirror_x else 1
	for dx in range(1, 5):
		_set_dirt(layer, hall + Vector2i(sx * dx, spur_y))
	for dy in range(1, 3):
		_set_dirt(layer, hall + Vector2i(sx * 4, spur_y - dy))


func _set_dirt(layer: TileMapLayer, tile: Vector2i) -> void:
	layer.set_cell(tile, SOURCE_DIRT, Vector2i.ZERO)
	if not _dirt_tiles.has(tile):
		_dirt_tiles.append(tile)


func _build_terrain_tileset() -> TileSet:
	var tileset := TileSet.new()
	tileset.tile_size = Vector2i(TILE, TILE)
	var textures: Array[Texture2D] = [TEX_GRASS_1, TEX_GRASS_2, TEX_DIRT]
	for i in textures.size():
		var atlas := TileSetAtlasSource.new()
		atlas.texture = textures[i]
		atlas.texture_region_size = Vector2i(TILE, TILE)
		atlas.create_tile(Vector2i.ZERO)
		# grass_2 already brightness-matched — modulate 1.0 (default).
		tileset.add_source(atlas, i)
	return tileset


func _spawn_core_demo() -> void:
	# DESIGN start: Radnice + villagers; resources from seeded MapGenerator.
	var hall: DropOff = DROPOFF_SCENE.instantiate()
	hall.team = 0
	hall.position = PLAYER_TC_POS
	hall.spawn_parent = units
	units.add_child(hall)
	victory.watch_new_hall(hall)

	var enemy_hall: DropOff = DROPOFF_SCENE.instantiate()
	enemy_hall.team = 1
	enemy_hall.position = ENEMY_TC_POS
	enemy_hall.spawn_parent = units
	units.add_child(enemy_hall)
	victory.watch_new_hall(enemy_hall)

	for offset in [Vector2(40, 20), Vector2(20, 40), Vector2(60, 40)]:
		var villager: Villager = VILLAGER_SCENE.instantiate()
		villager.position = PLAYER_TC_POS + offset
		units.add_child(villager)

	for offset in [Vector2(40, 40), Vector2(60, 60), Vector2(20, 70)]:
		var ev: Villager = VILLAGER_SCENE.instantiate()
		ev.team = 1
		ev.contribute_population = false
		ev.position = ENEMY_TC_POS + offset
		units.add_child(ev)

	map_generator = MapGenerator.new()
	map_generator.generate(units, MAP_SEED, PLAYER_TC_POS, ENEMY_TC_POS, _dirt_tiles)


## Headless/manual regression: own buildings must not take friendly damage.
func _run_friendly_target_smoke() -> void:
	await get_tree().physics_frame
	var hall := get_tree().get_first_node_in_group("player_town_hall") as DropOff
	if hall == null:
		print("[TEST] FAIL no player town hall")
		return
	var hp_before := hall.hp

	var soldier: Soldier = SOLDIER_SCENE.instantiate()
	soldier.team = 0
	soldier.contribute_population = false
	soldier.position = hall.global_position + Vector2(40, 40)
	units.add_child(soldier)
	await get_tree().physics_frame

	soldier.command_attack(hall)
	await get_tree().create_timer(0.3).timeout

	var refused := soldier.attack_target == null
	var hp_ok := is_equal_approx(hall.hp, hp_before)
	print("[TEST] friendly_fire refused=%s hp_unchanged=%s (hp=%.1f)" % [refused, hp_ok, hall.hp])
	if not refused or not hp_ok:
		print("[TEST] FAIL friendly fire check")
	else:
		print("[TEST] PASS friendly fire check")

	var villager := get_tree().get_first_node_in_group("player_units") as Villager
	if villager:
		villager.command_attack(hall)
		print("[TEST] villager_attack_target_null=%s" % [villager.attack_target == null])
		villager.command_move(hall.global_position + Vector2(80, 0))
		await get_tree().physics_frame
		print("[TEST] villager_moving_state=%s" % [villager.state == Villager.State.MOVING])

	soldier.queue_free()


## RMB-style gather: issue_gather must enter harvest and reduce resource (not stay MOVING).
func _run_gather_rmb_smoke() -> void:
	await get_tree().physics_frame
	var wood: ResourceNode = null
	for n in get_tree().get_nodes_in_group("resources"):
		if n is ResourceNode and (n as ResourceNode).resource_type == "wood":
			wood = n as ResourceNode
			break
	var villagers: Array[Villager] = []
	for n in get_tree().get_nodes_in_group("villagers"):
		if n is Villager and (n as Villager).team == 0:
			villagers.append(n as Villager)
	if wood == null or villagers.is_empty():
		print("[TEST] FAIL gather setup missing wood/villagers")
		return

	# Place villagers near the node so navigation is not flaky in headless.
	for i in villagers.size():
		villagers[i].global_position = wood.global_position + Vector2(18.0 + float(i) * 10.0, 8.0)

	var amount_before := wood.amount_remaining
	SelectionManager.select_multiple(villagers)
	SelectionManager.issue_gather(wood)
	await get_tree().physics_frame

	var ordered := 0
	for v in villagers:
		if v.state == Villager.State.MOVE_TO_RESOURCE or v.state == Villager.State.HARVESTING:
			ordered += 1
	print("[TEST] gather_rmb ordered=%d/%d state0=%s" % [ordered, villagers.size(), villagers[0].state])

	var harvested := false
	for _i in range(40):
		await get_tree().create_timer(0.25).timeout
		if not is_instance_valid(wood):
			harvested = true
			break
		if wood.amount_remaining < amount_before:
			harvested = true
			break

	var amount_after := wood.amount_remaining if is_instance_valid(wood) else 0
	print("[TEST] gather_rmb amount %d -> %d harvested=%s" % [amount_before, amount_after, harvested])
	if ordered > 0 and harvested:
		print("[TEST] PASS gather after RMB adds resource progress")
	else:
		print("[TEST] FAIL gather after RMB")

	SelectionManager.issue_stop()
	await get_tree().physics_frame


## Place house under construction; villager builds; completes after timed progress.
func _run_construction_smoke() -> void:
	await get_tree().physics_frame
	var villager: Villager = null
	for n in get_tree().get_nodes_in_group("villagers"):
		if n is Villager and (n as Villager).team == 0:
			villager = n as Villager
			break
	if villager == null or building_placer == null:
		print("[TEST] FAIL construction setup")
		return

	SelectionManager.select_single(villager)
	var place_pos := Vector2(1100, 780)
	var house := building_placer.place_at("house", place_pos)
	if house == null:
		print("[TEST] FAIL house place")
		return

	# Keep DESIGN formula, but shorten base time so headless finishes quickly.
	house.build_time = 2.0
	villager.global_position = house.global_position + Vector2(30, 0)
	villager.assign_build(house)

	var started_incomplete := not house.is_complete and house.build_progress < 0.05
	var low_hp := house.hp <= house.max_hp * 0.15 + 0.01
	print("[TEST] construction placed incomplete=%s low_hp=%s progress=%.2f hp=%.1f" % [
		started_incomplete, low_hp, house.build_progress, house.hp
	])

	await get_tree().create_timer(0.4).timeout
	print("[TEST] construction villager_state=%s builders=%d" % [villager.state, house.builder_count()])

	var progressed := false
	var completed := false
	for _i in range(40):
		await get_tree().create_timer(0.25).timeout
		if not is_instance_valid(house):
			break
		if house.build_progress > 0.05:
			progressed = true
		if house.is_complete:
			completed = true
			break

	print("[TEST] construction progressed=%s completed=%s final_progress=%.2f" % [
		progressed,
		completed,
		house.build_progress if is_instance_valid(house) else -1.0
	])
	if started_incomplete and low_hp and progressed and completed:
		print("[TEST] PASS building completes after time")
	else:
		print("[TEST] FAIL construction smoke")


## Projectile deals damage on impact when target stays at aim point.
func _run_projectile_smoke() -> void:
	await get_tree().physics_frame
	var enemy: Soldier = SOLDIER_SCENE.instantiate()
	enemy.team = 1
	enemy.contribute_population = false
	enemy.position = Vector2(700, 600)
	units.add_child(enemy)
	await get_tree().physics_frame
	var hp_before := enemy.hp

	var proj: Projectile = PROJECTILE_SCENE.instantiate() as Projectile
	units.add_child(proj)
	var origin := enemy.global_position + Vector2(-120, 0)
	proj.setup(origin, enemy.global_position, 4.0, 0, enemy)

	var hit := false
	for _i in range(40):
		await get_tree().create_timer(0.05).timeout
		if not is_instance_valid(enemy):
			hit = true
			break
		if enemy.hp < hp_before - 0.1:
			hit = true
			break

	var hp_after := enemy.hp if is_instance_valid(enemy) else 0.0
	print("[TEST] projectile hp %.1f -> %.1f hit=%s" % [hp_before, hp_after, hit])
	if hit:
		print("[TEST] PASS projectile deals damage")
	else:
		print("[TEST] FAIL projectile deals damage")

	if is_instance_valid(enemy):
		enemy.queue_free()


## Archer cannot be trained at Barracks (moved to Strelnice).
func _run_archer_barracks_block_smoke() -> void:
	await get_tree().physics_frame
	GameManager.add_population_cap(10)
	GameManager.add_resource("wood", 50)
	GameManager.add_resource("gold", 50)

	var barracks: Barracks = BARRACKS_SCENE.instantiate()
	barracks.position = Vector2(500, 500)
	barracks.is_complete = true
	units.add_child(barracks)
	await get_tree().physics_frame

	var refused := not barracks.enqueue_unit("archer")
	var still_empty := barracks.queue.is_empty()
	print("[TEST] barracks_archer refused=%s queue_empty=%s" % [refused, still_empty])
	if refused and still_empty:
		print("[TEST] PASS Archer cannot train at Barracks")
	else:
		print("[TEST] FAIL Archer cannot train at Barracks")

	barracks.queue_free()


## Age research at Radnice completes and advances age; blocks villager train while researching.
func _run_age_research_smoke() -> void:
	await get_tree().physics_frame
	var hall := get_tree().get_first_node_in_group("player_town_hall") as DropOff
	if hall == null:
		print("[TEST] FAIL age research: no town hall")
		return

	# Ensure two age-1 buildings (construction smoke may have left a house).
	_ensure_complete_age1_buildings(2)
	GameManager.add_resource("food", 500)
	var age_before := GameManager.current_age
	if age_before != 1:
		print("[TEST] FAIL age research expected age 1, got %d" % age_before)
		return

	var started := hall.start_age_research(0.4)
	var blocked_train := not hall.enqueue_villager()
	print("[TEST] age_research started=%s blocked_train=%s researching=%s" % [
		started, blocked_train, hall.researching_age
	])
	if not started or not blocked_train or not hall.researching_age:
		print("[TEST] FAIL age research start")
		return

	var advanced := false
	for _i in range(30):
		await get_tree().create_timer(0.1).timeout
		if GameManager.current_age > age_before and not hall.researching_age:
			advanced = true
			break

	print("[TEST] age_research age %d -> %d advanced=%s" % [age_before, GameManager.current_age, advanced])
	if advanced and GameManager.current_age == 2:
		print("[TEST] PASS age research completes and changes age")
	else:
		print("[TEST] FAIL age research completes and changes age")


## Cannot start age research without 2 buildings from current age.
func _run_age_gate_smoke() -> void:
	await get_tree().physics_frame
	var hall := get_tree().get_first_node_in_group("player_town_hall") as DropOff
	if hall == null:
		print("[TEST] FAIL age gate: no town hall")
		return

	# Reset to age 1 with zero age-1 buildings (remove player buildings except hall).
	GameManager.current_age = 1
	for n in get_tree().get_nodes_in_group("player_buildings"):
		if n is DropOff:
			continue
		if is_instance_valid(n):
			n.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame

	GameManager.add_resource("food", 500)
	var count := GameManager.count_age_buildings(1)
	var refused := not hall.start_age_research(0.2)
	print("[TEST] age_gate buildings=%d refused=%s" % [count, refused])
	if refused and count < AgeData.BUILDINGS_REQUIRED_TO_ADVANCE and not hall.researching_age:
		print("[TEST] PASS cannot start research without 2 buildings")
	else:
		print("[TEST] FAIL cannot start research without 2 buildings")


## Locked building (archery_range in age 1) cannot be placed.
func _run_age_locked_building_smoke() -> void:
	await get_tree().physics_frame
	GameManager.current_age = 1
	GameManager.add_resource("wood", 200)
	var before_wood := GameManager.wood
	var placed := building_placer.place_at("archery_range", Vector2(400, 400))
	var unlocked_ok := GameManager.is_building_unlocked("archery_range") == false
	print("[TEST] locked_building placed=%s unlocked=%s wood %d -> %d" % [
		placed != null, not unlocked_ok, before_wood, GameManager.wood
	])
	if placed == null and unlocked_ok and GameManager.wood == before_wood:
		print("[TEST] PASS locked building cannot be placed")
	else:
		print("[TEST] FAIL locked building cannot be placed")
		if placed != null and is_instance_valid(placed):
			placed.queue_free()


## Age 2→3 gate: Střelnice + Kovárna satisfy the 2 age-2 buildings requirement.
func _run_age2_to_age3_gate_smoke() -> void:
	await get_tree().physics_frame
	var hall := get_tree().get_first_node_in_group("player_town_hall") as DropOff
	if hall == null:
		print("[TEST] FAIL age2 gate: no town hall")
		return

	# Clear non-hall buildings so age-2 count is exact.
	for n in get_tree().get_nodes_in_group("player_buildings"):
		if n is DropOff:
			continue
		if is_instance_valid(n):
			n.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame

	GameManager.current_age = 2
	var archery: Building = preload("res://scenes/buildings/ArcheryRange.tscn").instantiate() as Building
	archery.position = Vector2(300, 300)
	archery.is_complete = true
	units.add_child(archery)
	var smith: Building = preload("res://scenes/buildings/Blacksmith.tscn").instantiate() as Building
	smith.position = Vector2(420, 300)
	smith.is_complete = true
	units.add_child(smith)
	await get_tree().physics_frame

	var age2_count := GameManager.count_age_buildings(2)
	GameManager.add_resource("food", 800)
	GameManager.add_resource("gold", 200)
	var started := hall.start_age_research(0.3)
	print("[TEST] age2_gate buildings=%d started=%s" % [age2_count, started])

	var advanced := false
	for _i in range(30):
		await get_tree().create_timer(0.1).timeout
		if GameManager.current_age >= 3 and not hall.researching_age:
			advanced = true
			break

	print("[TEST] age2_gate age -> %d advanced=%s" % [GameManager.current_age, advanced])
	if age2_count >= 2 and started and advanced and GameManager.current_age == 3:
		print("[TEST] PASS age 2→3 gate with Střelnice + Kovárna")
	else:
		print("[TEST] FAIL age 2→3 gate with Střelnice + Kovárna")


## AgeLabel and research button must match GameManager.current_age.
func _run_age_ui_sync_smoke() -> void:
	await get_tree().physics_frame
	var panel := _find_command_panel()
	if panel == null:
		print("[TEST] FAIL age_ui: no CommandPanel")
		return

	GameManager.current_age = 1
	await get_tree().process_frame
	panel._refresh_age_ui()
	var label_ok_1 := panel.age_label.text.contains("Velká Morava") and panel.age_label.text.contains("(1)")
	var btn_ok_1 := panel.research_button.text.contains("Přemyslovci")
	print("[TEST] age_ui age1 label=%s btn=%s" % [panel.age_label.text, panel.research_button.text])

	GameManager.current_age = 2
	await get_tree().process_frame
	panel._refresh_age_ui()
	var label_ok_2 := panel.age_label.text.contains("Přemyslovci") and panel.age_label.text.contains("(2)")
	var btn_ok_2 := panel.research_button.text.contains("Husitství")
	print("[TEST] age_ui age2 label=%s btn=%s" % [panel.age_label.text, panel.research_button.text])

	if label_ok_1 and btn_ok_1 and label_ok_2 and btn_ok_2:
		print("[TEST] PASS age UI label/button match current_age")
	else:
		print("[TEST] FAIL age UI label/button match current_age")


func _find_command_panel() -> CommandPanel:
	var ui := get_node_or_null("UI")
	if ui == null:
		return null
	for c in ui.get_children():
		if c is CommandPanel:
			return c as CommandPanel
	return null


## Civ gather / wood-cost / infantry HP / Habsburkové stone.
func _run_civ_bonus_smoke() -> void:
	await get_tree().physics_frame
	GameManager.player_civ = CivData.MORAVANE
	var wood_m := GameManager.gather_rate_mult(0, "wood")
	var house_cost := GameManager.adjust_building_cost({"wood": 25}, 0)
	var wood_ok := is_equal_approx(wood_m, 1.15)
	var cost_ok := int(house_cost.get("wood", 0)) == 23 # 25 * 0.90 rounded
	print("[TEST] civ_moravane wood_mult=%.2f house_wood=%s" % [wood_m, house_cost.get("wood", 0)])

	GameManager.player_civ = CivData.HUSITE
	var soldier: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	soldier.team = 0
	soldier.contribute_population = false
	units.add_child(soldier)
	await get_tree().physics_frame
	var expect_hp := 45.0 * 1.10
	var hp_ok := is_equal_approx(soldier.max_hp, expect_hp)
	print("[TEST] civ_husite soldier_hp=%.1f expect=%.1f" % [soldier.max_hp, expect_hp])
	soldier.queue_free()

	GameManager.player_civ = CivData.HABSBURKOVE
	GameManager.player_civ = CivData.PREMYSLOVCI
	var gold_m := GameManager.gather_rate_mult(0, "gold")
	var gold_ok := is_equal_approx(gold_m, 1.15)
	print("[TEST] civ_premyslovci gold_mult=%.2f" % gold_m)

	GameManager.player_civ = CivData.HABSBURKOVE
	var stone_m := GameManager.gather_rate_mult(0, "stone")
	var stone_ok := is_equal_approx(stone_m, 1.10) and CivData.HABSBURKOVE == "habsburkove"
	print("[TEST] civ_habsburkove stone_mult=%.2f id=%s" % [stone_m, CivData.HABSBURKOVE])
	GameManager.player_civ = CivData.DEFAULT_PLAYER

	var ids_ok := true
	for civ_id in CivData.CIVS.keys():
		var id_str := str(civ_id)
		var named := CivData.civ_name(id_str)
		var own: Dictionary = CivData.CIVS[civ_id]
		var got := CivData.def_for(id_str)
		var row_ok := named != id_str and got == own
		print("[TEST] civ_id=%s name=%s own_def=%s" % [id_str, named, row_ok])
		if not row_ok:
			ids_ok = false

	GameManager.player_civ = CivData.MORAVANE
	GameManager.enemy_civ = CivData.HUSITE
	if wood_ok and cost_ok and hp_ok and gold_ok and stone_ok and ids_ok:
		print("[TEST] PASS civ bonuses (wood / cost / infantry HP / gold / stone / ids)")
	else:
		print("[TEST] FAIL civ bonuses (wood / cost / infantry HP / gold / stone / ids)")


## Formation spacing + shared speed + Řada perpendicular to march (|dot| < 0.2).
func _run_formation_smoke() -> void:
	await get_tree().physics_frame
	const SPEARMAN_SCENE := preload("res://scenes/units/Spearman.tscn")
	var a: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	var b: Spearman = SPEARMAN_SCENE.instantiate() as Spearman
	var c: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	a.team = 0
	b.team = 0
	c.team = 0
	a.contribute_population = false
	b.contribute_population = false
	c.contribute_population = false
	a.position = Vector2(500, 500)
	b.position = Vector2(520, 500)
	c.position = Vector2(540, 500)
	units.add_child(a)
	units.add_child(b)
	units.add_child(c)
	await get_tree().physics_frame

	SelectionManager.select_multiple([a, b, c])
	SelectionManager.set_formation(FormationData.LINE)
	var dest := Vector2(800, 500)
	var centroid := (a.global_position + b.global_position + c.global_position) / 3.0
	var facing := (dest - centroid).normalized()
	SelectionManager.issue_move(dest)
	await get_tree().physics_frame

	var gap := FormationData.spacing(FormationData.LINE)
	var targets: Array[Vector2] = []
	for u in [a, b, c]:
		if u.navigation_agent:
			targets.append(u.navigation_agent.target_position)
	targets.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.y < q.y)
	var pair_ds: Array[float] = []
	for i in targets.size():
		for j in range(i + 1, targets.size()):
			pair_ds.append(targets[i].distance_to(targets[j]))
	pair_ds.sort()
	var spacing_ok := pair_ds.size() == 3
	if spacing_ok:
		spacing_ok = (
			is_equal_approx(pair_ds[0], gap)
			and is_equal_approx(pair_ds[1], gap)
			and is_equal_approx(pair_ds[2], gap * 2.0)
		)
		print("[TEST] formation_line pairs=%.1f,%.1f,%.1f expect=%.1f,%.1f,%.1f" % [
			pair_ds[0], pair_ds[1], pair_ds[2], gap, gap, gap * 2.0
		])

	var perp_ok := targets.size() >= 2
	if perp_ok:
		var slot_vec := (targets[targets.size() - 1] - targets[0]).normalized()
		var dot_af := absf(slot_vec.dot(facing))
		perp_ok = dot_af < 0.2
		print("[TEST] formation_perp slot_dot_facing=%.3f (want <0.2)" % dot_af)

	var slowest := minf(a.speed, minf(b.speed, c.speed))
	var speed_ok := (
		is_equal_approx(a.effective_move_speed(), slowest)
		and is_equal_approx(b.effective_move_speed(), slowest)
		and is_equal_approx(c.effective_move_speed(), slowest)
	)
	print("[TEST] formation_speed slowest=%.1f a=%.1f b=%.1f c=%.1f" % [
		slowest, a.effective_move_speed(), b.effective_move_speed(), c.effective_move_speed()
	])

	for u in [a, b, c]:
		u.queue_free()
	SelectionManager.clear_selection()
	SelectionManager.set_formation(FormationData.LINE)

	if spacing_ok and speed_ok and perp_ok:
		print("[TEST] PASS formation spacing + shared speed + perpendicular")
	else:
		print("[TEST] FAIL formation spacing + shared speed + perpendicular")


## HUD: layout nodes + DebugPanel hidden; villager → build buttons; Kovárna locked in age 1.
func _run_hud_layout_smoke() -> void:
	await get_tree().physics_frame
	var ui := get_node_or_null("UI")
	var res := ui.get_node_or_null("ResourceBar") if ui else null
	var cmd := ui.get_node_or_null("CommandPanel") as CommandPanel if ui else null
	var sel := ui.get_node_or_null("SelectionInfo") if ui else null
	var mini := ui.get_node_or_null("Minimap") if ui else null
	var debug := get_node_or_null("DebugPanel")
	var nodes_ok: bool = res != null and cmd != null and sel != null and mini != null
	var debug_ok: bool = debug != null and not debug.visible
	print("[TEST] hud nodes res=%s cmd=%s sel=%s mini=%s debug_hidden=%s" % [
		res != null, cmd != null, sel != null, mini != null, debug_ok
	])

	GameManager.current_age = 1
	var villager: Villager = null
	for n in get_tree().get_nodes_in_group("villagers"):
		if n is Villager and (n as Villager).team == 0:
			villager = n as Villager
			break
	var build_ok := false
	var kovarna_locked := false
	if villager and cmd:
		SelectionManager.select_single(villager)
		await get_tree().process_frame
		cmd._refresh_context_ui()
		build_ok = cmd.is_build_row_visible()
		var kov := cmd.get_build_button("blacksmith")
		kovarna_locked = kov != null and kov.disabled
		print("[TEST] hud villager build_row=%s kovarna_disabled=%s tip=%s" % [
			build_ok, kovarna_locked, kov.tooltip_text if kov else ""
		])
	SelectionManager.clear_selection()

	# AoE-style: no permanent world labels; Czech names via info_line / SelectionInfo.
	var czech_ok := true
	var any_hidden := false
	for n in get_tree().get_nodes_in_group("resources"):
		if not (n is ResourceNode):
			continue
		var rn := n as ResourceNode
		var t := rn.get_node_or_null("Label") as Label
		if t != null and t.visible and not t.text.is_empty():
			czech_ok = false
		else:
			any_hidden = true
		if rn.resource_type == "wood" and not rn.czech_type_name().begins_with("Dřevo"):
			czech_ok = false
		if rn.resource_type == "food" and not rn.czech_type_name().begins_with("Jídlo"):
			czech_ok = false
		if rn.resource_type == "gold" and not rn.czech_type_name().begins_with("Zlato"):
			czech_ok = false
		if rn.resource_type == "stone" and not rn.czech_type_name().begins_with("Kámen"):
			czech_ok = false
	czech_ok = czech_ok and any_hidden
	print("[TEST] hud resource_info_no_world_labels=%s" % czech_ok)

	if nodes_ok and debug_ok and build_ok and kovarna_locked and czech_ok:
		print("[TEST] PASS HUD layout + villager builds + DebugPanel hidden")
	else:
		print("[TEST] FAIL HUD layout + villager builds + DebugPanel hidden")


## Stable training, Spearman vs cavalry bonus, Přemyslovci cav bonus, Knight age lock.
func _run_stable_cavalry_smoke() -> void:
	await get_tree().physics_frame
	GameManager.current_age = 2
	GameManager.add_resource("food", 400)
	GameManager.add_resource("wood", 400)
	GameManager.add_resource("gold", 200)

	var barracks: Barracks = BARRACKS_SCENE.instantiate() as Barracks
	barracks.team = 0
	barracks.position = PLAYER_TC_POS + Vector2(100, -60)
	barracks.is_complete = true
	barracks.spawn_parent = units
	units.add_child(barracks)
	await get_tree().physics_frame

	var stable: Stable = preload("res://scenes/buildings/Stable.tscn").instantiate() as Stable
	stable.team = 0
	stable.position = PLAYER_TC_POS + Vector2(180, 50)
	stable.is_complete = true
	stable.spawn_parent = units
	units.add_child(stable)
	await get_tree().physics_frame

	var food_before := GameManager.food
	var queued := stable.enqueue_unit("light_cavalry")
	var spend_ok := queued and GameManager.food == food_before - 80
	# Finish train quickly.
	stable.train_remaining = 0.0
	stable._complete_training()
	await get_tree().physics_frame
	var cav: LightCavalry = null
	for n in get_tree().get_nodes_in_group("cavalry"):
		if n is LightCavalry and (n as LightCavalry).team == 0:
			cav = n as LightCavalry
			break
	var train_ok := cav != null and is_equal_approx(cav.speed, 80.0 * 1.6)

	# Spearman +15 vs cavalry.
	var spear: Spearman = preload("res://scenes/units/Spearman.tscn").instantiate() as Spearman
	spear.team = 0
	spear.contribute_population = false
	spear.position = PLAYER_TC_POS + Vector2(60, 100)
	units.add_child(spear)
	await get_tree().physics_frame
	var dummy: LightCavalry = preload("res://scenes/units/LightCavalry.tscn").instantiate() as LightCavalry
	dummy.team = 1
	dummy.contribute_population = false
	dummy.position = spear.global_position + Vector2(30, 0)
	units.add_child(dummy)
	await get_tree().physics_frame
	var hp_before := dummy.hp
	# Simulate strike damage calc: base 3 + 15 bonus.
	var expected := 3.0 + 15.0
	dummy.take_damage(expected, "melee")
	var spear_bonus_ok := is_equal_approx(spear.bonus_vs_cavalry, 15.0) and dummy.hp <= hp_before - 1.0
	# Also verify Unit strike path applies bonus.
	var hp2 := dummy.hp
	spear.attack_target = dummy
	spear._try_strike()
	var strike_ok := dummy.hp < hp2 - 10.0 # 3+15 through armor 0

	# Přemyslovci +10% cavalry damage.
	GameManager.player_civ = CivData.PREMYSLOVCI
	var cav2: LightCavalry = preload("res://scenes/units/LightCavalry.tscn").instantiate() as LightCavalry
	cav2.team = 0
	cav2.contribute_population = false
	cav2.position = PLAYER_TC_POS + Vector2(40, 120)
	units.add_child(cav2)
	await get_tree().physics_frame
	var prem_ok := cav2.attack_damage >= 4.0 * 1.10 - 0.01
	GameManager.player_civ = CivData.DEFAULT_PLAYER

	# Knight locked under age 3.
	GameManager.current_age = 2
	var knight_locked := not GameManager.is_unit_unlocked("knight")
	var food_mid := GameManager.food
	var knight_q := stable.enqueue_unit("knight")
	var knight_block_ok := knight_locked and not knight_q and GameManager.food == food_mid
	GameManager.current_age = 3
	var knight_open := GameManager.is_unit_unlocked("knight")
	var food3 := GameManager.food
	var knight_q2 := stable.enqueue_unit("knight")
	var knight_ok := knight_open and knight_q2 and GameManager.food == food3 - 60 and GameManager.gold >= 0

	print(
		"[TEST] stable spend=%s train=%s spear=%s strike=%s prem=%s knight_lock=%s knight_age3=%s"
		% [spend_ok, train_ok, spear_bonus_ok, strike_ok, prem_ok, knight_block_ok, knight_ok]
	)
	if spend_ok and train_ok and spear_bonus_ok and strike_ok and prem_ok and knight_block_ok and knight_ok:
		print("[TEST] PASS stable cavalry + spearman + civ + age lock")
	else:
		print("[TEST] FAIL stable cavalry + spearman + civ + age lock")

	for n in [barracks, stable, spear, dummy, cav2]:
		if is_instance_valid(n):
			n.queue_free()


## Age 3 reachable, Castle arrows, civ-unique train only, building/cavalry bonuses.
func _run_castle_unique_smoke() -> void:
	await get_tree().physics_frame
	# Age 3 research cost from DESIGN (800J+200Z / 160s) + castle unlock.
	var age3_def: Dictionary = AgeData.AGE_RESEARCH.get(3, {})
	var age3_cost: Dictionary = age3_def.get("cost", {})
	var age_ok: bool = (
		int(age3_cost.get("food", 0)) == 800
		and int(age3_cost.get("gold", 0)) == 200
		and float(age3_def.get("time", 0.0)) >= 120.0
		and AgeData.building_unlock_age("castle") == 3
	)
	GameManager.current_age = 3
	GameManager.player_civ = CivData.MORAVANE
	GameManager.add_resource("food", 500)
	GameManager.add_resource("wood", 300)
	GameManager.add_resource("gold", 400)
	GameManager.add_resource("stone", 700)
	GameManager.add_population_cap(20)

	var castle: Castle = preload("res://scenes/buildings/Castle.tscn").instantiate() as Castle
	castle.team = 0
	castle.position = PLAYER_TC_POS + Vector2(200, 60)
	castle.is_complete = true
	castle.spawn_parent = units
	units.add_child(castle)
	await get_tree().physics_frame

	# Castle shoots enemy in range.
	var foe: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	foe.team = 1
	foe.contribute_population = false
	foe.position = castle.global_position + Vector2(120, 0)
	units.add_child(foe)
	var hp_before: float = foe.hp
	castle._attack_timer = 0.0
	castle._try_auto_attack()
	await get_tree().create_timer(0.35).timeout
	var shot_ok: bool = foe.hp < hp_before
	print("[TEST] castle_shot hp %.1f -> %.1f ok=%s" % [hp_before, foe.hp, shot_ok])

	# Each civ trains its unique and rejects others.
	var civ_train_ok: bool = true
	var spawned: Array = []
	for civ_id_v in CivData.ALL_CIV_IDS:
		var civ_id: String = str(civ_id_v)
		GameManager.player_civ = civ_id
		GameManager.add_resource("food", 200)
		GameManager.add_resource("wood", 200)
		GameManager.add_resource("gold", 200)
		var mine: String = CivData.unique_unit_id(civ_id)
		var ok_mine: bool = castle.enqueue_unit(mine)
		if not ok_mine:
			civ_train_ok = false
			print("[TEST] castle civ=%s failed own unique %s" % [civ_id, mine])
		for other_id_v in CivData.UNIQUE_UNITS.keys():
			var other_id: String = str(other_id_v)
			if other_id == mine:
				continue
			var food0: int = GameManager.food
			var blocked: bool = not castle.enqueue_unit(other_id)
			if not blocked or GameManager.food != food0:
				civ_train_ok = false
				print("[TEST] castle civ=%s wrongly accepted %s" % [civ_id, other_id])
		# Finish one train for later bonus checks.
		if not castle.queue.is_empty():
			castle.train_remaining = 0.0
			castle._complete_training()
			await get_tree().physics_frame
	for n in get_tree().get_nodes_in_group("soldiers"):
		if n is BojovnikBradatice or n is Druzinik or n is ValecnyVuz or n is Lancknecht:
			if (n as Unit).team == 0:
				spawned.append(n)

	# Building bonus: Bradaticar +8 vs buildings.
	GameManager.player_civ = CivData.MORAVANE
	var axe: BojovnikBradatice = preload("res://scenes/units/BojovnikBradatice.tscn").instantiate() as BojovnikBradatice
	axe.team = 0
	axe.contribute_population = false
	axe.position = PLAYER_TC_POS + Vector2(40, 160)
	units.add_child(axe)
	await get_tree().physics_frame
	var hut: Building = preload("res://scenes/buildings/House.tscn").instantiate() as Building
	hut.team = 1
	hut.position = axe.global_position + Vector2(30, 0)
	hut.is_complete = true
	units.add_child(hut)
	await get_tree().physics_frame
	var hut_hp := hut.hp
	axe.command_attack(hut)
	axe._attack_timer = 0.0
	axe._try_strike()
	var expect_build := axe.attack_damage + axe.bonus_vs_buildings
	var build_bonus_ok := is_equal_approx(axe.bonus_vs_buildings, 8.0) and hut.hp <= hut_hp - expect_build + 0.1
	print("[TEST] bradaticar vs building dealt~%.1f ok=%s" % [expect_build, build_bonus_ok])

	# Cavalry bonus: Lancknecht +10 vs cavalry.
	GameManager.player_civ = CivData.HABSBURKOVE
	var lanc: Lancknecht = preload("res://scenes/units/Lancknecht.tscn").instantiate() as Lancknecht
	lanc.team = 0
	lanc.contribute_population = false
	lanc.position = PLAYER_TC_POS + Vector2(80, 200)
	units.add_child(lanc)
	await get_tree().physics_frame
	var cav: LightCavalry = preload("res://scenes/units/LightCavalry.tscn").instantiate() as LightCavalry
	cav.team = 1
	cav.contribute_population = false
	cav.position = lanc.global_position + Vector2(30, 0)
	units.add_child(cav)
	await get_tree().physics_frame
	var cav_hp := cav.hp
	lanc.command_attack(cav)
	lanc._attack_timer = 0.0
	lanc._try_strike()
	var expect_cav := lanc.attack_damage + lanc.bonus_vs_cavalry - cav.melee_armor
	var cav_bonus_ok := is_equal_approx(lanc.bonus_vs_cavalry, 10.0) and cav.hp <= cav_hp - maxf(1.0, expect_cav) + 0.1
	print("[TEST] lancknecht vs cav ok=%s" % cav_bonus_ok)

	# Přemyslovci +10% on Družiník.
	GameManager.player_civ = CivData.PREMYSLOVCI
	var dru: Druzinik = preload("res://scenes/units/Druzinik.tscn").instantiate() as Druzinik
	dru.team = 0
	dru.contribute_population = false
	units.add_child(dru)
	await get_tree().physics_frame
	var prem_ok := dru.attack_damage >= 11.0 * 1.10 - 0.05
	print("[TEST] druzinik prem dmg=%.2f ok=%s" % [dru.attack_damage, prem_ok])

	var all_ok := age_ok and shot_ok and civ_train_ok and build_bonus_ok and cav_bonus_ok and prem_ok
	print(
		"[TEST] castle age=%s shot=%s civ=%s build=%s cav=%s prem=%s"
		% [age_ok, shot_ok, civ_train_ok, build_bonus_ok, cav_bonus_ok, prem_ok]
	)
	if all_ok:
		print("[TEST] PASS castle + unique units + bonuses")
	else:
		print("[TEST] FAIL castle + unique units + bonuses")

	for n in [castle, foe, axe, hut, lanc, cav, dru]:
		if is_instance_valid(n):
			n.queue_free()
	for n in spawned:
		if is_instance_valid(n):
			n.queue_free()


## Blacksmith techs: spend, apply to existing+new, armor min 1, no double research.
func _run_blacksmith_tech_smoke() -> void:
	await get_tree().physics_frame
	GameManager.current_age = 2
	GameManager.add_resource("food", 400)
	GameManager.add_resource("gold", 100)

	var smith: Blacksmith = preload("res://scenes/buildings/Blacksmith.tscn").instantiate() as Blacksmith
	smith.team = 0
	smith.position = PLAYER_TC_POS + Vector2(160, 60)
	smith.is_complete = true
	units.add_child(smith)
	await get_tree().physics_frame

	var soldier: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	soldier.team = 0
	soldier.contribute_population = false
	soldier.position = PLAYER_TC_POS + Vector2(80, 80)
	units.add_child(soldier)
	await get_tree().physics_frame
	var atk_before := soldier.attack_damage
	var armor_m_before := soldier.melee_armor
	var armor_p_before := soldier.pierce_armor

	var food_before := GameManager.food
	var started := smith.enqueue_tech(TechData.FORGING)
	var spent_ok := started and GameManager.food == food_before - 150
	# Force completion (headless process timing is flaky with pause/timers).
	if started:
		smith.research_remaining = 0.0
		smith._complete_research()
	await get_tree().process_frame
	var forging_ok := GameManager.has_tech(0, TechData.FORGING) and soldier.attack_damage >= atk_before + 0.99

	# Chain mail on same soldier.
	food_before = GameManager.food
	var started2 := smith.enqueue_tech(TechData.CHAIN_MAIL)
	if started2:
		smith.research_remaining = 0.0
		smith._complete_research()
	await get_tree().process_frame
	var mail_ok := (
		started2
		and GameManager.has_tech(0, TechData.CHAIN_MAIL)
		and soldier.melee_armor >= armor_m_before + 0.99
		and soldier.pierce_armor >= armor_p_before + 0.99
	)

	# New soldier inherits techs.
	var soldier2: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	soldier2.team = 0
	soldier2.contribute_population = false
	soldier2.position = PLAYER_TC_POS + Vector2(100, 100)
	units.add_child(soldier2)
	await get_tree().physics_frame
	var new_ok := soldier2.attack_damage >= 6.99 and soldier2.melee_armor >= 0.99

	# Armor reduces damage, floor 1.
	var hp_before := soldier2.hp
	soldier2.take_damage(3.0, "melee") # 3 - 1 armor = 2
	var reduced_ok := is_equal_approx(soldier2.hp, hp_before - 2.0)
	hp_before = soldier2.hp
	soldier2.take_damage(1.0, "melee") # 1 - 1 = 0 → min 1
	var min_ok := is_equal_approx(soldier2.hp, hp_before - 1.0)

	# Cannot research twice.
	var food_mid := GameManager.food
	var again := smith.enqueue_tech(TechData.FORGING)
	var twice_ok := not again and GameManager.food == food_mid

	print(
		"[TEST] blacksmith spent=%s forging=%s mail=%s new=%s dmg=%s min1=%s twice=%s"
		% [spent_ok, forging_ok, mail_ok, new_ok, reduced_ok, min_ok, twice_ok]
	)
	if spent_ok and forging_ok and mail_ok and new_ok and reduced_ok and min_ok and twice_ok:
		print("[TEST] PASS blacksmith techs + armor")
	else:
		print("[TEST] FAIL blacksmith techs + armor")

	soldier.queue_free()
	soldier2.queue_free()
	smith.queue_free()


## Seeded map: same seed → same layout; TC fairness; gold harvest + mining camp deposit.
func _run_map_mines_smoke() -> void:
	await get_tree().physics_frame
	if map_generator == null:
		print("[TEST] FAIL map_mines: no generator")
		return

	# Same seed → same fingerprint.
	var fp1 := map_generator.resource_fingerprint()
	var gen2 := MapGenerator.new()
	var holder := Node2D.new()
	add_child(holder)
	gen2.generate(holder, MAP_SEED, PLAYER_TC_POS, ENEMY_TC_POS, _dirt_tiles.duplicate())
	var fp2 := gen2.resource_fingerprint()
	var seed_ok := fp1 == fp2 and not fp1.is_empty()
	holder.queue_free()

	# TC packs within ~12 tiles; count slightly wider for organic forest edges.
	var fair_r := 14.0
	var wood_p := map_generator.count_near(PLAYER_TC_POS, "wood", fair_r)
	var wood_e := map_generator.count_near(ENEMY_TC_POS, "wood", fair_r)
	var food_p := map_generator.count_near(PLAYER_TC_POS, "food", fair_r)
	var food_e := map_generator.count_near(ENEMY_TC_POS, "food", fair_r)
	var gold_p := map_generator.count_near(PLAYER_TC_POS, "gold", fair_r)
	var gold_e := map_generator.count_near(ENEMY_TC_POS, "gold", fair_r)
	var stone_p := map_generator.count_near(PLAYER_TC_POS, "stone", fair_r)
	var stone_e := map_generator.count_near(ENEMY_TC_POS, "stone", fair_r)
	var fair_ok := (
		wood_p == wood_e and wood_p >= 20
		and food_p == food_e and food_p >= 6
		and gold_p == gold_e and gold_p >= 7
		and stone_p == stone_e and stone_p >= 5
	)
	print(
		"[TEST] map_seed_ok=%s fair wood=%d/%d food=%d/%d gold=%d/%d stone=%d/%d"
		% [seed_ok, wood_p, wood_e, food_p, food_e, gold_p, gold_e, stone_p, stone_e]
	)

	# Gold harvest + deposit at Mining Camp (spawn villager — defeat smoke may have cleared them).
	var gold_node: ResourceNode = null
	for n in get_tree().get_nodes_in_group("gold_mines"):
		if n is ResourceNode and (n as ResourceNode).global_position.distance_to(PLAYER_TC_POS) < 12.0 * float(TILE):
			gold_node = n as ResourceNode
			break
	var villager := get_tree().get_first_node_in_group("player_units") as Villager
	if villager == null:
		villager = VILLAGER_SCENE.instantiate() as Villager
		villager.contribute_population = false
		villager.position = PLAYER_TC_POS + Vector2(50, 50)
		units.add_child(villager)
		await get_tree().physics_frame
	var harvest_ok := false
	var deposit_ok := false
	if gold_node and villager:
		var camp: MiningCamp = preload("res://scenes/buildings/MiningCamp.tscn").instantiate() as MiningCamp
		camp.team = 0
		camp.position = gold_node.global_position + Vector2(70, 40)
		camp.is_complete = true
		units.add_child(camp)
		await get_tree().physics_frame
		var gold_before := GameManager.gold
		var amount_before := gold_node.amount_remaining
		villager.global_position = gold_node.global_position + Vector2(8, 0)
		villager.assign_gather(gold_node, camp)
		await get_tree().physics_frame
		# Skip flaky nav in headless — begin harvest in range.
		if villager.state == Villager.State.MOVE_TO_RESOURCE or villager.state == Villager.State.IDLE:
			villager._begin_harvest()
		# Gold rate ~0.36/s — seed accumulator so one physics tick yields a chunk.
		villager._harvest_accumulator = 2.0
		for _i in 30:
			await get_tree().physics_frame
			if not is_instance_valid(gold_node) or gold_node.amount_remaining < amount_before:
				harvest_ok = true
			if villager.carried_amount > 0:
				harvest_ok = true
				break
		if harvest_ok and villager.carried_amount > 0:
			villager.target_dropoff = camp
			villager.global_position = camp.global_position
			villager._deposit()
			await get_tree().process_frame
		deposit_ok = GameManager.gold > gold_before
		print(
			"[TEST] mines harvest=%s deposit=%s gold %d -> %d carried=%d state=%s"
			% [harvest_ok, deposit_ok, gold_before, GameManager.gold, villager.carried_amount, villager.state]
		)
	else:
		print("[TEST] FAIL map_mines setup missing gold/villager")

	var rate_ok := is_equal_approx(
		float(Villager.HARVEST_RATES["gold"]), Villager.WOOD_HARVEST_RATE * 0.9
	) and is_equal_approx(
		float(Villager.HARVEST_RATES["stone"]), Villager.WOOD_HARVEST_RATE * 0.9
	)
	var labels_hidden := true
	for n in get_tree().get_nodes_in_group("resources"):
		if not (n is ResourceNode):
			continue
		var lab := (n as ResourceNode).get_node_or_null("Label") as Label
		if lab != null and lab.visible and not str(lab.text).is_empty():
			labels_hidden = false
			break
	# SelectionInfo surfaces amount on resource focus.
	var info_ok := false
	if gold_node:
		SelectionManager.select_resource(gold_node)
		await get_tree().process_frame
		var sel := get_node_or_null("UI/SelectionInfo") as SelectionInfo
		info_ok = sel != null and sel.label != null and sel.label.text.contains("Zlato")
		SelectionManager.clear_resource_selection()
	print("[TEST] mines labels_hidden=%s selection_info=%s" % [labels_hidden, info_ok])
	var ok := seed_ok and fair_ok and harvest_ok and deposit_ok and rate_ok and labels_hidden and info_ok
	if ok:
		print("[TEST] PASS map mines seed/fairness/harvest/deposit")
	else:
		print("[TEST] FAIL map mines seed/fairness/harvest/deposit")


## Camera clamp + zoom limits + minimap LMB → camera position.
func _run_camera_minimap_smoke() -> void:
	await get_tree().physics_frame
	var cam := get_node_or_null("Camera2D") as RTSCamera
	var mini := get_node_or_null("UI/Minimap") as Minimap
	if cam == null or mini == null:
		print("[TEST] FAIL camera/minimap: missing nodes")
		return

	# Zoom limits 0.6–1.5
	cam.set_zoom_clamped(0.1)
	var zoom_lo_ok := is_equal_approx(cam.zoom.x, cam.min_zoom) and cam.min_zoom >= 0.59
	cam.set_zoom_clamped(9.0)
	var zoom_hi_ok := is_equal_approx(cam.zoom.x, cam.max_zoom) and cam.max_zoom <= 1.51
	cam.set_zoom_clamped(1.0)

	# Clamp to map: push far outside, then clamp.
	cam.position = Vector2(-5000, -5000)
	cam.clamp_position_now()
	var half := cam.view_half_extents()
	var clamp_lo_ok := (
		cam.position.x >= cam.map_rect.position.x + half.x - 0.5
		and cam.position.y >= cam.map_rect.position.y + half.y - 0.5
	)
	cam.position = Vector2(9000, 9000)
	cam.clamp_position_now()
	half = cam.view_half_extents()
	var clamp_hi_ok := (
		cam.position.x <= cam.map_rect.end.x - half.x + 0.5
		and cam.position.y <= cam.map_rect.end.y - half.y + 0.5
	)

	# Minimap click → camera near mapped world point.
	cam.set_zoom_clamped(1.0)
	var local := Vector2(111, 64) # ~75% x, 50% y of 148×128 draw
	var target := mini.minimap_to_world(local)
	mini.move_camera_to_minimap(local)
	await get_tree().process_frame
	var cam_ok := cam.position.distance_to(target) < 8.0
	# Re-clamp may nudge if near edges; for mid-map target should match.
	if not cam_ok:
		# Allow clamp-adjusted center for half-extents.
		cam_ok = cam.position.distance_to(Vector2(
			clampf(target.x, cam.map_rect.position.x + half.x, cam.map_rect.end.x - half.x),
			clampf(target.y, cam.map_rect.position.y + half.y, cam.map_rect.end.y - half.y)
		)) < 8.0

	var edge_ok := is_equal_approx(cam.edge_margin, 20.0)
	var ok := zoom_lo_ok and zoom_hi_ok and clamp_lo_ok and clamp_hi_ok and cam_ok and edge_ok
	print(
		"[TEST] camera zoom_lo=%s zoom_hi=%s clamp_lo=%s clamp_hi=%s minimap=%s edge=%s"
		% [zoom_lo_ok, zoom_hi_ok, clamp_lo_ok, clamp_hi_ok, cam_ok, edge_ok]
	)
	if ok:
		print("[TEST] PASS camera clamp + zoom + minimap click")
	else:
		print("[TEST] FAIL camera clamp + zoom + minimap click")


## Win = enemy hall down + no enemy units; overlay Vítězství!
func _run_victory_smoke() -> void:
	await get_tree().physics_frame
	var victory := get_node_or_null("VictoryController") as VictoryController
	var ai := get_node_or_null("SimpleEnemyAI") as SimpleEnemyAI
	if victory == null:
		print("[TEST] FAIL victory: no VictoryController")
		return
	if ai:
		ai.set_process(false)
	victory.reset_for_test()
	for n in get_tree().get_nodes_in_group("enemy_units"):
		if is_instance_valid(n):
			n.queue_free()
	await get_tree().physics_frame
	var enemy_hall := get_tree().get_first_node_in_group("enemy_town_hall") as DropOff
	if enemy_hall == null:
		print("[TEST] FAIL victory: no enemy hall")
		return
	enemy_hall.take_damage(enemy_hall.max_hp + 10.0)
	await get_tree().physics_frame
	await get_tree().physics_frame
	victory.force_check()
	await get_tree().process_frame
	var overlay := victory.get_overlay()
	var title_ok := false
	if overlay:
		var title := overlay.find_child("EndTitle", true, false) as Label
		title_ok = title != null and title.text.contains("Vítězství")
	var ok := victory.ended and victory.player_won and title_ok
	print("[TEST] victory ended=%s won=%s title_ok=%s" % [victory.ended, victory.player_won, title_ok])
	if ok:
		print("[TEST] PASS victory overlay")
	else:
		print("[TEST] FAIL victory overlay")
	victory.reset_for_test()


## Loss = player hall down + no player units; overlay Porážka.
func _run_defeat_smoke() -> void:
	await get_tree().physics_frame
	var victory := get_node_or_null("VictoryController") as VictoryController
	if victory == null:
		print("[TEST] FAIL defeat: no VictoryController")
		return
	victory.reset_for_test()
	# Keep a spare unit list; free player units after hall dies.
	var player_hall := get_tree().get_first_node_in_group("player_town_hall") as DropOff
	if player_hall == null:
		print("[TEST] FAIL defeat: no player hall")
		return
	player_hall.take_damage(player_hall.max_hp + 10.0)
	await get_tree().physics_frame
	for n in get_tree().get_nodes_in_group("player_units"):
		if is_instance_valid(n):
			n.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	victory.force_check()
	await get_tree().process_frame
	var overlay := victory.get_overlay()
	var title_ok := false
	if overlay:
		var title := overlay.find_child("EndTitle", true, false) as Label
		title_ok = title != null and title.text.contains("Porážka")
	var ok := victory.ended and not victory.player_won and title_ok
	print("[TEST] defeat ended=%s won=%s title_ok=%s" % [victory.ended, victory.player_won, title_ok])
	if ok:
		print("[TEST] PASS defeat overlay")
	else:
		print("[TEST] FAIL defeat overlay")
	victory.reset_for_test()


## AI economy: places ≥1 building and launches a wave within timeout (Husité).
func _run_ai_economy_smoke() -> void:
	var ai := get_node_or_null("SimpleEnemyAI") as SimpleEnemyAI
	if ai == null:
		print("[TEST] FAIL ai_economy: no SimpleEnemyAI")
		return
	# Wait for bootstrap + house/barracks (3s each) + 3×1.2s train + wave.
	var placed := false
	var waved := false
	for _i in range(80):
		await get_tree().create_timer(0.35).timeout
		placed = ai.has_placed_building()
		waved = ai.has_launched_wave()
		if placed and waved:
			break
	print("[TEST] ai_economy placed=%s waved=%s food=%d wood=%d gold=%d" % [
		placed, waved, ai.food, ai.wood, ai.gold
	])
	if placed and waved:
		print("[TEST] PASS AI places building and launches wave")
	else:
		print("[TEST] FAIL AI places building and launches wave")


## Walls: segment cost, path block, gate pass own/block enemy, tower shot, repair.
func _run_walls_towers_smoke() -> void:
	await get_tree().physics_frame
	GameManager.current_age = 2
	GameManager.food = 200
	GameManager.wood = 200
	GameManager.gold = 100
	GameManager.stone = 200

	# 1) Segment cost — place 3 palisade tiles via placer API.
	var wood_before := GameManager.wood
	var tiles: Array[Vector2i] = [
		WallNav.world_to_tile(PLAYER_TC_POS + Vector2(200, -80)),
		WallNav.world_to_tile(PLAYER_TC_POS + Vector2(240, -80)),
		WallNav.world_to_tile(PLAYER_TC_POS + Vector2(280, -80)),
	]
	var placed: Array = building_placer.place_wall_line("palisade", tiles)
	var cost_ok: bool = placed.size() == 3 and GameManager.wood == wood_before - 6
	# Finish walls instantly for path tests.
	for s in placed:
		if s is WallSegment:
			(s as WallSegment).is_complete = true
			(s as WallSegment).build_progress = 1.0
			(s as WallSegment).hp = (s as WallSegment).max_hp
			(s as WallSegment)._show_final_visual()
			(s as WallSegment)._ensure_blocker()
	await get_tree().physics_frame
	print("[TEST] wall_cost placed=%d wood %d->%d ok=%s" % [
		placed.size(), wood_before, GameManager.wood, cost_ok
	])

	# 2) Wall tile blocks; short wall can be pathed around; sealed box has no path.
	var occ := WallNav.occupancy_map(get_tree())
	var tile_blocked: bool = WallNav.is_tile_blocked(tiles[1], 1, occ)
	var around_ok: bool = WallNav.path_exists(
		PLAYER_TC_POS + Vector2(240, 40),
		PLAYER_TC_POS + Vector2(240, -160),
		1,
		get_tree()
	)
	# 3×3 ring enclosure — inside cannot reach outside.
	var box_c := WallNav.world_to_tile(PLAYER_TC_POS + Vector2(600, 200))
	var box_tiles: Array[Vector2i] = []
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			box_tiles.append(box_c + Vector2i(dx, dy))
	GameManager.wood += 40
	var box_walls: Array = []
	# place_wall_line is Bresenham — place each ring tile individually.
	for bt in box_tiles:
		var one: Array[Vector2i] = [bt]
		box_walls.append_array(building_placer.place_wall_line("palisade", one))
	for s in box_walls:
		if s is WallSegment:
			(s as WallSegment).is_complete = true
			(s as WallSegment).hp = (s as WallSegment).max_hp
			(s as WallSegment)._ensure_blocker()
	await get_tree().physics_frame
	var sealed: bool = not WallNav.path_exists(
		WallNav.tile_center(box_c),
		WallNav.tile_center(box_c + Vector2i(5, 0)),
		1,
		get_tree()
	)
	var nearest := WallNav.nearest_blocking_segment(
		WallNav.tile_center(box_c),
		WallNav.tile_center(box_c + Vector2i(5, 0)),
		1,
		get_tree()
	)
	var blocked: bool = tile_blocked and around_ok and sealed and nearest is WallSegment
	print("[TEST] wall_blocks tile=%s around=%s sealed=%s nearest=%s ok=%s" % [
		tile_blocked, around_ok, sealed, nearest != null, blocked
	])

	# 3) Gate: own units pass through gate tiles; enemies blocked on those tiles.
	var stone_tiles: Array[Vector2i] = []
	for i in range(5):
		stone_tiles.append(WallNav.world_to_tile(PLAYER_TC_POS + Vector2(400.0 + float(i) * 40.0, -80.0)))
	GameManager.stone += 50
	var stone_wall: Array = building_placer.place_wall_line("stone_wall", stone_tiles)
	for s in stone_wall:
		if s is WallSegment:
			(s as WallSegment).is_complete = true
			(s as WallSegment).hp = (s as WallSegment).max_hp
			(s as WallSegment)._ensure_blocker()
	await get_tree().physics_frame
	var gate_anchor := stone_tiles[1]
	var gate: Gate = building_placer.place_gate_at(WallNav.tile_center(gate_anchor), "h") as Gate
	var gate_placed: bool = gate != null
	if gate:
		gate.is_complete = true
		gate.hp = gate.max_hp
		gate._ensure_blocker()
	await get_tree().physics_frame
	var occ2 := WallNav.occupancy_map(get_tree())
	var gate_mid := gate_anchor + Vector2i(1, 0)
	var own_pass: bool = not WallNav.is_tile_blocked(gate_mid, 0, occ2)
	var enemy_block: bool = WallNav.is_tile_blocked(gate_mid, 1, occ2)
	print("[TEST] gate placed=%s own_pass=%s enemy_block=%s" % [gate_placed, own_pass, enemy_block])

	# 4) Tower shoots.
	var tower: WatchTower = preload("res://scenes/buildings/WatchTower.tscn").instantiate() as WatchTower
	tower.team = 0
	tower.is_complete = true
	tower.spawn_parent = units
	tower.position = PLAYER_TC_POS + Vector2(120, 120)
	units.add_child(tower)
	var foe: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	foe.team = 1
	foe.contribute_population = false
	foe.position = tower.global_position + Vector2(80, 0)
	units.add_child(foe)
	var hp0: float = foe.hp
	tower._attack_timer = 0.0
	tower._try_auto_attack()
	await get_tree().create_timer(0.35).timeout
	var tower_ok: bool = foe.hp < hp0
	print("[TEST] tower_shot hp %.1f -> %.1f ok=%s" % [hp0, foe.hp, tower_ok])

	# 5) Repair restores HP and deducts resources.
	var hut: Building = preload("res://scenes/buildings/House.tscn").instantiate() as Building
	hut.team = 0
	hut.is_complete = true
	hut.placed_cost = {"wood": 25}
	hut.position = PLAYER_TC_POS + Vector2(-120, 80)
	units.add_child(hut)
	await get_tree().physics_frame
	hut.hp = hut.max_hp * 0.5
	var wood_r0 := GameManager.wood
	var repaired := hut.apply_repair(10.0)
	var wood_r1 := GameManager.wood
	var repair_ok: bool = repaired > 0.0 and hut.hp > hut.max_hp * 0.5 and wood_r1 < wood_r0
	print("[TEST] repair +%.1f HP wood %d->%d ok=%s" % [repaired, wood_r0, wood_r1, repair_ok])

	var all_ok: bool = cost_ok and blocked and gate_placed and own_pass and enemy_block and tower_ok and repair_ok
	# DESIGN values spot-check
	var design_ok: bool = (
		int(BuildingPlacer.COSTS["palisade"].get("wood", 0)) == 2
		and int(BuildingPlacer.COSTS["stone_wall"].get("stone", 0)) == 5
		and int(BuildingPlacer.COSTS["gate"].get("stone", 0)) == 30
		and int(BuildingPlacer.COSTS["watch_tower"].get("stone", 0)) == 125
		and float(BuildingPlacer.BUILD_TIMES["palisade"]) == 5.0
		and AgeData.building_unlock_age("palisade") == 1
		and AgeData.building_unlock_age("stone_wall") == 2
		and AgeData.building_unlock_age("watch_tower") == 2
	)
	all_ok = all_ok and design_ok
	print("[TEST] walls design_ok=%s" % design_ok)
	if all_ok:
		print("[TEST] PASS walls + towers + repair")
	else:
		print("[TEST] FAIL walls + towers + repair")

	for n in placed + stone_wall + box_walls + [gate, tower, foe, hut]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	await get_tree().physics_frame


func _ensure_complete_age1_buildings(need: int) -> void:
	var have := GameManager.count_age_buildings(1)
	if have >= need:
		return
	var scenes := [
		preload("res://scenes/buildings/House.tscn"),
		preload("res://scenes/buildings/LumberCamp.tscn"),
		preload("res://scenes/buildings/Mill.tscn"),
		preload("res://scenes/buildings/Barracks.tscn"),
	]
	var idx := 0
	while GameManager.count_age_buildings(1) < need and idx < scenes.size():
		var b: Building = scenes[idx].instantiate() as Building
		b.position = Vector2(200.0 + float(idx) * 100.0, 200.0)
		b.is_complete = true
		units.add_child(b)
		idx += 1
	# House grants pop on finish path; force complete buildings already ready.
	for n in get_tree().get_nodes_in_group("player_buildings"):
		if n is Building and (n as Building).is_complete == false:
			(n as Building).is_complete = true
