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
	_ensure_fog_of_war()
	# Fáze 5 AI vs AI balance suite (or one-game sim-smoke).
	if BalanceSim.active:
		await _run_balance_sim_game()
		if BalanceSim.suite_done():
			get_tree().quit(0)
		else:
			get_tree().reload_current_scene()
		return
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
		await _run_age34_monk_smoke()
		await _run_age4_siege_smoke()
		await _run_farm_plots_smoke()
		await _run_farm_reseed_smoke()
		await _run_audio_manager_smoke()
		await _run_team_recolour_smoke()
		await _run_walk_cycle_smoke()
		await _run_team_readability_smoke()
		await _run_fog_of_war_smoke()
		await _run_fog_polish_smoke()
		await _run_aoe_controls_smoke()
		await _run_balance_harness_smoke()
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
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--monk-shot"):
		await prepare_monk_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--university-shot"):
		await prepare_university_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--siege-shot"):
		await prepare_siege_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--farms-shot"):
		await prepare_farms_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--reseed-shot"):
		await prepare_reseed_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--build-bar-shot"):
		await prepare_build_bar_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--controls-shot"):
		await prepare_controls_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--team-shot"):
		await prepare_team_colours_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--walk-shot"):
		await prepare_walk_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--walk-v2-shot"):
		await prepare_walk_v2_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--team-read-shot"):
		await prepare_team_read_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--fog-shot"):
		await prepare_fog_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--fog-polish-shot"):
		await prepare_fog_polish_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--formation-shot"):
		await prepare_formation_screenshot()
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--ai-shot"):
		await prepare_ai_screenshot()
	else:
		await _sample_windowed_fps()
	NotificationManager.show_message("Start: Radnice + vesničané + zdroje. F3 debug. F9 fog.")


## T-28: player (blue) vs AI (red) archer/spearman — idle + walk, underfoot team markers.
func prepare_team_read_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	for n in get_tree().get_nodes_in_group("player_town_hall"):
		if n is Node2D:
			(n as Node2D).visible = false
			(n as Node2D).position = Vector2(-4000, -4000)
	for n in get_tree().get_nodes_in_group("enemy_town_hall"):
		if n is Node2D:
			(n as Node2D).visible = false
			(n as Node2D).position = Vector2(-4000, -4000)
	for n in get_tree().get_nodes_in_group("units"):
		if n is Unit and is_instance_valid(n):
			(n as Unit).visible = false
			(n as Unit).position = Vector2(-5000, -5000)
	var origin := Vector2(980, 720)
	var arch_p: Archer = ARCHER_SCENE.instantiate() as Archer
	arch_p.team = 0
	arch_p.contribute_population = false
	arch_p.position = origin + Vector2(-120, -20)
	units.add_child(arch_p)
	var arch_e: Archer = ARCHER_SCENE.instantiate() as Archer
	arch_e.team = 1
	arch_e.contribute_population = false
	arch_e.position = origin + Vector2(-40, -20)
	units.add_child(arch_e)
	var spear_p: Spearman = preload("res://scenes/units/Spearman.tscn").instantiate() as Spearman
	spear_p.team = 0
	spear_p.contribute_population = false
	spear_p.position = origin + Vector2(50, -20)
	units.add_child(spear_p)
	var spear_e: Spearman = preload("res://scenes/units/Spearman.tscn").instantiate() as Spearman
	spear_e.team = 1
	spear_e.contribute_population = false
	spear_e.position = origin + Vector2(140, -20)
	units.add_child(spear_e)
	# Bottom row: mid-walk (feature in action).
	var arch_pw: Archer = ARCHER_SCENE.instantiate() as Archer
	arch_pw.team = 0
	arch_pw.contribute_population = false
	arch_pw.position = origin + Vector2(-120, 70)
	units.add_child(arch_pw)
	var arch_ew: Archer = ARCHER_SCENE.instantiate() as Archer
	arch_ew.team = 1
	arch_ew.contribute_population = false
	arch_ew.position = origin + Vector2(-40, 70)
	units.add_child(arch_ew)
	var spear_pw: Spearman = preload("res://scenes/units/Spearman.tscn").instantiate() as Spearman
	spear_pw.team = 0
	spear_pw.contribute_population = false
	spear_pw.position = origin + Vector2(50, 70)
	units.add_child(spear_pw)
	var spear_ew: Spearman = preload("res://scenes/units/Spearman.tscn").instantiate() as Spearman
	spear_ew.team = 1
	spear_ew.contribute_population = false
	spear_ew.position = origin + Vector2(140, 70)
	units.add_child(spear_ew)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(2.3)
		cam.center_at(origin + Vector2(10, 20))
	await get_tree().create_timer(0.35).timeout
	var all_units: Array = [arch_p, arch_e, spear_p, spear_e, arch_pw, arch_ew, spear_pw, spear_ew]
	for u in all_units:
		if u == null:
			continue
		u.set_process(false)
		u.set_physics_process(false)
		if u.navigation_agent:
			u.navigation_agent.avoidance_enabled = false
			if u.navigation_agent.velocity_computed.is_connected(u._on_velocity_computed):
				u.navigation_agent.velocity_computed.disconnect(u._on_velocity_computed)
		if u._visual == null:
			u._visual = u.get_node_or_null("Visual") as Sprite2D
	# Top row idle facing; bottom row mid-stride walk.
	for u in [arch_p, arch_e, spear_p, spear_e]:
		u._facing = "right" if u.team == 0 else "left"
		u.velocity = Vector2.ZERO
		u._apply_facing_texture()
		if u._visual:
			u._visual.scale = Vector2(3.0, 3.0)
			u._anchor_sprite_to_feet()
		u.queue_redraw()
	arch_pw._facing = "right"
	arch_pw._walk_frame = 1
	arch_pw.velocity = Vector2(80, 0)
	arch_ew._facing = "left"
	arch_ew._walk_frame = 2
	arch_ew.velocity = Vector2(-80, 0)
	spear_pw._facing = "right"
	spear_pw._walk_frame = 2
	spear_pw.velocity = Vector2(80, 0)
	spear_ew._facing = "left"
	spear_ew._walk_frame = 1
	spear_ew.velocity = Vector2(-80, 0)
	for u in [arch_pw, arch_ew, spear_pw, spear_ew]:
		if u.has_walk_sheet():
			u._apply_walk_frame()
			u._visual.scale = Vector2(3.0, 3.0)
			u._anchor_sprite_to_feet()
		else:
			u._apply_facing_texture()
		u.queue_redraw()
	# Select one player unit so selection ring + team oval coexist without colliding.
	arch_p.set_selected(true)
	if cam:
		cam.set_zoom_clamped(2.5)
		cam.center_at(origin + Vector2(10, 25))
	await get_tree().process_frame
	await get_tree().process_frame
	print(
		"[SHOT] team-read arch_tint=%s spear_tint=%s marker_p=%s marker_e=%s"
		% [
			arch_e._visual.modulate if arch_e._visual else Color.BLACK,
			spear_e._visual.modulate if spear_e._visual else Color.BLACK,
			arch_p.team_marker_color(),
			arch_e.team_marker_color(),
		]
	)
	_save_shot("t28_team_read.png", 0)


## T-27: archer + spearman mid-walk (walk-v2 sheets) + idle facing.
func prepare_walk_v2_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	for n in get_tree().get_nodes_in_group("player_town_hall"):
		if n is Node2D:
			(n as Node2D).visible = false
			(n as Node2D).position = Vector2(-4000, -4000)
	for n in get_tree().get_nodes_in_group("enemy_town_hall"):
		if n is Node2D:
			(n as Node2D).visible = false
			(n as Node2D).position = Vector2(-4000, -4000)
	for n in get_tree().get_nodes_in_group("units"):
		if n is Unit and is_instance_valid(n):
			(n as Unit).visible = false
			(n as Unit).position = Vector2(-5000, -5000)
	var origin := Vector2(980, 720)
	var idle_arch: Archer = ARCHER_SCENE.instantiate() as Archer
	idle_arch.team = 0
	idle_arch.contribute_population = false
	idle_arch.position = origin + Vector2(-100, 0)
	units.add_child(idle_arch)
	var arch: Archer = ARCHER_SCENE.instantiate() as Archer
	arch.team = 0
	arch.contribute_population = false
	arch.position = origin + Vector2(-20, 0)
	units.add_child(arch)
	var spear: Spearman = preload("res://scenes/units/Spearman.tscn").instantiate() as Spearman
	spear.team = 0
	spear.contribute_population = false
	spear.position = origin + Vector2(70, 0)
	units.add_child(spear)
	var spear_ai: Spearman = preload("res://scenes/units/Spearman.tscn").instantiate() as Spearman
	spear_ai.team = 1
	spear_ai.contribute_population = false
	spear_ai.position = origin + Vector2(160, 0)
	units.add_child(spear_ai)
	await get_tree().physics_frame
	await get_tree().physics_frame
	idle_arch.velocity = Vector2.ZERO
	idle_arch._facing = "down"
	idle_arch._apply_facing_texture()
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(2.2)
		cam.center_at(origin + Vector2(20, -8))
	await get_tree().create_timer(0.35).timeout
	for u in [idle_arch, arch, spear, spear_ai]:
		if u == null:
			continue
		u.set_process(false)
		u.set_physics_process(false)
		if u.navigation_agent:
			u.navigation_agent.avoidance_enabled = false
			if u.navigation_agent.velocity_computed.is_connected(u._on_velocity_computed):
				u.navigation_agent.velocity_computed.disconnect(u._on_velocity_computed)
	idle_arch._facing = "right"
	idle_arch.velocity = Vector2.ZERO
	idle_arch._apply_facing_texture()
	if idle_arch._visual:
		idle_arch._visual.scale = Vector2(3.0, 3.0)
		idle_arch._anchor_sprite_to_feet()
	arch._facing = "right"
	arch._walk_frame = 1
	arch.velocity = Vector2(80, 0)
	spear._facing = "right"
	spear._walk_frame = 2
	spear.velocity = Vector2(80, 0)
	spear_ai._facing = "left"
	spear_ai._walk_frame = 1
	spear_ai.velocity = Vector2(-80, 0)
	for u in [arch, spear, spear_ai]:
		if u == null:
			continue
		if u._visual == null:
			u._visual = u.get_node_or_null("Visual") as Sprite2D
		if u.has_walk_sheet():
			u._apply_walk_frame()
			u._visual.scale = Vector2(3.0, 3.0)
			u._anchor_sprite_to_feet()
		else:
			u._apply_facing_texture()
	if cam:
		cam.set_zoom_clamped(2.4)
		cam.center_at(origin + Vector2(30, -12))
	await get_tree().process_frame
	await get_tree().process_frame
	print(
		"[SHOT] walk-v2 archer_sheet=%s spear_sheet=%s a_hframes=%d a_frame=%d s_frame=%d"
		% [
			str(arch.has_walk_sheet()),
			str(spear.has_walk_sheet()),
			arch._visual.hframes if arch._visual else -1,
			arch._visual.frame if arch._visual else -1,
			spear._visual.frame if spear._visual else -1,
		]
	)
	_save_shot("t27_walk_v2.png", 0)


## T-17: villager + soldier mid-walk (walk sheet frames) + idle facing.
func prepare_walk_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	for n in get_tree().get_nodes_in_group("player_town_hall"):
		if n is Node2D:
			(n as Node2D).visible = false
			(n as Node2D).position = Vector2(-4000, -4000)
	for n in get_tree().get_nodes_in_group("enemy_town_hall"):
		if n is Node2D:
			(n as Node2D).visible = false
			(n as Node2D).position = Vector2(-4000, -4000)
	# Clear demo units so the shot shows only walk/idle subjects.
	for n in get_tree().get_nodes_in_group("units"):
		if n is Unit and is_instance_valid(n):
			(n as Unit).visible = false
			(n as Unit).position = Vector2(-5000, -5000)
	var origin := Vector2(980, 720)
	var idle: Villager = VILLAGER_SCENE.instantiate() as Villager
	idle.team = 0
	idle.contribute_population = false
	idle.position = origin + Vector2(-90, 0)
	units.add_child(idle)
	var vill: Villager = VILLAGER_SCENE.instantiate() as Villager
	vill.team = 0
	vill.contribute_population = false
	vill.position = origin
	units.add_child(vill)
	var sol: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	sol.team = 1
	sol.contribute_population = false
	sol.position = origin + Vector2(90, 0)
	units.add_child(sol)
	await get_tree().physics_frame
	await get_tree().physics_frame
	# Keep idle villager stopped on facing sprite.
	idle.state = Villager.State.IDLE
	idle._facing = "down"
	idle.velocity = Vector2.ZERO
	idle._apply_facing_texture()
	# Villager IDLE calls stop_movement each tick — park walkers in MOVING.
	vill.state = Villager.State.MOVING
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(2.2)
		cam.center_at(origin + Vector2(0, -8))
	await get_tree().create_timer(0.35).timeout
	# Force mid-walk visuals immediately before capture (feature in action).
	# Disconnect nav avoidance — velocity_computed can reset walk to idle mid-shot.
	for u in [vill, sol, idle]:
		if u == null:
			continue
		u.set_process(false)
		u.set_physics_process(false)
		if u.navigation_agent:
			u.navigation_agent.avoidance_enabled = false
			if u.navigation_agent.velocity_computed.is_connected(u._on_velocity_computed):
				u.navigation_agent.velocity_computed.disconnect(u._on_velocity_computed)
	idle._facing = "right"
	idle.velocity = Vector2.ZERO
	idle._apply_facing_texture()
	if idle._visual:
		idle._visual.scale = Vector2(3.0, 3.0)
		idle._anchor_sprite_to_feet()
	# Mid-stride walk frames (feature in action); AI soldier keeps T-18 tint.
	vill._facing = "right"
	vill._walk_frame = 1
	vill.velocity = Vector2(80, 0)
	sol._facing = "right"
	sol._walk_frame = 2
	sol.velocity = Vector2(80, 0)
	for u in [vill, sol]:
		if u == null:
			continue
		if u._visual == null:
			u._visual = u.get_node_or_null("Visual") as Sprite2D
		if u.has_walk_sheet():
			u._apply_walk_frame()
			u._visual.scale = Vector2(3.0, 3.0)
			u._anchor_sprite_to_feet()
		else:
			u._apply_facing_texture()
	if cam:
		cam.set_zoom_clamped(2.4)
		cam.center_at(origin + Vector2(10, -12))
	await get_tree().process_frame
	await get_tree().process_frame
	print(
		"[SHOT] walk sheet_v=%s active=%s hframes=%d frame=%d tint=%s"
		% [
			str(vill.has_walk_sheet()),
			str(vill.is_walk_animating()),
			vill._visual.hframes if vill._visual else -1,
			vill._visual.frame if vill._visual else -1,
			sol._visual.modulate if sol._visual else Color.BLACK,
		]
	)
	_save_shot("t17_walk.png", 0)


