extends Node2D

const MAP_SIZE := Vector2(2000, 2000)

@onready var navigation_region: NavigationRegion2D = $NavigationRegion2D


func _ready() -> void:
	_setup_navigation()
	NotificationManager.show_message("Mapa připravena. WASD pohyb, kolečko zoom.")


func _setup_navigation() -> void:
	var polygon := NavigationPolygon.new()
	polygon.add_outline(PackedVector2Array([
		Vector2.ZERO,
		Vector2(MAP_SIZE.x, 0.0),
		MAP_SIZE,
		Vector2(0.0, MAP_SIZE.y),
	]))
	polygon.make_polygons_from_outlines()
	navigation_region.navigation_polygon = polygon
