extends SceneTree
## Prefer: Godot --path . --quit-after 8000 -- --formation-shot
## (Map.prepare_formation_screenshot saves docs/screenshots/pixel_art_formations.png)


func _initialize() -> void:
	print("[SHOT] hint: run main scene with -- --formation-shot")
	quit(0)