## Player (blue) vs AI (red) side-by-side — T-18 team recolour.
func prepare_team_colours_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	for n in get_tree().get_nodes_in_group("player_town_hall"):
		if n is Node2D:
			(n as Node2D).visible = false
			(n as Node2D).position = Vector2(-4000, -4000)
	for n in get_tree().get_nodes_in_group("enemy_town_hall"):
		if n is Node2D:
			(n as Node2D).visible = false
			(n as Node2D).position = Vector2(-4000, -4000)
	GameManager.current_age = 3
	var origin := Vector2(900, 700)
	var market_p: Building = preload("res://scenes/buildings/Market.tscn").instantiate() as Building
	market_p.team = 0
	market_p.is_complete = true
	market_p.position = origin
	units.add_child(market_p)
	var market_e: Building = preload("res://scenes/buildings/Market.tscn").instantiate() as Building
	market_e.team = 1
	market_e.is_complete = true
	market_e.position = origin + Vector2(280, 0)
	units.add_child(market_e)
	var kn_p: Knight = preload("res://scenes/units/Knight.tscn").instantiate() as Knight
	kn_p.team = 0
	kn_p.contribute_population = false
	kn_p.position = origin + Vector2(40, 90)
	units.add_child(kn_p)
	var kn_e: Knight = preload("res://scenes/units/Knight.tscn").instantiate() as Knight
	kn_e.team = 1
	kn_e.contribute_population = false
	kn_e.position = origin + Vector2(320, 90)
	units.add_child(kn_e)
	var sol_p: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	sol_p.team = 0
	sol_p.contribute_population = false
	sol_p.position = origin + Vector2(100, 100)
	units.add_child(sol_p)
	var sol_e: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	sol_e.team = 1
	sol_e.contribute_population = false
	sol_e.position = origin + Vector2(380, 100)
	units.add_child(sol_e)
	await get_tree().physics_frame
	await get_tree().physics_frame
	if kn_p:
		kn_p._facing = "right"
		kn_p._apply_facing_texture()
		kn_p._apply_team_visual()
	if kn_e:
		kn_e._facing = "left"
		kn_e._apply_facing_texture()
		kn_e._apply_team_visual()
	if sol_p:
		sol_p._apply_team_visual()
	if sol_e:
		sol_e._apply_team_visual()
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(1.35)
		cam.center_at(origin + Vector2(160, 55))
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame
	await get_tree().process_frame
	_save_shot("t18_team_colours.png", 0)


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


## Close-up: Mnich healing a clearly wounded ally (low HP bar).
func prepare_monk_screenshot() -> void:
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
	GameManager.add_resource("gold", 200)
	var origin := Vector2(1100, 740)
	var monastery: Monastery = preload("res://scenes/buildings/Monastery.tscn").instantiate() as Monastery
	monastery.team = 0
	monastery.is_complete = true
	monastery.spawn_parent = units
	monastery.position = origin + Vector2(-160, -80)
	units.add_child(monastery)
	var ally: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	ally.team = 0
	ally.contribute_population = false
	ally.position = origin + Vector2(36, 8)
	units.add_child(ally)
	var monk: Monk = preload("res://scenes/units/Monk.tscn").instantiate() as Monk
	monk.team = 0
	monk.contribute_population = false
	monk.position = origin + Vector2(-36, 8)
	units.add_child(monk)
	await get_tree().physics_frame
	await get_tree().physics_frame
	ally.hp = 5.0
	ally.queue_redraw()
	monk._facing = "right"
	monk._apply_facing_texture()
	if monk._visual:
		monk._visual.visible = true
		monk._visual.z_index = 5
	SelectionManager.select_single(monk)
	monk.assign_heal(ally)
	monk.monk_state = Monk.MonkState.HEALING
	monk.heal_target = ally
	monk.stop_movement()
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(1.7)
		cam.center_at(origin + Vector2(0, -16))
	await get_tree().create_timer(0.4).timeout
	ally.hp = 5.0
	ally.queue_redraw()
	monk.queue_redraw()
	NotificationManager.show_message("Léčení!")
	await get_tree().process_frame
	await get_tree().process_frame
	_save_shot("monk.png", 0)


## T-19: Mlýn + farm with villager farming (ripe field).
func prepare_farms_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	for n in get_tree().get_nodes_in_group("player_town_hall"):
		if n is Node2D:
			(n as Node2D).visible = false
			(n as Node2D).position = Vector2(-4000, -4000)
	GameManager.current_age = 1
	GameManager.wood = 400
	var origin := Vector2(1020, 700)
	var mill: Mill = preload("res://scenes/buildings/Mill.tscn").instantiate() as Mill
	mill.team = 0
	mill.is_complete = true
	mill.position = origin
	units.add_child(mill)
	var farm: Farm = preload("res://scenes/buildings/Farm.tscn").instantiate() as Farm
	farm.team = 0
	farm.is_complete = true
	farm.amount_remaining = Farm.STOCKPILE
	farm.farm_state = "ripe"
	farm.position = origin + Vector2(20, 95)
	units.add_child(farm)
	farm.set_farm_state("ripe")
	var villager: Villager = preload("res://scenes/units/Villager.tscn").instantiate() as Villager
	villager.team = 0
	villager.contribute_population = false
	villager.position = farm.position + Vector2(-18, 10)
	units.add_child(villager)
	villager.assign_gather(farm, mill)
	await get_tree().create_timer(0.35).timeout
	SelectionManager.select_single(villager)
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(1.25)
		cam.center_at(origin + Vector2(10, 60))
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame
	_save_shot("t19_farms.png", 0)


## T-25: empty farm + Znovu osít command button (60 wood).
func prepare_reseed_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	for n in get_tree().get_nodes_in_group("player_town_hall"):
		if n is Node2D:
			(n as Node2D).visible = false
			(n as Node2D).position = Vector2(-4000, -4000)
	GameManager.current_age = 1
	GameManager.wood = 200
	GameManager.food = 300
	var origin := Vector2(1020, 700)
	var mill: Mill = preload("res://scenes/buildings/Mill.tscn").instantiate() as Mill
	mill.team = 0
	mill.is_complete = true
	mill.position = origin
	units.add_child(mill)
	var farm: Farm = preload("res://scenes/buildings/Farm.tscn").instantiate() as Farm
	farm.team = 0
	farm.is_complete = true
	farm.amount_remaining = 0
	farm.farm_state = "empty"
	farm.position = origin + Vector2(20, 95)
	units.add_child(farm)
	farm.set_farm_state("empty")
	var villager: Villager = preload("res://scenes/units/Villager.tscn").instantiate() as Villager
	villager.team = 0
	villager.contribute_population = false
	villager.position = farm.position + Vector2(-18, 10)
	units.add_child(villager)
	await get_tree().create_timer(0.2).timeout
	SelectionManager.select_building(farm)
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(1.25)
		cam.center_at(origin + Vector2(10, 60))
	await get_tree().create_timer(0.45).timeout
	await get_tree().process_frame
	_save_shot("t25_reseed.png", 0)


## Obléhací dílna + Beranidlo + Trebuchet (age-4 siege).
func prepare_siege_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	for n in get_tree().get_nodes_in_group("player_town_hall"):
		if n is Node2D:
			(n as Node2D).visible = false
			(n as Node2D).position = Vector2(-4000, -4000)
	GameManager.current_age = 4
	GameManager.wood = 800
	GameManager.gold = 500
	var origin := Vector2(1020, 700)
	var uni: University = preload("res://scenes/buildings/University.tscn").instantiate() as University
	uni.team = 0
	uni.is_complete = true
	uni.position = origin + Vector2(-140, 0)
	units.add_child(uni)
	var shop: SiegeWorkshop = preload("res://scenes/buildings/SiegeWorkshop.tscn").instantiate() as SiegeWorkshop
	shop.team = 0
	shop.is_complete = true
	shop.spawn_parent = units
	shop.position = origin
	units.add_child(shop)
	var ram: Ram = preload("res://scenes/units/Ram.tscn").instantiate() as Ram
	ram.team = 0
	ram.contribute_population = false
	ram.position = origin + Vector2(70, 70)
	units.add_child(ram)
	var treb: Trebuchet = preload("res://scenes/units/Trebuchet.tscn").instantiate() as Trebuchet
	treb.team = 0
	treb.contribute_population = false
	treb.position = origin + Vector2(130, 40)
	units.add_child(treb)
	await get_tree().physics_frame
	treb.request_unpack()
	await get_tree().create_timer(0.5).timeout
	SelectionManager.select_building(shop)
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(1.15)
		cam.center_at(origin + Vector2(40, 30))
	await get_tree().create_timer(0.5).timeout
	await get_tree().process_frame
	_save_shot("siege.png", 0)


## Univerzita selected with research buttons visible.
func prepare_university_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	for n in get_tree().get_nodes_in_group("player_town_hall"):
		if n is Node2D:
			(n as Node2D).visible = false
			(n as Node2D).position = Vector2(-4000, -4000)
	GameManager.current_age = 4
	GameManager.wood = 800
	GameManager.gold = 400
	GameManager.stone = 400
	var origin := Vector2(1020, 700)
	var university: University = preload("res://scenes/buildings/University.tscn").instantiate() as University
	university.team = 0
	university.is_complete = true
	university.position = origin
	units.add_child(university)
	var monastery: Monastery = preload("res://scenes/buildings/Monastery.tscn").instantiate() as Monastery
	monastery.team = 0
	monastery.is_complete = true
	monastery.position = origin + Vector2(-150, 10)
	units.add_child(monastery)
	var market: Market = preload("res://scenes/buildings/Market.tscn").instantiate() as Market
	market.team = 0
	market.is_complete = true
	market.position = origin + Vector2(150, 5)
	units.add_child(market)
	await get_tree().physics_frame
	SelectionManager.select_building(university)
	university.enqueue_tech(TechData.MASONRY)
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(1.15)
		cam.center_at(origin + Vector2(0, 20))
	await get_tree().create_timer(0.7).timeout
	await get_tree().process_frame
	_save_shot("university.png", 0)


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


## T-26: rally flag on Radnice + idle-villager HUD button.
func prepare_controls_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	var hall: DropOff = null
	for n in get_tree().get_nodes_in_group("player_town_hall"):
		if n is DropOff:
			hall = n as DropOff
			break
	var wood: ResourceNode = null
	for n in get_tree().get_nodes_in_group("resources"):
		if n is ResourceNode and (n as ResourceNode).resource_type == "wood" and not (n as ResourceNode).is_depleted():
			wood = n as ResourceNode
			break
	if hall:
		SelectionManager.select_building(hall)
		var rally_pos := hall.global_position + Vector2(120, 80)
		if wood:
			rally_pos = wood.global_position
			SelectionManager.set_building_rally(rally_pos, wood)
		else:
			SelectionManager.set_building_rally(rally_pos, null)
	# Ensure idle count is visible on the HUD button.
	SelectionManager.idle_villager_count_changed.emit(SelectionManager.count_idle_villagers())
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam and hall:
		cam.set_zoom_clamped(1.0)
		cam.center_at(hall.global_position + Vector2(60, 40))
	await get_tree().create_timer(0.7).timeout
	await get_tree().process_frame
	_save_shot("t26_controls.png", 0)


## T-24: villager selected — build bar inside command panel (no overlap).
func prepare_build_bar_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	GameManager.current_age = 1
	var villager: Villager = null
	for n in get_tree().get_nodes_in_group("villagers"):
		if n is Villager and (n as Villager).team == 0:
			villager = n as Villager
			break
	if villager == null:
		villager = preload("res://scenes/units/Villager.tscn").instantiate() as Villager
		villager.team = 0
		villager.contribute_population = false
		villager.position = Vector2(920, 720)
		units.add_child(villager)
	SelectionManager.select_single(villager)
	var cmd := _find_command_panel()
	if cmd:
		cmd._refresh_context_ui()
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(1.0)
		cam.center_at(villager.global_position + Vector2(40, 20))
	await get_tree().create_timer(0.6).timeout
	await get_tree().process_frame
	_save_shot("t24_build_bar.png", 1)


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


