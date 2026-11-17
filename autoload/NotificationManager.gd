extends Node

func show_message(text: String, duration: float = 3.0) -> void:
	print("[NOTIFY] ", text)
	var label := Label.new()
	label.text = text
	label.position = Vector2(20, 100)
	add_child(label)
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(label):
		label.queue_free()
