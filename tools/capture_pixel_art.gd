extends SceneTree
## One-shot: load Map, wait ~2.5s, save viewport PNG, quit.
## Run: godot --path . -s res://tools/capture_pixel_art.gd


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var packed: PackedScene = load("res://scenes/map/Map.tscn") as PackedScene
	if packed == null:
		push_error("[SHOT] failed to load Map.tscn")
		quit(1)
		return
	root.add_child(packed.instantiate())
	call_deferred("_capture_after_delay")


func _capture_after_delay() -> void:
	await create_timer(2.5).timeout
	var vp := root.get_viewport()
	if vp == null or vp.get_texture() == null:
		push_error("[SHOT] no viewport texture")
		quit(1)
		return
	var img: Image = vp.get_texture().get_image()
	if img == null or img.get_width() < 2:
		push_error("[SHOT] empty image")
		quit(1)
		return
	var dir := "res://docs/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/pixel_art.png" % dir
	var err := img.save_png(path)
	if err != OK:
		push_error("[SHOT] save failed err=%s" % err)
		quit(1)
		return
	print("[SHOT] saved %s %dx%d" % [ProjectSettings.globalize_path(path), img.get_width(), img.get_height()])
	quit(0)
