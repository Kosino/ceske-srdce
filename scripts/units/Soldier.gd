extends Unit
class_name Soldier


func _ready() -> void:
	speed = 90.0
	max_hp = 55.0
	super._ready()
	add_to_group("soldiers")
	if has_node("Visual"):
		$Visual.color = Color(0.75, 0.15, 0.15, 1.0)
