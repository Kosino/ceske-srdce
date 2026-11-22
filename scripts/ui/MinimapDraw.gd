extends Control
class_name MinimapDraw
## Draw surface for Minimap dots.


var host: Minimap


func _draw() -> void:
	if host:
		host.paint_minimap(self)
