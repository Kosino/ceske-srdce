extends Node2D
class_name BuildingPlacer

signal building_placed(building: Building)

const HOUSE_SCENE := preload("res://scenes/buildings/House.tscn")
const BARRACKS_SCENE := preload("res://scenes/buildings/Barracks.tscn")
const LUMBER_SCENE := preload("res://scenes/buildings/LumberCamp.tscn")
const MILL_SCENE := preload("res://scenes/buildings/Mill.tscn")

## DESIGN costs (build time not simulated in placer — instant place).
const COSTS := {
	"house": {"wood": 25},
	"barracks": {"wood": 175},
	"lumber_camp": {"wood": 100},
	"mill": {"wood": 100},
}

const FOOTPRINTS := {
	"house": Vector2(56, 56),
	"barracks": Vector2(80, 80),
	"lumber_camp": Vector2(72, 72),
	"mill": Vector2(72, 72),
}

@export var map_size: Vector2 = Vector2(3000, 3000)
@export var entities_path: NodePath = ^"../Units"

var placing_type: String = ""
var entities: Node2D
var _ghost: Polygon2D


func _ready() -> void:
	add_to_group("building_placer")
	entities = get_node_or_null(entities_path)
	_ghost = Polygon2D.new()
	_ghost.z_index = 100
	_ghost.visible = false
	add_child(_ghost)


func begin_place(building_type: String) -> void:
	if building_type not in COSTS:
		return
	placing_type = building_type
	_configure_ghost(FOOTPRINTS[building_type])
	_ghost.visible = true
	NotificationManager.show_message("Stavba: %s (LMB položit, RMB zrušit)" % building_type)


func cancel() -> void:
	placing_type = ""
	_ghost.visible = false


func place_at(building_type: String, world_pos: Vector2) -> Building:
	if building_type not in COSTS:
		return null
	if not _can_place(building_type, world_pos):
		return null
	if not GameManager.spend(COSTS[building_type]):
		NotificationManager.show_message("Nedostatek surovin.")
		return null
	var building := _instantiate_building(building_type)
	if building == null or entities == null:
		return null
	building.position = world_pos
	entities.add_child(building)
	if building is Barracks:
		(building as Barracks).spawn_parent = entities
	print("[BUILD] placed %s at %s" % [building_type, str(world_pos)])
	building_placed.emit(building)
	NotificationManager.show_message("Postaveno: %s" % building.display_name)
	return building


func _process(_delta: float) -> void:
	if placing_type == "":
		return
	var mouse := get_global_mouse_position()
	_ghost.global_position = mouse
	var ok := _can_place(placing_type, mouse) and GameManager.can_afford(COSTS[placing_type])
	_ghost.color = Color(0.2, 0.85, 0.3, 0.35) if ok else Color(0.9, 0.2, 0.2, 0.35)


func _unhandled_input(event: InputEvent) -> void:
	if placing_type == "":
		return
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			var built := place_at(placing_type, get_global_mouse_position())
			if built:
				cancel()
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel()
			get_viewport().set_input_as_handled()


func _instantiate_building(building_type: String) -> Building:
	match building_type:
		"house":
			return HOUSE_SCENE.instantiate() as Building
		"barracks":
			return BARRACKS_SCENE.instantiate() as Building
		"lumber_camp":
			return LUMBER_SCENE.instantiate() as Building
		"mill":
			return MILL_SCENE.instantiate() as Building
		_:
			return null


func _configure_ghost(size: Vector2) -> void:
	var half := size * 0.5
	_ghost.polygon = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y),
	])


func _can_place(building_type: String, world_pos: Vector2) -> bool:
	var size: Vector2 = FOOTPRINTS[building_type]
	var half := size * 0.5
	if world_pos.x - half.x < 0.0 or world_pos.y - half.y < 0.0:
		return false
	if world_pos.x + half.x > map_size.x or world_pos.y + half.y > map_size.y:
		return false
	if entities == null:
		return true
	for child in entities.get_children():
		if child is Building:
			var other := child as Building
			var min_dist := (other.footprint + size).length() * 0.35
			if world_pos.distance_to(other.global_position) < min_dist:
				return false
		elif child is DropOff:
			if world_pos.distance_to(child.global_position) < 90.0:
				return false
	return true