extends SceneTree
## Windowed capture → docs/screenshots/pixel_art_fix.png


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var err := change_scene_to_file("res://scenes/map/Map.tscn")
	if err != OK:
		push_error("[SHOT] change_scene failed %s" % err)
		quit(1)
		return
	call_deferred("_capture_after_delay")


func _capture_after_delay() -> void:
	await create_timer(2.2).timeout
	var vp := root.get_viewport()
	var img: Image = vp.get_texture().get_image() if vp and vp.get_texture() else null
	if img == null or img.get_width() < 2:
		push_error("[SHOT] empty image")
		quit(1)
		return
	var dir := "res://docs/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/pixel_art_fix.png" % dir
	var save_err := img.save_png(path)
	if save_err != OK:
		push_error("[SHOT] save failed %s" % save_err)
		quit(1)
		return
	print("[SHOT] saved %s %dx%d" % [ProjectSettings.globalize_path(path), img.get_width(), img.get_height()])
	quit(0)