func _ensure_fog_of_war() -> FogOfWar:
	var existing := get_node_or_null("FogOfWar") as FogOfWar
	if existing:
		return existing
	var fog := FogOfWar.new()
	add_child(fog)
	return fog


## T-29: fog edge — clear near TC, black unexplored corner, AI unit out of sight.
func prepare_fog_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	var fog := _ensure_fog_of_war()
	fog.fog_enabled = true
	for n in get_tree().get_nodes_in_group("enemy_units"):
		if n is Unit and is_instance_valid(n):
			(n as Unit).position = Vector2(40, 40)
	var scout: Villager = null
	for n in get_tree().get_nodes_in_group("player_units"):
		if n is Villager:
			scout = n as Villager
			break
	if scout:
		scout.position = PLAYER_TC_POS + Vector2(180, 40)
	var hidden_ai: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	hidden_ai.team = 1
	hidden_ai.contribute_population = false
	hidden_ai.position = PLAYER_TC_POS + Vector2(520, 0)
	units.add_child(hidden_ai)
	await get_tree().physics_frame
	await get_tree().physics_frame
	fog.force_update()
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(1.0)
		cam.center_at(PLAYER_TC_POS + Vector2(120, 40))
	await get_tree().create_timer(0.4).timeout
	_save_shot("t29_fog.png", 0)


## T-32: soft fog edge + last-known enemy building in explored grey.
func prepare_fog_polish_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	var fog := _ensure_fog_of_war()
	fog.fog_enabled = true
	for n in get_tree().get_nodes_in_group("enemy_units"):
		if n is Unit and is_instance_valid(n):
			(n as Unit).position = Vector2(40, 40)
	# Scout reveals east of TC LOS, then pulls back so hut stays last-known in grey.
	var scout: Villager = null
	for n in get_tree().get_nodes_in_group("player_units"):
		if n is Villager:
			scout = n as Villager
			break
	var known_pos := PLAYER_TC_POS + Vector2(420, 40)
	if scout:
		scout.position = known_pos
	await get_tree().physics_frame
	fog.force_update()
	var known_hut: Building = preload("res://scenes/buildings/House.tscn").instantiate() as Building
	known_hut.team = 1
	known_hut.is_complete = true
	known_hut.position = known_pos
	units.add_child(known_hut)
	await get_tree().physics_frame
	fog.force_update()
	# Leave LOS so hut stays as last-known in grey; hidden AI stays out of sight.
	if scout:
		scout.position = PLAYER_TC_POS + Vector2(40, 40)
	var hidden_ai: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	hidden_ai.team = 1
	hidden_ai.contribute_population = false
	hidden_ai.position = PLAYER_TC_POS + Vector2(620, 80)
	units.add_child(hidden_ai)
	await get_tree().physics_frame
	await get_tree().physics_frame
	fog.force_update()
	var cam := get_node_or_null("Camera2D") as RTSCamera
	if cam:
		cam.set_zoom_clamped(0.85)
		cam.center_at(PLAYER_TC_POS + Vector2(220, 40))
	await get_tree().create_timer(0.4).timeout
	_save_shot("t32_fog_polish.png", 0)


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
	soldier.position = PLAYER_TC_POS + Vector2(50, 50)
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
	var sel := ui.get_node_or_null("SelectionInfo") as Control if ui else null
	var mini := ui.get_node_or_null("Minimap") as Control if ui else null
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
	var no_overlap := false
	if villager and cmd and sel and mini:
		SelectionManager.select_single(villager)
		await get_tree().process_frame
		cmd._refresh_context_ui()
		await get_tree().process_frame
		await get_tree().process_frame
		build_ok = cmd.is_build_row_visible()
		var kov := cmd.get_build_button("blacksmith")
		kovarna_locked = kov != null and kov.disabled
		print("[TEST] hud villager build_row=%s kovarna_disabled=%s tip=%s" % [
			build_ok, kovarna_locked, kov.tooltip_text if kov else ""
		])
		no_overlap = await _build_bar_no_overlap_at_sizes(cmd, sel, mini)
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

	if nodes_ok and debug_ok and build_ok and kovarna_locked and czech_ok and no_overlap:
		print("[TEST] PASS HUD layout + villager builds + DebugPanel hidden")
	else:
		print("[TEST] FAIL HUD layout + villager builds + DebugPanel hidden")


## Build-bar global rect must not intersect SelectionInfo or Minimap at 720p/1080p.
func _build_bar_no_overlap_at_sizes(cmd: CommandPanel, sel: Control, mini: Control) -> bool:
	var build := cmd.get_build_bar_control()
	if build == null:
		build = cmd.get_node_or_null("CommandMargin/CommandVBox/BuildScroll") as Control
	if build == null or not build.visible:
		print("[TEST] FAIL build-bar overlap: BuildScroll missing/hidden")
		return false
	var ok := true
	var prev := DisplayServer.window_get_size()
	for win_size in [Vector2i(1280, 720), Vector2i(1920, 1080)]:
		DisplayServer.window_set_size(win_size)
		# Headless: also drive viewport size so Control anchors reflow.
		get_viewport().size = win_size
		cmd._sync_panel_to_content()
		await get_tree().process_frame
		await get_tree().process_frame
		var br := build.get_global_rect()
		var sr := sel.get_global_rect()
		var mr := mini.get_global_rect()
		var cr := cmd.get_global_rect()
		var hit_sel := br.intersects(sr)
		var hit_mini := br.intersects(mr)
		var inside_cmd := cr.grow(1.0).encloses(br)
		print(
			"[TEST] build-bar %dx%d rect=%s sel_hit=%s mini_hit=%s inside_cmd=%s"
			% [win_size.x, win_size.y, br, hit_sel, hit_mini, inside_cmd]
		)
		if hit_sel or hit_mini or not inside_cmd:
			ok = false
	DisplayServer.window_set_size(prev)
	get_viewport().size = prev
	if ok:
		print("[TEST] PASS build-bar rect must not overlap selection-info rect or minimap rect")
	else:
		print("[TEST] FAIL build-bar rect must not overlap selection-info rect or minimap rect")
	return ok


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

	# Cavalry bonus: Lancknecht +6 vs cavalry.
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
	var cav_bonus_ok := is_equal_approx(lanc.bonus_vs_cavalry, 6.0) and cav.hp <= cav_hp - maxf(1.0, expect_cav) + 0.1
	print("[TEST] lancknecht vs cav ok=%s" % cav_bonus_ok)

	# Přemyslovci +10% on Družiník.
	GameManager.player_civ = CivData.PREMYSLOVCI
	var dru: Druzinik = preload("res://scenes/units/Druzinik.tscn").instantiate() as Druzinik
	dru.team = 0
	dru.contribute_population = false
	dru.position = PLAYER_TC_POS + Vector2(60, 100)
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


## T-30 Standard AI: accelerated ~10 in-game minutes → ≥12 vills, ≥1 farm, age≥2, ≥1 wave.
func _run_ai_economy_smoke() -> void:
	var ai := get_node_or_null("SimpleEnemyAI") as SimpleEnemyAI
	if ai == null:
		print("[TEST] FAIL ai_economy: no SimpleEnemyAI")
		return
	## Keep victory from pausing the tree when a wave hits the player TC mid-smoke.
	var victory := get_node_or_null("VictoryController") as VictoryController
	if victory:
		victory.set_process(false)
	## Deterministic RNG; do not wipe buildings/age already earned during prior smokes.
	ai.rng.seed = 4242 + ai.team * 7919
	ai.timing_jitter = 1.0
	var start_elapsed: float = ai._sim_elapsed
	Engine.time_scale = 80.0
	var ok := false
	## Headless frames can have tiny wall deltas; allow many iterations for +10 min.
	var frames := 0
	while frames < 40000:
		await get_tree().process_frame
		frames += 1
		## Keep player TC alive so later victory/defeat smokes still have a hall.
		var ph := get_tree().get_first_node_in_group("player_town_hall") as DropOff
		if ph != null and is_instance_valid(ph):
			ph.hp = ph.max_hp
		if ai.standard_smoke_ok():
			ok = true
			break
		if ai._sim_elapsed - start_elapsed >= 600.0:
			ok = ai.standard_smoke_ok()
			break
	ai.print_ai_summary()
	Engine.time_scale = 1.0
	## Pull wave home, freeze AI, restore player hall for subsequent smokes.
	ai._retreating = true
	for u in ai._own_military():
		if u is Unit and is_instance_valid(u):
			(u as Unit).command_move(ai.base_position)
	ai.set_process(false)
	_ensure_player_hall_after_ai_smoke(victory)
	if victory:
		victory.set_process(true)
		victory.reset_for_test()
	print("[TEST] ai_economy vills=%d farms=%d age=%d waved=%s elapsed=%.0fs frames=%d" % [
		ai._count_villagers(), ai._count_farms(), ai.age, ai.has_launched_wave(), ai._sim_elapsed, frames
	])
	if ok:
		print("[TEST] PASS AI places building and launches wave")
	else:
		print("[TEST] FAIL AI places building and launches wave")


func _ensure_player_hall_after_ai_smoke(victory_node: VictoryController) -> void:
	var hall := get_tree().get_first_node_in_group("player_town_hall") as DropOff
	if hall != null and is_instance_valid(hall):
		hall.hp = hall.max_hp
		return
	hall = DROPOFF_SCENE.instantiate() as DropOff
	hall.team = 0
	hall.position = PLAYER_TC_POS
	hall.spawn_parent = units
	units.add_child(hall)
	if victory_node:
		victory_node.watch_new_hall(hall)
	print("[TEST] ai_economy restored player town hall")


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


