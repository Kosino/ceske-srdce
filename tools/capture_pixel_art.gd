extends SceneTree
## Windowed capture: Map + Střelnice + Kovárna → docs/screenshots/pixel_art_age2.png


func _initialize() -> void:
	DisplayServer.window_set_size(Vector2i(1280, 720))
	var err := change_scene_to_file("res://scenes/map/Map.tscn")
	if err != OK:
		push_error("[SHOT] change_scene failed %s" % err)
		quit(1)
		return
	call_deferred("_capture_after_delay")


func _capture_after_delay() -> void:
	await create_timer(2.0).timeout
	var map := current_scene
	if map == null:
		push_error("[SHOT] no current_scene")
		quit(1)
		return
	var units: Node2D = map.get_node_or_null("Units") as Node2D
	var gm = root.get_node_or_null("/root/GameManager")
	if gm:
		gm.set("current_age", 2)
	if units:
		var archery = load("res://scenes/buildings/ArcheryRange.tscn").instantiate()
		archery.position = Vector2(820, 640)
		archery.set("is_complete", true)
		units.add_child(archery)
		var smith = load("res://scenes/buildings/Blacksmith.tscn").instantiate()
		smith.position = Vector2(1000, 760)
		smith.set("is_complete", true)
		units.add_child(smith)
	await create_timer(0.8).timeout
	var vp := root.get_viewport()
	var img: Image = vp.get_texture().get_image() if vp and vp.get_texture() else null
	if img == null or img.get_width() < 2:
		push_error("[SHOT] empty image")
		quit(1)
		return
	var dir := "res://docs/screenshots"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var path := "%s/pixel_art_age2.png" % dir
	var save_err := img.save_png(path)
	if save_err != OK:
		push_error("[SHOT] save failed %s" % save_err)
		quit(1)
		return
	print("[SHOT] saved %s %dx%d" % [ProjectSettings.globalize_path(path), img.get_width(), img.get_height()])
	quit(0)
