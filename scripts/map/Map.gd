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

@onready var units: Node2D = $Units
@onready var building_placer: BuildingPlacer = $BuildingPlacer
@onready var victory: VictoryController = $VictoryController


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
	elif not Engine.is_editor_hint() and OS.get_cmdline_user_args().has("--formation-shot"):
		await prepare_formation_screenshot()
	else:
		await _sample_windowed_fps()
	NotificationManager.show_message("Start: Radnice + vesničané + zdroje. F3 stavění/trénink.")


## Windowed screenshot: 5 soldiers in line after group move; hide DebugPanel; save PNG; quit.
func prepare_formation_screenshot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var debug := get_node_or_null("DebugPanel")
	if debug:
		debug.visible = false
	var cam := get_node_or_null("Camera2D") as Camera2D
	var squad: Array = []
	var origin := Vector2(780, 820)
	for i in 5:
		var s: Soldier = SOLDIER_SCENE.instantiate() as Soldier
		s.team = 0
		s.contribute_population = false
		s.position = origin + Vector2(float(i) * 14.0, 0.0)
		units.add_child(s)
		squad.append(s)
	await get_tree().physics_frame
	SelectionManager.select_multiple(squad)
	SelectionManager.set_formation(FormationData.LINE)
	SelectionManager.issue_move(Vector2(1100, 820))
	await get_tree().create_timer(2.4).timeout
	var mid := Vector2.ZERO
	var n := 0
	for u in squad:
		if is_instance_valid(u):
			mid += (u as Node2D).global_position
			n += 1
	if n > 0:
		mid /= float(n)
	if cam:
		cam.position = mid + Vector2(40.0, -20.0)
		cam.zoom = Vector2(1.15, 1.15)
	await get_tree().process_frame
	await get_tree().process_frame
	var img: Image = get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 2:
		push_error("[SHOT] empty image")
		get_tree().quit(1)
		return
	var dir := "res://docs/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/pixel_art_formations.png" % dir
	var save_err := img.save_png(path)
	if save_err != OK:
		push_error("[SHOT] save failed %s" % save_err)
		get_tree().quit(1)
		return
	print("[SHOT] saved %s %dx%d squad=%d" % [
		ProjectSettings.globalize_path(path), img.get_width(), img.get_height(), squad.size()
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

	# 1-tile dirt: south from Radnice bottom edge (~4), then spur toward wood/forest.
	# Hall center ~ (22,17); footprint ~2×2 — start at y+2 so nothing under the building.
	var hall := Vector2i(900 / TILE, 700 / TILE)
	for i in range(2, 6):
		layer.set_cell(hall + Vector2i(0, i), SOURCE_DIRT, Vector2i.ZERO)
	# Spur east toward wood at ~(1080,620) / tile (27,15), then north a bit into forest.
	var spur_y := 4
	for dx in range(1, 5):
		layer.set_cell(hall + Vector2i(dx, spur_y), SOURCE_DIRT, Vector2i.ZERO)
	for dy in range(1, 3):
		layer.set_cell(hall + Vector2i(4, spur_y - dy), SOURCE_DIRT, Vector2i.ZERO)


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
	# DESIGN start: only Radnice, villagers, and resource nodes (no prebuilt House/Pila/combat).
	var hall: DropOff = DROPOFF_SCENE.instantiate()
	hall.team = 0
	hall.position = Vector2(900, 700)
	hall.spawn_parent = units
	units.add_child(hall)
	victory.watch_new_hall(hall)

	var wood: ResourceNode = RESOURCE_SCENE.instantiate()
	wood.resource_type = "wood"
	wood.amount_remaining = 200
	wood.position = Vector2(1080, 620)
	units.add_child(wood)

	var food: ResourceNode = RESOURCE_SCENE.instantiate()
	food.resource_type = "food"
	food.amount_remaining = 120
	food.position = Vector2(760, 820)
	units.add_child(food)

	for offset in [Vector2(940, 720), Vector2(920, 740), Vector2(960, 740)]:
		var villager: Villager = VILLAGER_SCENE.instantiate()
		villager.position = offset
		units.add_child(villager)


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
	var stone_m := GameManager.gather_rate_mult(0, "stone")
	var stone_ok := is_equal_approx(stone_m, 1.10) and CivData.HABSBURKOVE == "habsburkove"
	print("[TEST] civ_habsburkove stone_mult=%.2f id=%s" % [stone_m, CivData.HABSBURKOVE])

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
	if wood_ok and cost_ok and hp_ok and stone_ok and ids_ok:
		print("[TEST] PASS civ bonuses (wood / cost / infantry HP / stone / ids)")
	else:
		print("[TEST] FAIL civ bonuses (wood / cost / infantry HP / stone / ids)")


## Formation spacing + shared group move speed (slowest unit).
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
	SelectionManager.issue_move(dest)
	await get_tree().physics_frame

	var gap := FormationData.spacing(FormationData.LINE)
	var targets: Array[Vector2] = []
	for u in [a, b, c]:
		if u.navigation_agent:
			targets.append(u.navigation_agent.target_position)
	var pair_ds: Array[float] = []
	for i in targets.size():
		for j in range(i + 1, targets.size()):
			pair_ds.append(targets[i].distance_to(targets[j]))
	pair_ds.sort()
	var spacing_ok := pair_ds.size() == 3
	if spacing_ok:
		# Line of 3: two adjacent gaps + one double gap.
		spacing_ok = (
			is_equal_approx(pair_ds[0], gap)
			and is_equal_approx(pair_ds[1], gap)
			and is_equal_approx(pair_ds[2], gap * 2.0)
		)
		print("[TEST] formation_line pairs=%.1f,%.1f,%.1f expect=%.1f,%.1f,%.1f" % [
			pair_ds[0], pair_ds[1], pair_ds[2], gap, gap, gap * 2.0
		])

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

	if spacing_ok and speed_ok:
		print("[TEST] PASS formation spacing + shared speed")
	else:
		print("[TEST] FAIL formation spacing + shared speed")


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