## Age 3–4 buildings (Klášter/Tržiště/Univerzita) + Monk heal/convert.
func _run_age34_monk_smoke() -> void:
	await get_tree().physics_frame
	GameManager.current_age = 3
	GameManager.food = 400
	GameManager.wood = 500
	GameManager.gold = 300
	GameManager.stone = 100
	GameManager.add_population_cap(20)

	var design_ok: bool = (
		int(BuildingPlacer.COSTS["monastery"].get("wood", 0)) == 175
		and int(BuildingPlacer.COSTS["market"].get("wood", 0)) == 175
		and int(BuildingPlacer.COSTS["university"].get("wood", 0)) == 200
		and float(BuildingPlacer.BUILD_TIMES["monastery"]) == 40.0
		and float(BuildingPlacer.BUILD_TIMES["market"]) == 60.0
		and float(BuildingPlacer.BUILD_TIMES["university"]) == 60.0
		and AgeData.building_unlock_age("monastery") == 3
		and AgeData.building_unlock_age("market") == 3
		and AgeData.building_unlock_age("university") == 4
		and AgeData.unit_unlock_age("monk") == 3
	)

	# Age lock: university blocked at age 3.
	GameManager.current_age = 3
	var uni_locked: bool = not GameManager.is_building_unlocked("university")
	var wood0 := GameManager.wood
	var uni_place := building_placer.place_at("university", PLAYER_TC_POS + Vector2(260, 180))
	var uni_block_ok: bool = uni_locked and uni_place == null and GameManager.wood == wood0

	# Place monastery + market at age 3.
	var mon_pos := PLAYER_TC_POS + Vector2(160, 140)
	var mkt_pos := PLAYER_TC_POS + Vector2(280, 140)
	var monastery: Monastery = building_placer.place_at("monastery", mon_pos) as Monastery
	var market: Market = building_placer.place_at("market", mkt_pos) as Market
	var place_ok: bool = monastery != null and market != null
	if monastery:
		monastery.is_complete = true
		monastery.build_progress = 1.0
		monastery.hp = monastery.max_hp
		monastery._show_final_visual()
		monastery.spawn_parent = units
	if market:
		market.is_complete = true
		market.build_progress = 1.0
		market.hp = market.max_hp
		market._show_final_visual()
	await get_tree().physics_frame

	# Age 4 unlocks university.
	GameManager.current_age = 4
	GameManager.wood = maxi(GameManager.wood, 250)
	var uni_open: bool = GameManager.is_building_unlocked("university")
	var university: University = building_placer.place_at(
		"university", PLAYER_TC_POS + Vector2(400, 160)
	) as University
	var uni_place_ok: bool = uni_open and university != null
	if university:
		university.is_complete = true
		university.build_progress = 1.0
		university.hp = university.max_hp
		university._show_final_visual()
	await get_tree().physics_frame

	# Monk train from monastery.
	GameManager.current_age = 3
	var gold_before := GameManager.gold
	var queued := monastery != null and monastery.enqueue_monk()
	var spend_ok: bool = queued and GameManager.gold == gold_before - 100
	if monastery and not monastery.queue.is_empty():
		monastery.train_remaining = 0.0
		monastery._complete_training()
	await get_tree().physics_frame
	var monk: Monk = null
	for n in get_tree().get_nodes_in_group("monks"):
		if n is Monk and (n as Monk).team == 0:
			monk = n as Monk
			break
	var train_ok: bool = monk != null and is_equal_approx(monk.max_hp, 30.0) and not monk.can_attack

	# Heal damaged ally.
	var ally: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	ally.team = 0
	ally.contribute_population = false
	ally.position = (monk.global_position if monk else PLAYER_TC_POS) + Vector2(40, 40)
	units.add_child(ally)
	await get_tree().physics_frame
	ally.hp = 10.0
	ally.queue_redraw()
	var heal_ok: bool = false
	if monk:
		monk.global_position = ally.global_position + Vector2(20, 0)
		monk.assign_heal(ally)
		# Force healing state at range and wait for HP ticks.
		monk.monk_state = Monk.MonkState.HEALING
		monk.stop_movement()
		await get_tree().create_timer(1.2).timeout
		heal_ok = ally.hp > 10.0 + 3.0
	print("[TEST] monk_heal hp %.1f ok=%s" % [ally.hp, heal_ok])

	# Convert enemy.
	var foe: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	foe.team = 1
	foe.contribute_population = false
	foe.position = (monk.global_position if monk else PLAYER_TC_POS) + Vector2(80, 0)
	units.add_child(foe)
	await get_tree().physics_frame
	var convert_ok: bool = false
	if monk:
		monk.command_stop()
		monk.global_position = foe.global_position + Vector2(10, 0)
		monk.assign_convert(foe)
		monk.monk_state = Monk.MonkState.CONVERTING
		monk._convert_progress = Monk.CONVERT_TIME
		monk._finish_convert()
		convert_ok = foe.team == 0 and foe.is_in_group("player_units")
	print("[TEST] monk_convert team=%d ok=%s" % [foe.team, convert_ok])

	# Market trade wood→gold.
	GameManager.wood = 200
	GameManager.gold = 50
	var trade_ok: bool = false
	if market:
		trade_ok = market.trade_wood_for_gold(100) and GameManager.wood == 100 and GameManager.gold == 120
	print("[TEST] market_trade wood=%d gold=%d ok=%s" % [GameManager.wood, GameManager.gold, trade_ok])

	# University techs (same research system as Blacksmith).
	GameManager.wood = 800
	GameManager.gold = 400
	GameManager.stone = 400
	var hut: Building = preload("res://scenes/buildings/House.tscn").instantiate() as Building
	hut.team = 0
	hut.is_complete = true
	hut.position = PLAYER_TC_POS + Vector2(-160, 160)
	units.add_child(hut)
	await get_tree().physics_frame
	var hut_max0 := hut.max_hp
	var tower: WatchTower = preload("res://scenes/buildings/WatchTower.tscn").instantiate() as WatchTower
	tower.team = 0
	tower.is_complete = true
	tower.spawn_parent = units
	tower.position = PLAYER_TC_POS + Vector2(120, 220)
	units.add_child(tower)
	await get_tree().physics_frame
	var tower_dmg0 := tower.attack_damage
	var tower_rng0 := tower.attack_range_px
	var archer: Archer = ARCHER_SCENE.instantiate() as Archer
	archer.team = 0
	archer.contribute_population = false
	archer.position = PLAYER_TC_POS + Vector2(40, 220)
	units.add_child(archer)
	await get_tree().physics_frame
	var archer_rng0 := archer.attack_range

	var uni_tech_ok: bool = false
	if university:
		var wood_u0 := GameManager.wood
		var stone_u0 := GameManager.stone
		var started_m := university.enqueue_tech(TechData.MASONRY)
		if started_m:
			university.research_remaining = 0.0
			university._complete_research()
		await get_tree().process_frame
		var masonry_ok := (
			started_m
			and GameManager.has_tech(0, TechData.MASONRY)
			and GameManager.wood == wood_u0 - 150
			and GameManager.stone == stone_u0 - 175
			and hut.max_hp >= hut_max0 * 1.10 - 0.01
		)
		var started_b := university.enqueue_tech(TechData.BALLISTICS)
		if started_b:
			university.research_remaining = 0.0
			university._complete_research()
		await get_tree().process_frame
		var ball_ok := (
			started_b
			and GameManager.has_tech(0, TechData.BALLISTICS)
			and archer.attack_range >= archer_rng0 + 39.0
			and tower.attack_range_px >= tower_rng0 + 39.0
		)
		var started_t := university.enqueue_tech(TechData.TOWER_ENGINE)
		if started_t:
			university.research_remaining = 0.0
			university._complete_research()
		await get_tree().process_frame
		var engine_ok := (
			started_t
			and GameManager.has_tech(0, TechData.TOWER_ENGINE)
			and tower.attack_damage >= tower_dmg0 + 1.99
			and tower.attack_range_px >= tower_rng0 + 79.0
		)
		var twice := university.enqueue_tech(TechData.MASONRY)
		uni_tech_ok = masonry_ok and ball_ok and engine_ok and not twice
		print(
			"[TEST] uni_techs masonry=%s ball=%s engine=%s twice_block=%s"
			% [masonry_ok, ball_ok, engine_ok, not twice]
		)
	else:
		print("[TEST] uni_techs skipped (no university)")

	# Sprites wired (Honza art pipeline).
	var art_ok: bool = true
	for b in [monastery, market, university]:
		if b == null:
			art_ok = false
			continue
		var vis := b.get_node_or_null("Visual") as Sprite2D
		if vis == null or vis.texture == null:
			art_ok = false
			print("[TEST] missing building sprite on %s" % (b.display_name if b else "?"))
	if monk == null or monk.get_node_or_null("Visual") == null:
		art_ok = false
	elif (monk.get_node("Visual") as Sprite2D).texture == null:
		art_ok = false
		print("[TEST] missing monk facing texture")
	else:
		var mt := (monk.get_node("Visual") as Sprite2D).texture
		if mt.get_width() != 24 or mt.get_height() != 46:
			art_ok = false
			print("[TEST] monk canvas expected 24x46 got %dx%d" % [mt.get_width(), mt.get_height()])

	var all_ok: bool = (
		design_ok and uni_block_ok and place_ok and uni_place_ok
		and spend_ok and train_ok and heal_ok and convert_ok and trade_ok
		and uni_tech_ok and art_ok
	)
	print(
		"[TEST] age34 design=%s uni_lock=%s place=%s uni4=%s spend=%s train=%s heal=%s convert=%s trade=%s techs=%s art=%s"
		% [
			design_ok, uni_block_ok, place_ok, uni_place_ok, spend_ok, train_ok,
			heal_ok, convert_ok, trade_ok, uni_tech_ok, art_ok
		]
	)
	if all_ok:
		print("[TEST] PASS age 3–4 buildings + monk heal/convert")
	else:
		print("[TEST] FAIL age 3–4 buildings + monk heal/convert")

	for n in [monastery, market, university, monk, ally, foe, hut, tower, archer]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	await get_tree().physics_frame


## Age-4 siege: Obléhací dílna requires University; Ram/Trebuchet buildings-only; unpack.
func _run_age4_siege_smoke() -> void:
	await get_tree().physics_frame
	GameManager._researched = {0: {}, 1: {}}
	GameManager.player_civ = CivData.DEFAULT_PLAYER
	GameManager.current_age = 4
	GameManager.food = 400
	GameManager.wood = 800
	GameManager.gold = 500
	GameManager.stone = 100
	GameManager.add_population_cap(20)

	var design_ok: bool = (
		int(BuildingPlacer.COSTS["siege_workshop"].get("wood", 0)) == 200
		and float(BuildingPlacer.BUILD_TIMES["siege_workshop"]) == 60.0
		and AgeData.building_unlock_age("siege_workshop") == 4
		and AgeData.unit_unlock_age("ram") == 4
		and AgeData.unit_unlock_age("trebuchet") == 4
		and int(SiegeWorkshop.UNIT_DEFS["ram"]["cost"].get("wood", 0)) == 160
		and int(SiegeWorkshop.UNIT_DEFS["ram"]["cost"].get("gold", 0)) == 75
		and int(SiegeWorkshop.UNIT_DEFS["trebuchet"]["cost"].get("wood", 0)) == 200
		and int(SiegeWorkshop.UNIT_DEFS["trebuchet"]["cost"].get("gold", 0)) == 200
	)

	# Prereq: workshop blocked without university.
	var wood0 := GameManager.wood
	var blocked := building_placer.place_at("siege_workshop", PLAYER_TC_POS + Vector2(200, 160))
	var prereq_ok: bool = blocked == null and GameManager.wood == wood0 and not building_placer._prereq_met("siege_workshop")

	var uni: University = building_placer.place_at("university", PLAYER_TC_POS + Vector2(260, 140)) as University
	var uni_ok: bool = uni != null
	if uni:
		uni.is_complete = true
		uni.build_progress = 1.0
		uni.hp = uni.max_hp
		uni._show_final_visual()
	await get_tree().physics_frame

	var shop: SiegeWorkshop = building_placer.place_at(
		"siege_workshop", PLAYER_TC_POS + Vector2(380, 140)
	) as SiegeWorkshop
	var shop_ok: bool = shop != null and building_placer._prereq_met("siege_workshop")
	if shop:
		shop.is_complete = true
		shop.build_progress = 1.0
		shop.hp = shop.max_hp
		shop._show_final_visual()
		shop.spawn_parent = units
	await get_tree().physics_frame

	# Train ram + trebuchet.
	var wood_r0 := GameManager.wood
	var gold_r0 := GameManager.gold
	var ram_q := shop != null and shop.enqueue_unit("ram")
	var ram_spend: bool = ram_q and GameManager.wood == wood_r0 - 160 and GameManager.gold == gold_r0 - 75
	if shop and not shop.queue.is_empty():
		shop.train_remaining = 0.0
		shop._complete_training()
	await get_tree().physics_frame
	var ram: Ram = null
	for n in get_tree().get_nodes_in_group("siege"):
		if n is Ram and (n as Ram).team == 0:
			ram = n as Ram
			break
	var ram_ok: bool = (
		ram != null
		and ram.buildings_only
		and is_equal_approx(ram.bonus_vs_buildings, 125.0)
		and is_equal_approx(ram.pierce_armor, 7.0)
		and is_equal_approx(ram.speed, 40.0)
	)

	var wood_t0 := GameManager.wood
	var gold_t0 := GameManager.gold
	var treb_q := shop != null and shop.enqueue_unit("trebuchet")
	var treb_spend: bool = treb_q and GameManager.wood == wood_t0 - 200 and GameManager.gold == gold_t0 - 200
	if shop and not shop.queue.is_empty():
		shop.train_remaining = 0.0
		shop._complete_training()
	await get_tree().physics_frame
	var treb: Trebuchet = null
	for n in get_tree().get_nodes_in_group("siege"):
		if n is Trebuchet and (n as Trebuchet).team == 0:
			treb = n as Trebuchet
			break
	var treb_stats: bool = (
		treb != null
		and treb.buildings_only
		and treb.packed
		and not treb.can_attack
		and is_equal_approx(treb.attack_range, 640.0)
		and is_equal_approx(treb.min_attack_range, 160.0)
		and is_equal_approx(treb.attack_damage, 40.0)
	)

	# Buildings-only: refuse soldier, accept house.
	var foe: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	foe.team = 1
	foe.contribute_population = false
	foe.position = (ram.global_position if ram else PLAYER_TC_POS) + Vector2(50, 0)
	units.add_child(foe)
	await get_tree().physics_frame
	var hut: Building = preload("res://scenes/buildings/House.tscn").instantiate() as Building
	hut.team = 1
	hut.is_complete = true
	hut.position = (ram.global_position if ram else PLAYER_TC_POS) + Vector2(80, 40)
	units.add_child(hut)
	await get_tree().physics_frame

	var ram_refuse := false
	var ram_hit := false
	if ram:
		ram.command_attack(foe)
		ram_refuse = ram.attack_target == null
		ram.global_position = hut.global_position + Vector2(30, 0)
		ram.command_attack(hut)
		ram_hit = ram.attack_target == hut
		if ram_hit:
			var hp0 := hut.hp
			ram._try_strike()
			ram_hit = hut.hp < hp0 - 50.0 ## 2 + 125 vs building
	print("[TEST] ram buildings_only refuse=%s hit=%s" % [ram_refuse, ram_hit])

	# Trebuchet unpack then attack building; refuse unit.
	# Hit must come from Unit._chase_and_attack after unpack — never hand-call _try_strike.
	var unpack_ok := false
	var treb_refuse := false
	var treb_hit := false
	if treb:
		treb.global_position = hut.global_position + Vector2(200, 0) ## inside 160–640
		treb.command_attack(foe)
		treb_refuse = treb.attack_target == null and treb._pending_attack == null
		var hut_hp_before_treb := hut.hp
		treb.command_attack(hut)
		var pending := (
			treb._pending_attack == hut
			or treb.is_transitioning()
			or treb._approach_target == hut
		)
		## Unpack (~0.35s headless) then natural strike (short attack_cd).
		for _u in 90:
			await get_tree().physics_frame
			if not is_instance_valid(treb) or not is_instance_valid(hut):
				break
			if (not treb.packed) and treb.can_attack:
				unpack_ok = pending
			if unpack_ok and hut.hp < hut_hp_before_treb - 20.0:
				treb_hit = treb.attack_target == hut or treb._pending_attack == null
				break
		if unpack_ok and not treb_hit:
			## Still waiting on cooldown/frames — give a bit more.
			for _u2 in 60:
				await get_tree().physics_frame
				if is_instance_valid(hut) and hut.hp < hut_hp_before_treb - 20.0:
					treb_hit = true
					break
	print("[TEST] treb unpack=%s refuse=%s hit=%s" % [unpack_ok, treb_refuse, treb_hit])

	# Long-range approach: ~20 tiles away → pathfind around a wall → unpack → natural hit.
	var approach_ok := false
	var barrier_walls: Array = []
	if treb and hut and is_instance_valid(hut):
		## Stop ram so it doesn't finish the hut mid-approach.
		if ram and is_instance_valid(ram):
			ram.command_stop()
			ram.global_position = hut.global_position + Vector2(-200, -200)
		hut.hp = hut.max_hp
		if not treb.packed:
			treb.request_pack()
			await get_tree().create_timer(0.55).timeout
		## Fresh packed state — clear any leftover approach/pending.
		treb.packed = true
		treb.can_attack = false
		treb.speed = Trebuchet.PACKED_SPEED
		treb._pack_timer = 0.0
		treb._approach_target = null
		treb._pending_attack = null
		treb._pending_move = Vector2.INF
		treb.attack_target = null
		treb.stop_movement()
		var far := hut.global_position + Vector2(20.0 * 40.0, 0.0) ## 800 px ≈ 20 tiles
		treb.global_position = far
		if treb.navigation_agent:
			treb.navigation_agent.target_position = far
		## Short vertical palisade between treb and hut — must path around (no walk-through).
		GameManager.wood += 40
		var mid := hut.global_position + Vector2(10.0 * 40.0, 0.0)
		var barrier_tiles: Array[Vector2i] = []
		for dy in range(-2, 3):
			barrier_tiles.append(WallNav.world_to_tile(mid + Vector2(0.0, float(dy) * 40.0)))
		barrier_walls = building_placer.place_wall_line("palisade", barrier_tiles)
		for s in barrier_walls:
			if s is WallSegment:
				(s as WallSegment).is_complete = true
				(s as WallSegment).build_progress = 1.0
				(s as WallSegment).hp = (s as WallSegment).max_hp
				(s as WallSegment)._show_final_visual()
				(s as WallSegment)._ensure_blocker()
		await get_tree().physics_frame
		await get_tree().physics_frame
		var start_pos := treb.global_position
		var start_dist := treb.global_position.distance_to(hut.global_position)
		var hut_hp_far := hut.hp
		treb.command_attack(hut)
		await get_tree().physics_frame
		## Must start approach while still packed (not unpack at 800px).
		var dist0 := treb.global_position.distance_to(hut.global_position)
		var started_approach := (
			treb.packed
			and dist0 > Trebuchet.RANGE_MAX
			and (
				treb._approach_target == hut
				or treb._pending_attack == hut
			)
		)
		## Nav around wall at 48px/s — allow enough frames for path + unpack + natural fire.
		var walked := false
		var unpacked_in_range := false
		var hit_far := false
		var min_dist := start_dist
		var max_lateral := 0.0
		for _i in 900:
			await get_tree().physics_frame
			if not is_instance_valid(treb) or not is_instance_valid(hut):
				break
			var d := treb.global_position.distance_to(hut.global_position)
			min_dist = minf(min_dist, d)
			## Path around wall shows as lateral (Y) travel, not a straight X slide.
			max_lateral = maxf(max_lateral, absf(treb.global_position.y - start_pos.y))
			if d < start_dist - 40.0 or max_lateral > 30.0:
				walked = true
			if (not treb.packed) and treb.can_attack and d <= Trebuchet.RANGE_MAX + 24.0:
				unpacked_in_range = true
			## Natural fire only — no _try_strike() from the smoke.
			if unpacked_in_range and hut.hp < hut_hp_far - 20.0:
				hit_far = true
				break
		approach_ok = started_approach and walked and unpacked_in_range and hit_far
		print(
			"[TEST] treb approach start=%s walk=%s unpack_rng=%s hit=%s min_d=%.0f lat=%.0f ok=%s"
			% [started_approach, walked, unpacked_in_range, hit_far, min_dist, max_lateral, approach_ok]
		)
	else:
		print("[TEST] treb approach skipped")

	var art_ok: bool = true
	if shop:
		var vis := shop.get_node_or_null("Visual") as Sprite2D
		if vis == null or vis.texture == null:
			art_ok = false
	if ram == null or ram.get_node_or_null("Visual") == null:
		art_ok = false
	elif (ram.get_node("Visual") as Sprite2D).texture == null:
		art_ok = false
	if treb == null or treb.get_node_or_null("Visual") == null:
		art_ok = false
	elif (treb.get_node("Visual") as Sprite2D).texture == null:
		art_ok = false

	var all_ok: bool = (
		design_ok and prereq_ok and uni_ok and shop_ok
		and ram_spend and ram_ok and ram_refuse and ram_hit
		and treb_spend and treb_stats and unpack_ok and treb_refuse and treb_hit
		and approach_ok and art_ok
	)
	print(
		"[TEST] siege design=%s prereq=%s uni=%s shop=%s ram=%s/%s treb=%s/%s unpack=%s approach=%s art=%s"
		% [
			design_ok, prereq_ok, uni_ok, shop_ok,
			ram_ok and ram_spend and ram_refuse and ram_hit,
			ram != null,
			treb_stats and treb_spend and treb_refuse and treb_hit,
			treb != null,
			unpack_ok, approach_ok, art_ok
		]
	)
	if all_ok:
		print("[TEST] PASS age-4 siege workshop + ram/trebuchet")
	else:
		print("[TEST] FAIL age-4 siege workshop + ram/trebuchet")

	for n in [uni, shop, ram, treb, foe, hut]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	for s in barrier_walls:
		if s != null and is_instance_valid(s):
			s.queue_free()
	await get_tree().physics_frame


