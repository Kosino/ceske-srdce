extends Control
class_name MainMenu
## Title screen — pick player + AI civ, then Hrát.


const MAP_SCENE := "res://scenes/map/Map.tscn"
const CIV_ORDER := [
	CivData.MORAVANE,
	CivData.PREMYSLOVCI,
	CivData.HUSITE,
	CivData.HABSBURKOVE,
]

@onready var player_option: OptionButton = %PlayerCivOption
@onready var enemy_option: OptionButton = %EnemyCivOption
@onready var title_label: Label = %TitleLabel


func _ready() -> void:
	add_to_group("main_menu")
	_fill_civ_options()
	_select_civ(player_option, CivData.DEFAULT_PLAYER)
	_select_civ(enemy_option, CivData.DEFAULT_ENEMY)

	if DisplayServer.get_name() == "headless":
		await _run_menu_civ_smoke()
		# Reset defaults so Map smokes stay stable, then load Map (runs all headless tests).
		GameManager.player_civ = CivData.DEFAULT_PLAYER
		GameManager.enemy_civ = CivData.DEFAULT_ENEMY
		get_tree().change_scene_to_file(MAP_SCENE)
		return

	var args := OS.get_cmdline_user_args()
	if args.has("--menu-shot"):
		await _capture_menu_shot()
		return
	# Feature screenshots that need the map.
	for flag in [
		"--hud-shot", "--victory-shot", "--formation-shot", "--ai-shot",
		"--camera-shot", "--mines-shot", "--blacksmith-shot", "--stable-shot", "--castle-shot",
		"--art-shot", "--walls-shot", "--art-v2-shot", "--monk-shot", "--university-shot"
	]:
		if args.has(flag):
			get_tree().change_scene_to_file(MAP_SCENE)
			return


func _fill_civ_options() -> void:
	for opt in [player_option, enemy_option]:
		if opt == null:
			continue
		opt.clear()
		for id in CIV_ORDER:
			opt.add_item(CivData.civ_name(id))
			opt.set_item_metadata(opt.item_count - 1, id)


func _select_civ(opt: OptionButton, civ_id: String) -> void:
	if opt == null:
		return
	for i in opt.item_count:
		if str(opt.get_item_metadata(i)) == civ_id:
			opt.select(i)
			return


func selected_player_civ() -> String:
	if player_option == null or player_option.selected < 0:
		return CivData.DEFAULT_PLAYER
	return str(player_option.get_item_metadata(player_option.selected))


func selected_enemy_civ() -> String:
	if enemy_option == null or enemy_option.selected < 0:
		return CivData.DEFAULT_ENEMY
	return str(enemy_option.get_item_metadata(enemy_option.selected))


func apply_civ_selection() -> void:
	GameManager.player_civ = selected_player_civ()
	GameManager.enemy_civ = selected_enemy_civ()


func _on_play_pressed() -> void:
	apply_civ_selection()
	get_tree().change_scene_to_file(MAP_SCENE)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _run_menu_civ_smoke() -> void:
	_select_civ(player_option, CivData.PREMYSLOVCI)
	_select_civ(enemy_option, CivData.HABSBURKOVE)
	apply_civ_selection()
	var ok := (
		GameManager.player_civ == CivData.PREMYSLOVCI
		and GameManager.enemy_civ == CivData.HABSBURKOVE
	)
	print("[TEST] menu civs player=%s enemy=%s" % [GameManager.player_civ, GameManager.enemy_civ])
	if ok:
		print("[TEST] PASS menu sets player_civ / enemy_civ")
	else:
		print("[TEST] FAIL menu sets player_civ / enemy_civ")
	await get_tree().process_frame


func _capture_menu_shot() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	await get_tree().create_timer(0.8).timeout
	var img: Image = get_viewport().get_texture().get_image()
	if img == null or img.get_width() < 2:
		push_error("[SHOT] empty menu image")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/screenshots"))
	var path := "res://docs/screenshots/menu.png"
	var err := img.save_png(path)
	if err != OK:
		push_error("[SHOT] save failed %s" % err)
		get_tree().quit(1)
		return
	print("[SHOT] saved %s %dx%d" % [ProjectSettings.globalize_path(path), img.get_width(), img.get_height()])
	get_tree().quit(0)