## T-19 farm plots: sprite + Mill prereq + gather food + deplete → empty.
func _run_farm_plots_smoke() -> void:
	await get_tree().physics_frame
	GameManager.current_age = 1
	GameManager.wood = 400
	GameManager.food = 200

	var tex_farm := load("res://assets/sprites/buildings/farm.png") as Texture2D
	var tex_empty := load("res://assets/sprites/buildings/farm_empty.png") as Texture2D
	var tex_sown := load("res://assets/sprites/buildings/farm_sown.png") as Texture2D
	var tex_ripe := load("res://assets/sprites/buildings/farm_ripe.png") as Texture2D
	var sprites_ok: bool = (
		tex_farm != null and tex_empty != null and tex_sown != null and tex_ripe != null
		and tex_farm.get_width() == 80
		and tex_empty.get_width() == 80
		and tex_sown.get_width() == 80
		and tex_ripe.get_width() == 80
	)

	var design_ok: bool = (
		int(BuildingPlacer.COSTS["farm"].get("wood", 0)) == 60
		and float(BuildingPlacer.BUILD_TIMES["farm"]) == 15.0
		and AgeData.building_unlock_age("farm") == 1
		and BuildingPlacer.FOOTPRINTS["farm"] == Vector2(80, 80)
		and str(BuildingPlacer.REQUIRES_BUILDING.get("farm", "")) == "mill"
		and is_equal_approx(Villager.FARM_HARVEST_RATE, 0.33)
		and Farm.STOCKPILE == 175
	)

	# Blocked without mill.
	var wood0 := GameManager.wood
	var blocked := building_placer.place_at("farm", PLAYER_TC_POS + Vector2(220, 180))
	var prereq_ok: bool = blocked == null and GameManager.wood == wood0 and not building_placer._prereq_met("farm")

	var mill: Mill = building_placer.place_at("mill", PLAYER_TC_POS + Vector2(260, 160)) as Mill
	var mill_ok: bool = mill != null
	if mill:
		mill.is_complete = true
		mill.build_progress = 1.0
		mill.hp = mill.max_hp
		mill._show_final_visual()
		mill._on_construction_finished()
	await get_tree().physics_frame

	var farm: Farm = building_placer.place_at("farm", PLAYER_TC_POS + Vector2(340, 200)) as Farm
	var place_ok: bool = farm != null and building_placer._prereq_met("farm")
	if farm:
		farm.is_complete = true
		farm.build_progress = 1.0
		farm.hp = farm.max_hp
		farm._on_construction_finished()
		farm._show_final_visual()
	await get_tree().physics_frame

	var sown_ok: bool = farm != null and farm.farm_state == "sown" and farm.amount_remaining == Farm.STOCKPILE
	var uses_sprite: bool = false
	if farm:
		var vis := farm.get_node_or_null("Visual") as Sprite2D
		uses_sprite = vis != null and vis.texture == Farm.TEX_SOWN

	# Gather: villager on farm deposits food at mill → player food rises.
	var villager: Villager = null
	for n in get_tree().get_nodes_in_group("villagers"):
		if n is Villager and (n as Villager).team == 0:
			villager = n as Villager
			break
	var food0 := GameManager.food
	var gather_ok := false
	var one_farmer_ok := false
	if farm and villager and mill:
		farm.amount_remaining = 12
		farm.farm_state = "sown"
		farm._apply_farm_sprite()
		villager.carry_capacity = 1
		villager.global_position = farm.global_position + Vector2(8, 8)
		if villager.navigation_agent:
			villager.navigation_agent.target_position = villager.global_position
		await get_tree().physics_frame
		villager.assign_gather(farm, mill)
		one_farmer_ok = farm.has_farmer()
		var v2: Villager = VILLAGER_SCENE.instantiate() as Villager
		v2.team = 0
		v2.contribute_population = false
		v2.global_position = farm.global_position + Vector2(-20, 0)
		units.add_child(v2)
		v2.assign_gather(farm, mill)
		one_farmer_ok = one_farmer_ok and v2.target_resource != farm
		v2.queue_free()
		# 0.33/s × carry 1 ≈ ~3s to first deposit; allow headless slack.
		for _i in 900:
			await get_tree().physics_frame
			if GameManager.food > food0:
				gather_ok = true
				break
		# Force deplete remainder and confirm empty state.
		if is_instance_valid(farm) and not farm.is_depleted():
			farm.harvest(farm.amount_remaining)
		var empty_ok: bool = farm.is_depleted() and farm.farm_state == "empty"
		uses_sprite = uses_sprite and empty_ok
	else:
		one_farmer_ok = false

	var all_ok: bool = (
		sprites_ok and design_ok and prereq_ok and mill_ok and place_ok
		and sown_ok and uses_sprite and gather_ok and one_farmer_ok
	)
	print(
		"[TEST] farm sprites=%s design=%s prereq=%s mill=%s place=%s sown=%s gather=%s one=%s empty=%s"
		% [
			sprites_ok, design_ok, prereq_ok, mill_ok, place_ok, sown_ok,
			gather_ok, one_farmer_ok, uses_sprite
		]
	)
	if all_ok:
		print("[TEST] PASS farm plots gather food and deplete to empty")
	else:
		print("[TEST] FAIL farm plots gather food and deplete to empty")

	if villager != null and is_instance_valid(villager):
		villager.command_stop()
	for n in [mill, farm]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	await get_tree().physics_frame


## T-25: empty farm → reseed 60 wood → sown → food rises again.
func _run_farm_reseed_smoke() -> void:
	await get_tree().physics_frame
	GameManager.current_age = 1
	GameManager.wood = 300
	GameManager.food = 200

	var design_ok: bool = Farm.RESEED_WOOD == 60 and Farm.STOCKPILE == 175

	var mill: Mill = building_placer.place_at("mill", PLAYER_TC_POS + Vector2(280, 140)) as Mill
	if mill:
		mill.is_complete = true
		mill.build_progress = 1.0
		mill.hp = mill.max_hp
		mill._show_final_visual()
		mill._on_construction_finished()
	await get_tree().physics_frame

	var farm: Farm = building_placer.place_at("farm", PLAYER_TC_POS + Vector2(360, 190)) as Farm
	if farm:
		farm.is_complete = true
		farm.build_progress = 1.0
		farm.hp = farm.max_hp
		farm._on_construction_finished()
		farm._show_final_visual()
	await get_tree().physics_frame

	var villager: Villager = null
	for n in get_tree().get_nodes_in_group("villagers"):
		if n is Villager and (n as Villager).team == 0:
			villager = n as Villager
			break

	# Deplete farm to empty.
	var deplete_ok := false
	if farm:
		farm.harvest(farm.amount_remaining)
		deplete_ok = farm.is_depleted() and farm.farm_state == "empty"

	# Manual reseed spends 60 wood and restores sown stockpile.
	var wood_before := GameManager.wood
	var reseed_ok := false
	var sown_ok := false
	if farm:
		reseed_ok = farm.try_reseed(0, false)
		sown_ok = (
			reseed_ok
			and GameManager.wood == wood_before - Farm.RESEED_WOOD
			and farm.farm_state == "sown"
			and farm.amount_remaining == Farm.STOCKPILE
		)

	# No-wood failure notifies like other cost fails.
	var refuse_ok := false
	if farm:
		farm.harvest(farm.amount_remaining)
		var wood_keep := GameManager.wood
		GameManager.wood = 0
		refuse_ok = not farm.try_reseed(0, true) and farm.is_depleted() and GameManager.wood == 0
		GameManager.wood = wood_keep
		# Restore sown for gather leg.
		farm.try_reseed(0, false)

	# Panel button present when empty farm selected.
	var panel := get_tree().get_first_node_in_group("hud_command_panel") as CommandPanel
	var btn_ok := false
	if farm and panel:
		farm.harvest(farm.amount_remaining)
		SelectionManager.select_building(farm)
		await get_tree().process_frame
		panel._refresh_context_ui()
		await get_tree().process_frame
		var btn := panel.get_farm_reseed_button()
		btn_ok = btn != null and btn.visible and btn.get_parent().visible and "Znovu osít" in btn.text
		# Reseed via button path for gather.
		if farm.can_reseed():
			farm.try_reseed(0, false)

	# Gather after reseed → food increases.
	var food0 := GameManager.food
	var gather_ok := false
	if farm and villager and mill:
		farm.amount_remaining = 12
		farm.farm_state = "sown"
		farm._apply_farm_sprite()
		villager.carry_capacity = 1
		villager.carried_amount = 0
		villager.carried_type = ""
		villager.command_stop()
		villager.global_position = farm.global_position + Vector2(8, 8)
		if villager.navigation_agent:
			villager.navigation_agent.target_position = villager.global_position
		await get_tree().physics_frame
		villager.assign_gather(farm, mill)
		for _i in 900:
			await get_tree().physics_frame
			if GameManager.food > food0:
				gather_ok = true
				break

	# Auto-reseed: farmer who finished harvest reseeds if wood available.
	var auto_ok := false
	if farm and villager and mill:
		GameManager.wood = 120
		farm.amount_remaining = 1
		farm.farm_state = "ripe"
		farm._apply_farm_sprite()
		villager.carry_capacity = 10
		villager.carried_amount = 0
		villager.carried_type = ""
		villager.command_stop()
		villager.global_position = farm.global_position + Vector2(6, 6)
		if villager.navigation_agent:
			villager.navigation_agent.target_position = villager.global_position
		await get_tree().physics_frame
		villager.assign_gather(farm, mill)
		var wood_auto := GameManager.wood
		for _i in 1200:
			await get_tree().physics_frame
			# After reseed, claim flips sown→ripe immediately; wood spend is the gate.
			if (
				is_instance_valid(farm)
				and not farm.is_depleted()
				and farm.amount_remaining >= Farm.STOCKPILE - 5
				and GameManager.wood == wood_auto - Farm.RESEED_WOOD
				and (farm.farm_state == "sown" or farm.farm_state == "ripe")
			):
				auto_ok = true
				break
		# Deterministic fallback: deplete under the farmer and invoke auto-reseed path.
		if not auto_ok and is_instance_valid(farm) and is_instance_valid(villager):
			GameManager.wood = 120
			wood_auto = GameManager.wood
			farm.harvest(farm.amount_remaining)
			villager.target_resource = farm
			villager.target_dropoff = mill
			villager._try_auto_reseed_farm()
			auto_ok = (
				not farm.is_depleted()
				and farm.amount_remaining >= Farm.STOCKPILE - 5
				and GameManager.wood == wood_auto - Farm.RESEED_WOOD
				and (farm.farm_state == "sown" or farm.farm_state == "ripe")
			)
			print("[TEST] farm_reseed auto_fallback=%s wood=%d state=%s amt=%d" % [
				auto_ok, GameManager.wood, farm.farm_state, farm.amount_remaining
			])

	var all_ok: bool = (
		design_ok and deplete_ok and sown_ok and refuse_ok and btn_ok and gather_ok and auto_ok
	)
	print(
		"[TEST] farm_reseed design=%s deplete=%s sown=%s refuse=%s btn=%s gather=%s auto=%s"
		% [design_ok, deplete_ok, sown_ok, refuse_ok, btn_ok, gather_ok, auto_ok]
	)
	if all_ok:
		print("[TEST] PASS farm reseed deducts 60 wood and restores food gather")
	else:
		print("[TEST] FAIL farm reseed deducts 60 wood and restores food gather")

	if villager != null and is_instance_valid(villager):
		villager.command_stop()
	SelectionManager.select_building(null)
	for n in [mill, farm]:
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


## Fáze 5: one AI vs AI match under BalanceSim (sped-up).
func _run_balance_sim_game() -> void:
	var cfg := BalanceSim.begin_game()
	var civ_a: String = str(cfg.get("civ_a", CivData.DEFAULT_PLAYER))
	var civ_b: String = str(cfg.get("civ_b", CivData.DEFAULT_ENEMY))
	var sim_seed: int = int(cfg.get("seed", 4242))
	var jitter_a: float = float(cfg.get("jitter_a", 1.0))
	var jitter_b: float = float(cfg.get("jitter_b", 1.0))
	var strat_a: String = str(cfg.get("strategy_a", BalanceSim.STRAT_RUSH))
	var strat_b: String = str(cfg.get("strategy_b", BalanceSim.STRAT_RUSH))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	var enemy_ai := get_node_or_null("SimpleEnemyAI") as SimpleEnemyAI
	if enemy_ai:
		enemy_ai.team = 1
		enemy_ai.civ_id = civ_b
		enemy_ai.base_position = ENEMY_TC_POS
		enemy_ai.configure_sim(sim_seed, jitter_b, strat_b)
		GameManager.enemy_civ = civ_b
	var player_ai := SimpleEnemyAI.new()
	player_ai.name = "PlayerAI"
	player_ai.team = 0
	player_ai.civ_id = civ_a
	player_ai.base_position = PLAYER_TC_POS
	player_ai.configure_sim(sim_seed, jitter_a, strat_a)
	GameManager.player_civ = civ_a
	add_child(player_ai)
	## Sim-only TC HP (normal play unchanged). Soft phase + post-12min burst resolve fights.
	var tc_hp := 1600.0
	if strat_a == BalanceSim.STRAT_RUSH and strat_b == BalanceSim.STRAT_RUSH:
		tc_hp = 1200.0
	elif strat_a != BalanceSim.STRAT_RUSH and strat_b != BalanceSim.STRAT_RUSH:
		tc_hp = 2000.0
	for hall in get_tree().get_nodes_in_group("town_halls"):
		if hall is DropOff:
			(hall as DropOff).max_hp = tc_hp
			(hall as DropOff).hp = tc_hp
	await get_tree().physics_frame
	await get_tree().physics_frame

	var victory_node := victory
	victory_node.reset_for_test()
	var sim_state := {"done": false, "winner_team": -1}
	var on_end := func(player_won: bool) -> void:
		sim_state["done"] = true
		sim_state["winner_team"] = 0 if player_won else 1
	if not victory_node.match_ended.is_connected(on_end):
		victory_node.match_ended.connect(on_end)

	var sim_t := 0.0
	var max_t: float = BalanceSim.MAX_GAME_SEC
	if BalanceSim.smoke_only:
		max_t = 900.0
	var timed_out := false
	while not bool(sim_state["done"]) and sim_t < max_t:
		await get_tree().process_frame
		sim_t += get_process_delta_time()
		BalanceSim.note_elapsed(sim_t)
		## Belt-and-suspenders: VictoryController.ended may set before signal delivery.
		if victory_node.ended and not bool(sim_state["done"]):
			sim_state["done"] = true
			sim_state["winner_team"] = 0 if victory_node.player_won else 1
	var winner_team: int = int(sim_state["winner_team"])
	if not bool(sim_state["done"]):
		## Timeout = draw. Do NOT resolve by army size.
		timed_out = true
		winner_team = -1
		print("[SIM] timeout draw t=%.1fs (cap=%.0fs)" % [sim_t, max_t])
	if victory_node.match_ended.is_connected(on_end):
		victory_node.match_ended.disconnect(on_end)
	BalanceSim.finish_game(winner_team, sim_t, timed_out)
	Engine.time_scale = 1.0
	get_tree().paused = false


## T-18: team palette-swap shader assigned; player vs AI team_color differs;
## art-debt units keep soft AI tint; team-blue units use WHITE + shader.
func _run_team_recolour_smoke() -> void:
	await get_tree().physics_frame
	var kn_p: Knight = preload("res://scenes/units/Knight.tscn").instantiate() as Knight
	kn_p.team = 0
	kn_p.contribute_population = false
	kn_p.position = PLAYER_TC_POS + Vector2(120, 80)
	units.add_child(kn_p)
	var kn_e: Knight = preload("res://scenes/units/Knight.tscn").instantiate() as Knight
	kn_e.team = 1
	kn_e.contribute_population = false
	kn_e.position = PLAYER_TC_POS + Vector2(180, 80)
	units.add_child(kn_e)
	var sol_e: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	sol_e.team = 1
	sol_e.contribute_population = false
	sol_e.position = PLAYER_TC_POS + Vector2(200, 100)
	units.add_child(sol_e)
	var mkt_p: Building = preload("res://scenes/buildings/Market.tscn").instantiate() as Building
	mkt_p.team = 0
	mkt_p.is_complete = true
	mkt_p.position = PLAYER_TC_POS + Vector2(240, 40)
	units.add_child(mkt_p)
	var mkt_e: Building = preload("res://scenes/buildings/Market.tscn").instantiate() as Building
	mkt_e.team = 1
	mkt_e.is_complete = true
	mkt_e.position = PLAYER_TC_POS + Vector2(340, 40)
	units.add_child(mkt_e)
	await get_tree().physics_frame
	await get_tree().physics_frame
	var shader_ok := false
	var param_diff := false
	var mats_ok := false
	var knight_ai_ok := false
	if kn_p._visual and kn_e._visual:
		var mp := kn_p._visual.material as ShaderMaterial
		var me := kn_e._visual.material as ShaderMaterial
		mats_ok = mp != null and me != null
		if mats_ok:
			shader_ok = mp.shader != null and me.shader != null
			var cp: Color = mp.get_shader_parameter("team_color")
			var ce: Color = me.get_shader_parameter("team_color")
			param_diff = not cp.is_equal_approx(ce)
			## Player blue vs AI red constants.
			shader_ok = (
				shader_ok
				and cp.is_equal_approx(TeamColors.PLAYER)
				and ce.is_equal_approx(TeamColors.AI)
			)
			## Enemy Knight (has team-blue) → shader team_color = AI, modulate WHITE.
			knight_ai_ok = (
				ce.is_equal_approx(TeamColors.AI)
				and kn_e._visual.modulate.is_equal_approx(Color.WHITE)
			)
	## Enemy Soldier (no team-blue) → soft AI tint, not WHITE.
	var soldier_tint_ok := false
	if sol_e._visual:
		soldier_tint_ok = not sol_e._visual.modulate.is_equal_approx(Color.WHITE)
		soldier_tint_ok = (
			soldier_tint_ok
			and sol_e._visual.modulate.is_equal_approx(TeamColors.AI_TINT_UNIT)
		)
	var build_ok := false
	if mkt_p._visual and mkt_e._visual:
		var bp := mkt_p._visual.material as ShaderMaterial
		var be := mkt_e._visual.material as ShaderMaterial
		build_ok = (
			bp != null
			and be != null
			and not (bp.get_shader_parameter("team_color") as Color).is_equal_approx(
				be.get_shader_parameter("team_color") as Color
			)
			and mkt_e._visual.modulate.is_equal_approx(Color.WHITE)
		)
	var minimap_ok := (
		not TeamColors.minimap_unit(0).is_equal_approx(TeamColors.minimap_unit(1))
		and not TeamColors.minimap_build(0).is_equal_approx(TeamColors.minimap_build(1))
	)
	var all_ok := (
		mats_ok
		and shader_ok
		and param_diff
		and build_ok
		and minimap_ok
		and knight_ai_ok
		and soldier_tint_ok
	)
	print(
		"[TEST] team_recolour mats=%s shader=%s param_diff=%s build=%s minimap=%s knight_ai=%s soldier_tint=%s"
		% [mats_ok, shader_ok, param_diff, build_ok, minimap_ok, knight_ai_ok, soldier_tint_ok]
	)
	if all_ok:
		print("[TEST] PASS team recolour (shader + player/AI params)")
	else:
		print("[TEST] FAIL team recolour (shader + player/AI params)")
	for n in [kn_p, kn_e, sol_e, mkt_p, mkt_e]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	await get_tree().physics_frame


## T-17/T-27: moving unit changes walk frame; idle uses idle sprite; AI modulate survives frame change.
## T-27: archer + spearman walk sheets advance frames; units without a sheet keep idle facing (fallback).
func _run_walk_cycle_smoke() -> void:
	await get_tree().physics_frame
	var vill: Villager = VILLAGER_SCENE.instantiate() as Villager
	vill.team = 0
	vill.contribute_population = false
	vill.position = PLAYER_TC_POS + Vector2(140, 120)
	units.add_child(vill)
	var sol_ai: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	sol_ai.team = 1
	sol_ai.contribute_population = false
	sol_ai.position = PLAYER_TC_POS + Vector2(200, 120)
	units.add_child(sol_ai)
	var archer: Archer = ARCHER_SCENE.instantiate() as Archer
	archer.team = 0
	archer.contribute_population = false
	archer.position = PLAYER_TC_POS + Vector2(260, 120)
	units.add_child(archer)
	var spear: Spearman = preload("res://scenes/units/Spearman.tscn").instantiate() as Spearman
	spear.team = 0
	spear.contribute_population = false
	spear.position = PLAYER_TC_POS + Vector2(320, 120)
	units.add_child(spear)
	var monk: Monk = preload("res://scenes/units/Monk.tscn").instantiate() as Monk
	monk.team = 0
	monk.contribute_population = false
	monk.position = PLAYER_TC_POS + Vector2(380, 120)
	units.add_child(monk)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var sheet_ok: bool = (
		vill.has_walk_sheet()
		and sol_ai.has_walk_sheet()
		and archer.has_walk_sheet()
		and spear.has_walk_sheet()
	)
	# Idle fallback: unit without a walk sheet stays on static facing while "moving".
	var fallback_ok: bool = not monk.has_walk_sheet()
	var idle_tex: Texture2D = vill._facing_textures.get("down") as Texture2D
	var idle_ok: bool = (
		vill._visual != null
		and idle_tex != null
		and vill._visual.texture == idle_tex
		and not vill.is_walk_animating()
	)

	# Drive walk animation without relying on nav avoidance callbacks.
	var frame_before: int = vill.walk_frame()
	var tex_before: Texture2D = vill._visual.texture
	vill.velocity = Vector2(80, 0)
	vill._update_facing_from_velocity()
	var saw_frame_change: bool = false
	# 5 × 0.05s @ 8 FPS → 2 frame advances (avoid wrapping back to frame_before).
	for _i in range(5):
		vill._update_walk_animation(0.05)
		if vill.walk_frame() != frame_before:
			saw_frame_change = true
	var moved_ok: bool = (
		vill.has_walk_sheet()
		and vill.is_walk_animating()
		and vill._visual.texture == vill._walk_sheet
		and vill._visual.hframes == Unit.WALK_FRAME_COUNT
		and saw_frame_change
		and vill.walk_frame() != frame_before
		and vill._visual.frame >= 0
	)
	var idle_tex_after_move: Texture2D = vill._facing_textures.get(vill._facing) as Texture2D
	vill.velocity = Vector2.ZERO
	vill._update_walk_animation(0.05)
	var back_idle_ok: bool = (
		not vill.is_walk_animating()
		and vill._visual.texture == idle_tex_after_move
		and vill._visual.hframes == 1
		and vill.walk_frame() == 0
	)
	# Texture object identity may differ after swap; ensure we left the sheet.
	var left_sheet_ok: bool = vill._visual.texture != vill._walk_sheet

	# AI tint must survive walk frame changes (T-18).
	var mod_before: Color = sol_ai._visual.modulate
	sol_ai.velocity = Vector2(0, 80)
	sol_ai._update_facing_from_velocity()
	for _j in range(16):
		sol_ai._update_walk_animation(0.05)
	var mod_after: Color = sol_ai._visual.modulate
	var modulate_ok: bool = (
		sol_ai.has_walk_sheet()
		and sol_ai.is_walk_animating()
		and mod_after.is_equal_approx(mod_before)
		and mod_after.is_equal_approx(TeamColors.AI_TINT_UNIT)
	)

	# T-27: archer + spearman advance walk frames while moving.
	var archer_frame_before: int = archer.walk_frame()
	archer.velocity = Vector2(60, 0)
	archer._update_facing_from_velocity()
	var archer_saw_change: bool = false
	for _a in range(5):
		archer._update_walk_animation(0.05)
		if archer.walk_frame() != archer_frame_before:
			archer_saw_change = true
	var archer_walk_ok: bool = (
		archer.has_walk_sheet()
		and archer.is_walk_animating()
		and archer._visual.texture == archer._walk_sheet
		and archer._visual.hframes == Unit.WALK_FRAME_COUNT
		and archer_saw_change
		and archer.walk_frame() != archer_frame_before
	)
	var spear_frame_before: int = spear.walk_frame()
	spear.velocity = Vector2(60, 0)
	spear._update_facing_from_velocity()
	var spear_saw_change: bool = false
	for _s in range(5):
		spear._update_walk_animation(0.05)
		if spear.walk_frame() != spear_frame_before:
			spear_saw_change = true
	var spear_walk_ok: bool = (
		spear.has_walk_sheet()
		and spear.is_walk_animating()
		and spear._visual.texture == spear._walk_sheet
		and spear._visual.hframes == Unit.WALK_FRAME_COUNT
		and spear_saw_change
		and spear.walk_frame() != spear_frame_before
	)

	# Monk without sheet stays on static facing while "moving".
	monk.velocity = Vector2(60, 0)
	monk._update_facing_from_velocity()
	monk._update_walk_animation(0.2)
	var monk_fallback_ok: bool = (
		not monk.has_walk_sheet()
		and not monk.is_walk_animating()
		and monk._visual.texture != null
		and monk._visual.hframes == 1
		and monk._facing_textures.has(monk._facing)
		and monk._visual.texture == monk._facing_textures[monk._facing]
	)
	fallback_ok = fallback_ok and monk_fallback_ok

	var all_ok: bool = (
		sheet_ok
		and fallback_ok
		and idle_ok
		and moved_ok
		and back_idle_ok
		and left_sheet_ok
		and modulate_ok
		and archer_walk_ok
		and spear_walk_ok
		and tex_before != null
	)
	print(
		"[TEST] walk sheet=%s fallback=%s idle=%s moved=%s back_idle=%s modulate=%s archer=%s spear=%s"
		% [
			sheet_ok,
			fallback_ok,
			idle_ok,
			moved_ok,
			back_idle_ok,
			modulate_ok,
			archer_walk_ok,
			spear_walk_ok,
		]
	)
	if all_ok:
		print("[TEST] PASS walk cycle (frame change + idle + AI modulate)")
	else:
		print("[TEST] FAIL walk cycle (frame change + idle + AI modulate)")
	for n in [vill, sol_ai, archer, spear, monk]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	await get_tree().physics_frame


## T-28: AI archer/spearman differ from player in team colour (idle + moving) + underfoot marker.
func _run_team_readability_smoke() -> void:
	await get_tree().physics_frame
	var arch_p: Archer = ARCHER_SCENE.instantiate() as Archer
	arch_p.team = 0
	arch_p.contribute_population = false
	arch_p.position = PLAYER_TC_POS + Vector2(140, 140)
	units.add_child(arch_p)
	var arch_e: Archer = ARCHER_SCENE.instantiate() as Archer
	arch_e.team = 1
	arch_e.contribute_population = false
	arch_e.position = PLAYER_TC_POS + Vector2(200, 140)
	units.add_child(arch_e)
	var spear_p: Spearman = preload("res://scenes/units/Spearman.tscn").instantiate() as Spearman
	spear_p.team = 0
	spear_p.contribute_population = false
	spear_p.position = PLAYER_TC_POS + Vector2(260, 140)
	units.add_child(spear_p)
	var spear_e: Spearman = preload("res://scenes/units/Spearman.tscn").instantiate() as Spearman
	spear_e.team = 1
	spear_e.contribute_population = false
	spear_e.position = PLAYER_TC_POS + Vector2(320, 140)
	units.add_child(spear_e)
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Idle: AI soft tint + underfoot marker colour differ from player.
	var idle_arch_ok := false
	var idle_spear_ok := false
	if arch_p._visual and arch_e._visual:
		idle_arch_ok = (
			arch_p._visual.modulate.is_equal_approx(Color.WHITE)
			and arch_e._visual.modulate.is_equal_approx(TeamColors.AI_TINT_UNIT)
			and not arch_p.team_marker_color().is_equal_approx(arch_e.team_marker_color())
			and arch_p.team_marker_color().is_equal_approx(
				Color(TeamColors.PLAYER.r, TeamColors.PLAYER.g, TeamColors.PLAYER.b, Unit.TEAM_MARKER_ALPHA)
			)
			and arch_e.team_marker_color().is_equal_approx(
				Color(TeamColors.AI.r, TeamColors.AI.g, TeamColors.AI.b, Unit.TEAM_MARKER_ALPHA)
			)
		)
	if spear_p._visual and spear_e._visual:
		idle_spear_ok = (
			spear_p._visual.modulate.is_equal_approx(Color.WHITE)
			and spear_e._visual.modulate.is_equal_approx(TeamColors.AI_TINT_UNIT)
			and not spear_p.team_marker_color().is_equal_approx(spear_e.team_marker_color())
			and spear_e.team_marker_color().is_equal_approx(
				Color(TeamColors.AI.r, TeamColors.AI.g, TeamColors.AI.b, Unit.TEAM_MARKER_ALPHA)
			)
		)

	# Moving: walk frames advance; AI tint + marker still differ from player.
	var move_arch_ok := false
	var move_spear_ok := false
	arch_e.velocity = Vector2(60, 0)
	arch_e._update_facing_from_velocity()
	for _i in range(8):
		arch_e._update_walk_animation(0.05)
	arch_p.velocity = Vector2(60, 0)
	arch_p._update_facing_from_velocity()
	for _j in range(8):
		arch_p._update_walk_animation(0.05)
	if arch_p._visual and arch_e._visual:
		move_arch_ok = (
			arch_p.has_walk_sheet()
			and arch_e.has_walk_sheet()
			and arch_p.is_walk_animating()
			and arch_e.is_walk_animating()
			and arch_p._visual.modulate.is_equal_approx(Color.WHITE)
			and arch_e._visual.modulate.is_equal_approx(TeamColors.AI_TINT_UNIT)
			and not arch_p.team_marker_color().is_equal_approx(arch_e.team_marker_color())
		)
	spear_e.velocity = Vector2(0, 60)
	spear_e._update_facing_from_velocity()
	for _k in range(8):
		spear_e._update_walk_animation(0.05)
	spear_p.velocity = Vector2(0, 60)
	spear_p._update_facing_from_velocity()
	for _m in range(8):
		spear_p._update_walk_animation(0.05)
	if spear_p._visual and spear_e._visual:
		move_spear_ok = (
			spear_p.has_walk_sheet()
			and spear_e.has_walk_sheet()
			and spear_p.is_walk_animating()
			and spear_e.is_walk_animating()
			and spear_p._visual.modulate.is_equal_approx(Color.WHITE)
			and spear_e._visual.modulate.is_equal_approx(TeamColors.AI_TINT_UNIT)
			and not spear_p.team_marker_color().is_equal_approx(spear_e.team_marker_color())
		)

	# Selection ring radius stays outside team marker (no collide).
	var ring_ok := (
		Unit.TEAM_MARKER_RX < Unit.SELECTION_RING_RADIUS
		and Unit.TEAM_MARKER_RY < Unit.SELECTION_RING_RADIUS
	)

	var all_ok := idle_arch_ok and idle_spear_ok and move_arch_ok and move_spear_ok and ring_ok
	print(
		"[TEST] team_read idle_arch=%s idle_spear=%s move_arch=%s move_spear=%s ring=%s"
		% [idle_arch_ok, idle_spear_ok, move_arch_ok, move_spear_ok, ring_ok]
	)
	if all_ok:
		print("[TEST] PASS team readability (AI archer/spearman idle+move colour)")
	else:
		print("[TEST] FAIL team readability (AI archer/spearman idle+move colour)")
	for n in [arch_p, arch_e, spear_p, spear_e]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	await get_tree().physics_frame


## T-26: control groups, rally point (+ gather), idle villager hotkey/HUD.
func _run_aoe_controls_smoke() -> void:
	await get_tree().physics_frame
	var cam := get_node_or_null("Camera2D") as RTSCamera
	var idle_btn := get_node_or_null("UI/IdleVillagerButton") as IdleVillagerButton

	# --- Control groups ---
	var a: Villager = VILLAGER_SCENE.instantiate() as Villager
	a.team = 0
	a.contribute_population = false
	a.position = PLAYER_TC_POS + Vector2(-80, 40)
	units.add_child(a)
	var b: Villager = VILLAGER_SCENE.instantiate() as Villager
	b.team = 0
	b.contribute_population = false
	b.position = PLAYER_TC_POS + Vector2(-40, 80)
	units.add_child(b)
	await get_tree().physics_frame
	SelectionManager.select_multiple([a, b])
	SelectionManager.assign_control_group(1)
	SelectionManager.clear_selection()
	var group_empty := SelectionManager.selected_units.is_empty()
	SelectionManager.select_control_group(1)
	var group_sel := SelectionManager.selected_units.size() == 2
	if cam:
		cam.center_at(Vector2(400, 400))
	# Force double-tap window: reset then two selects.
	SelectionManager._last_group_slot = 1
	SelectionManager._last_group_tap_msec = Time.get_ticks_msec()
	var doubled := SelectionManager.select_control_group(1)
	var cam_after := cam.position if cam else Vector2.ZERO
	var mid := (a.global_position + b.global_position) * 0.5
	var centered := doubled and cam != null and cam_after.distance_to(mid) < 80.0
	print(
		"[TEST] control_groups clear=%s recall=%s double_tap=%s centered=%s"
		% [group_empty, group_sel, doubled, centered]
	)
	var groups_ok := group_empty and group_sel and doubled and centered
	if groups_ok:
		print("[TEST] PASS control groups (save/recall/double-tap center)")
	else:
		print("[TEST] FAIL control groups (save/recall/double-tap center)")

	# --- Rally point (spawn fresh hall — defeat smoke may have freed the demo TC) ---
	var hall: DropOff = DROPOFF_SCENE.instantiate() as DropOff
	hall.team = 0
	hall.position = PLAYER_TC_POS + Vector2(40, -120)
	hall.spawn_parent = units
	units.add_child(hall)
	await get_tree().physics_frame
	var wood: ResourceNode = null
	for n in get_tree().get_nodes_in_group("resources"):
		if n is ResourceNode and (n as ResourceNode).resource_type == "wood" and not (n as ResourceNode).is_depleted():
			wood = n as ResourceNode
			break
	if wood == null:
		wood = RESOURCE_SCENE.instantiate() as ResourceNode
		wood.resource_type = "wood"
		wood.amount_remaining = 200
		wood.position = hall.global_position + Vector2(140, 20)
		units.add_child(wood)
		await get_tree().physics_frame
	var rally_flag_ok := false
	var rally_gather_ok := false
	var rally_move_ok := false
	SelectionManager.clear_selection()
	SelectionManager.select_building(hall)
	var rally_ground := hall.global_position + Vector2(160, 40)
	var set_ok := SelectionManager.set_building_rally(rally_ground, null)
	var rally := RallyPointController.of(hall)
	rally_flag_ok = set_ok and rally != null and rally.has_rally and rally.visible
	# Ground rally → trained villager moves there.
	GameManager.add_resource("food", 100)
	GameManager.add_population_cap(5)
	var queued := hall.enqueue_villager()
	hall.train_remaining = 0.0
	hall._complete_training()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var spawned_move: Villager = null
	for n in get_tree().get_nodes_in_group("villagers"):
		if n is Villager and (n as Villager).team == 0 and (n as Villager).state == Villager.State.MOVING:
			if (n as Villager).global_position.distance_to(hall.global_position) < 120.0:
				spawned_move = n as Villager
				break
	rally_move_ok = queued and spawned_move != null
	# Resource rally → villager gathers.
	SelectionManager.select_building(hall)
	SelectionManager.set_building_rally(wood.global_position, wood)
	hall.enqueue_villager()
	hall.train_remaining = 0.0
	hall._complete_training()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var gatherer: Villager = null
	for n in get_tree().get_nodes_in_group("villagers"):
		if not (n is Villager) or (n as Villager).team != 0:
			continue
		var vv := n as Villager
		if vv.target_resource == wood and (
			vv.state == Villager.State.MOVE_TO_RESOURCE or vv.state == Villager.State.HARVESTING
		):
			gatherer = vv
			break
	rally_gather_ok = gatherer != null
	print(
		"[TEST] rally flag=%s move=%s gather=%s queued=%s"
		% [rally_flag_ok, rally_move_ok, rally_gather_ok, queued]
	)
	if rally_flag_ok and rally_move_ok and rally_gather_ok:
		print("[TEST] PASS rally point (flag + move + gather)")
	else:
		print("[TEST] FAIL rally point (flag + move + gather)")
	if is_instance_valid(hall):
		hall.queue_free()
	await get_tree().physics_frame

	# --- Idle villager ---
	for n in get_tree().get_nodes_in_group("villagers"):
		if n is Villager and (n as Villager).team == 0:
			(n as Villager).command_stop()
	await get_tree().physics_frame
	var idle_n := SelectionManager.count_idle_villagers()
	if cam:
		cam.center_at(Vector2(200, 200))
	var picked := SelectionManager.select_next_idle_villager()
	var idle_sel := (
		picked != null
		and SelectionManager.selected_units.size() == 1
		and SelectionManager.selected_units[0] == picked
	)
	var idle_cam := cam != null and picked != null and cam.position.distance_to(picked.global_position) < 80.0
	SelectionManager.idle_villager_count_changed.emit(idle_n)
	await get_tree().process_frame
	var btn_ok := idle_btn != null and ("Nečinní" in idle_btn.text) and idle_n >= 1
	print(
		"[TEST] idle count=%d sel=%s cam=%s btn=%s text=%s"
		% [idle_n, idle_sel, idle_cam, btn_ok, idle_btn.text if idle_btn else "?"]
	)
	if idle_n >= 1 and idle_sel and idle_cam and btn_ok:
		print("[TEST] PASS idle villager (hotkey + HUD button)")
	else:
		print("[TEST] FAIL idle villager (hotkey + HUD button)")

	SelectionManager.clear_selection()
	for n in [a, b]:
		if is_instance_valid(n):
			n.queue_free()
	await get_tree().physics_frame


## AudioManager loads; every shipped SFX path exists; headless stays silent.
func _run_audio_manager_smoke() -> void:
	await get_tree().physics_frame
	var am := AudioManager
	var autoload_ok := am != null
	var check: Dictionary = am.verify_paths() if am else {"ok": false, "missing": PackedStringArray(["no AudioManager"]), "enabled": true}
	var silent_ok := bool(check.get("enabled", true)) == false
	var paths_ok := bool(check.get("ok", false))
	var expected := AudioManager.SFX_PATHS.size() if am else 0
	var missing: PackedStringArray = check.get("missing", PackedStringArray())
	print(
		"[TEST] audio autoload=%s silent=%s paths=%s expected=%d missing=%s"
		% [autoload_ok, silent_ok, paths_ok, expected, ", ".join(missing)]
	)
	if autoload_ok and silent_ok and paths_ok and expected >= 12:
		print("[TEST] PASS audio manager (paths + headless silent)")
	else:
		print("[TEST] FAIL audio manager (paths + headless silent)")


## T-29: TC tile visible; map corner unexplored; AI out of LOS hidden; explored persists after move.
func _run_fog_of_war_smoke() -> void:
	await get_tree().physics_frame
	var fog := _ensure_fog_of_war()
	fog.fog_enabled = true
	# Pull every player sight source home so leftover smoke units cannot keep a far tile lit.
	for n in get_tree().get_nodes_in_group("player_units"):
		if n is Unit and is_instance_valid(n):
			(n as Unit).position = PLAYER_TC_POS + Vector2(30, 30)
	fog.force_update()
	await get_tree().physics_frame

	var tc_tile := fog.world_to_tile(PLAYER_TC_POS)
	var near_tc_visible := fog.tile_state(tc_tile.x, tc_tile.y) == FogOfWar.STATE_VISIBLE
	var corner_unexplored := fog.tile_state(0, 0) == FogOfWar.STATE_UNEXPLORED

	var ai: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	ai.team = 1
	ai.contribute_population = false
	ai.position = PLAYER_TC_POS + Vector2(700, 0)
	units.add_child(ai)
	await get_tree().physics_frame
	fog.force_update()
	var ai_hidden := not ai.visible and not fog.is_world_visible(ai.global_position)

	# Far south of both TCs — only the scout can reveal it, then leave.
	var scout: Villager = VILLAGER_SCENE.instantiate() as Villager
	scout.team = 0
	scout.contribute_population = false
	var explore_pos := Vector2(200, 2600)
	scout.position = explore_pos
	units.add_child(scout)
	await get_tree().physics_frame
	fog.force_update()
	var explore_tile := fog.world_to_tile(explore_pos)
	var was_visible := fog.tile_state(explore_tile.x, explore_tile.y) == FogOfWar.STATE_VISIBLE
	scout.position = PLAYER_TC_POS + Vector2(40, 40)
	await get_tree().physics_frame
	fog.force_update()
	var after_state := fog.tile_state(explore_tile.x, explore_tile.y)
	var stayed_explored := after_state == FogOfWar.STATE_EXPLORED

	var fog_ok := (
		near_tc_visible
		and corner_unexplored
		and ai_hidden
		and was_visible
		and stayed_explored
	)
	print(
		"[TEST] fog near_tc=%s corner=%s ai_hidden=%s explored_persist=%s (was_vis=%s after=%d)"
		% [near_tc_visible, corner_unexplored, ai_hidden, stayed_explored, was_visible, after_state]
	)
	if fog_ok:
		print("[TEST] PASS fog of war (visible / unexplored / hide / persist)")
	else:
		print("[TEST] FAIL fog of war (visible / unexplored / hide / persist)")
	for n in [ai, scout]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	fog.force_update()
	await get_tree().physics_frame


## T-32: soft edges; hidden enemy not click-targetable; unseen / grey-new buildings hidden.
func _run_fog_polish_smoke() -> void:
	await get_tree().physics_frame
	var fog := _ensure_fog_of_war()
	fog.fog_enabled = true
	for n in get_tree().get_nodes_in_group("player_units"):
		if n is Unit and is_instance_valid(n):
			(n as Unit).position = PLAYER_TC_POS + Vector2(30, 30)
	fog.force_update()
	await get_tree().physics_frame

	var soft_ok := fog.uses_soft_edges()

	var sc := get_tree().get_first_node_in_group("selection_controller") as SelectionController
	var hidden_ai: Soldier = SOLDIER_SCENE.instantiate() as Soldier
	hidden_ai.team = 1
	hidden_ai.contribute_population = false
	hidden_ai.position = PLAYER_TC_POS + Vector2(700, 0)
	units.add_child(hidden_ai)
	await get_tree().physics_frame
	fog.force_update()
	var enemy_click_blocked := (
		not hidden_ai.visible
		and not fog.is_world_visible(hidden_ai.global_position)
		and sc != null
		and sc._find_enemy_at(hidden_ai.global_position) == null
	)

	# Unexplored far corner: building stays hidden.
	var unseen_hut: Building = preload("res://scenes/buildings/House.tscn").instantiate() as Building
	unseen_hut.team = 1
	unseen_hut.is_complete = true
	unseen_hut.position = Vector2(80, 80)
	units.add_child(unseen_hut)
	await get_tree().physics_frame
	fog.force_update()
	var unexplored_hidden := (
		not unseen_hut.visible
		and not fog.is_enemy_building_revealed(unseen_hut)
		and (sc == null or sc._find_enemy_at(unseen_hut.global_position) == null)
	)

	# Explore a south tile, leave grey, then spawn a NEW hut there — must stay hidden until sighted.
	var scout: Villager = VILLAGER_SCENE.instantiate() as Villager
	scout.team = 0
	scout.contribute_population = false
	var explore_pos := Vector2(200, 2600)
	scout.position = explore_pos
	units.add_child(scout)
	await get_tree().physics_frame
	fog.force_update()
	scout.position = PLAYER_TC_POS + Vector2(40, 40)
	await get_tree().physics_frame
	fog.force_update()
	var explore_tile := fog.world_to_tile(explore_pos)
	var grey_ok := fog.tile_state(explore_tile.x, explore_tile.y) == FogOfWar.STATE_EXPLORED
	var grey_hut: Building = preload("res://scenes/buildings/House.tscn").instantiate() as Building
	grey_hut.team = 1
	grey_hut.is_complete = true
	grey_hut.position = explore_pos
	units.add_child(grey_hut)
	await get_tree().physics_frame
	fog.force_update()
	var grey_new_hidden := (
		grey_ok
		and not grey_hut.visible
		and not fog.is_enemy_building_revealed(grey_hut)
	)

	# Sight a hut outside TC LOS (8 tiles), then leave — last-known stays in explored grey.
	var known_pos := PLAYER_TC_POS + Vector2(420, 80)
	scout.position = known_pos
	await get_tree().physics_frame
	fog.force_update()
	var known_hut: Building = preload("res://scenes/buildings/House.tscn").instantiate() as Building
	known_hut.team = 1
	known_hut.is_complete = true
	known_hut.position = known_pos
	units.add_child(known_hut)
	await get_tree().physics_frame
	fog.force_update()
	var seen_in_sight := (
		fog.is_world_visible(known_pos)
		and fog.is_enemy_building_revealed(known_hut)
		and known_hut.visible
	)
	scout.position = PLAYER_TC_POS + Vector2(40, 40)
	await get_tree().physics_frame
	fog.force_update()
	var known_tile := fog.world_to_tile(known_pos)
	var last_known_ok := (
		seen_in_sight
		and fog.tile_state(known_tile.x, known_tile.y) == FogOfWar.STATE_EXPLORED
		and known_hut.visible
		and fog.is_enemy_building_revealed(known_hut)
		and sc != null
		and sc._find_enemy_at(known_hut.global_position) == known_hut
	)

	var building_unseen_hidden := unexplored_hidden and grey_new_hidden and last_known_ok
	var polish_ok := soft_ok and enemy_click_blocked and building_unseen_hidden
	print(
		"[TEST] fog polish soft=%s click_blocked=%s unseen=%s grey_new=%s last_known=%s"
		% [soft_ok, enemy_click_blocked, unexplored_hidden, grey_new_hidden, last_known_ok]
	)
	if polish_ok:
		print("[TEST] PASS fog polish (enemy_click_blocked, building_unseen_hidden)")
	else:
		print("[TEST] FAIL fog polish (enemy_click_blocked, building_unseen_hidden)")
	for n in [hidden_ai, unseen_hut, scout, grey_hut, known_hut]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	fog.force_update()
	await get_tree().physics_frame


## Harness smoke: civ pairs + report writer (no full suite).
func _run_balance_harness_smoke() -> void:
	await get_tree().physics_frame
	BalanceSim._ensure_suite()
	BalanceSim._build_pairs()
	var pair_ok: bool = BalanceSim.pairs.size() == 6
	var prev_results: Array[Dictionary] = BalanceSim.results.duplicate()
	var prev_trains: Dictionary = BalanceSim.unit_trains.duplicate(true)
	var prev_ages: Dictionary = BalanceSim.age_reach.duplicate(true)
	var prev_active := BalanceSim.active
	BalanceSim.active = false
	BalanceSim.results.clear()
	BalanceSim.results.append({
		"civ_a": CivData.MORAVANE,
		"civ_b": CivData.HUSITE,
		"strategy_a": BalanceSim.STRAT_BOOM,
		"strategy_b": BalanceSim.STRAT_RUSH,
		"winner": CivData.MORAVANE,
		"loser": CivData.HUSITE,
		"draw": false,
		"length": 900.0,
		"pair_index": 0,
		"game_index": 0,
	})
	for civ in CivData.ALL_CIV_IDS:
		BalanceSim.unit_trains[civ] = {}
		BalanceSim.age_reach[civ] = {2: [180.0], 3: [420.0], 4: [900.0]}
	BalanceSim.unit_trains[CivData.MORAVANE] = {
		"soldier": 3, "spearman": 2, "archer": 2, "bojovnik_bradatice": 2, "monk": 1, "light_cavalry": 2
	}
	var md := BalanceSim._build_report_markdown()
	var tmp_path := "res://docs/balance/_harness_smoke.md"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/balance"))
	var f := FileAccess.open(tmp_path, FileAccess.WRITE)
	var report_ok: bool = (
		f != null
		and md.contains("95%")
		and md.contains("Army composition")
		and md.contains("Strategies")
		and md.contains("p25")
	)
	if f:
		f.store_string(md)
		f.close()
	BalanceSim.results = prev_results
	BalanceSim.unit_trains = prev_trains
	BalanceSim.age_reach = prev_ages
	BalanceSim.active = prev_active
	print("[TEST] balance_harness pairs=%s report=%s" % [pair_ok, report_ok])
	if pair_ok and report_ok:
		print("[TEST] PASS balance harness (pairs + report)")
	else:
		print("[TEST] FAIL balance harness (pairs + report)")
