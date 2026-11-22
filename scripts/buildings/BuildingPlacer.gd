extends Node2D
class_name BuildingPlacer

signal building_placed(building: Building)

const HOUSE_SCENE := preload("res://scenes/buildings/House.tscn")
const BARRACKS_SCENE := preload("res://scenes/buildings/Barracks.tscn")
const ARCHERY_SCENE := preload("res://scenes/buildings/ArcheryRange.tscn")
const LUMBER_SCENE := preload("res://scenes/buildings/LumberCamp.tscn")
const MILL_SCENE := preload("res://scenes/buildings/Mill.tscn")
const BLACKSMITH_SCENE := preload("res://scenes/buildings/Blacksmith.tscn")

const GHOST_TEXTURES := {
	"house": preload("res://assets/sprites/buildings/house.png"),
	"barracks": preload("res://assets/sprites/buildings/barracks.png"),
	"archery_range": preload("res://assets/sprites/buildings/archery_range.png"),
	"lumber_camp": preload("res://assets/sprites/buildings/lumber_camp.png"),
	"mill": preload("res://assets/sprites/buildings/mill.png"),
	"blacksmith": preload("res://assets/sprites/buildings/blacksmith.png"),
}

## DESIGN costs and base build times (1 villager).
const COSTS := {
	"house": {"wood": 25},
	"barracks": {"wood": 175},
	"archery_range": {"wood": 175},
	"lumber_camp": {"wood": 100},
	"mill": {"wood": 100},
	"blacksmith": {"wood": 150}, # NÁVRH
}

const BUILD_TIMES := {
	"house": 25.0,
	"barracks": 50.0,
	"archery_range": 50.0,
	"lumber_camp": 35.0,
	"mill": 35.0,
	"blacksmith": 40.0, # NÁVRH
}

const FOOTPRINTS := {
	"house": Vector2(56, 56),
	"barracks": Vector2(80, 80),
	"archery_range": Vector2(80, 80),
	"lumber_camp": Vector2(72, 72),
	"mill": Vector2(72, 72),
	"blacksmith": Vector2(80, 80),
}

@export var map_size: Vector2 = Vector2(3000, 3000)
@export var entities_path: NodePath = ^"../Units"

var placing_type: String = ""
var entities: Node2D
var _ghost: Sprite2D


func _ready() -> void:
	add_to_group("building_placer")
	entities = get_node_or_null(entities_path)
	_ghost = Sprite2D.new()
	_ghost.centered = true
	_ghost.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_ghost.z_index = 100
	_ghost.visible = false
	add_child(_ghost)


func begin_place(building_type: String) -> void:
	if building_type not in COSTS:
		return
	if not GameManager.is_building_unlocked(building_type):
		NotificationManager.show_message(
			"Zamčeno do věku %s." % AgeData.age_name(AgeData.building_unlock_age(building_type))
		)
		return
	placing_type = building_type
	_configure_ghost(building_type)
	_ghost.visible = true
	NotificationManager.show_message("Stavba: %s (LMB položit, RMB zrušit)" % building_type)


func cancel() -> void:
	placing_type = ""
	_ghost.visible = false


func place_at(building_type: String, world_pos: Vector2) -> Building:
	if building_type not in COSTS:
		return null
	if not GameManager.is_building_unlocked(building_type):
		NotificationManager.show_message(
			"Zamčeno do věku %s." % AgeData.age_name(AgeData.building_unlock_age(building_type))
		)
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
	# Mark incomplete before _ready so House/Pila/Mlýn skip pop/drop-off unlock.
	building.is_complete = false
	building.build_progress = 0.0
	entities.add_child(building)
	if building is Barracks:
		(building as Barracks).spawn_parent = entities
	elif building is ArcheryRange:
		(building as ArcheryRange).spawn_parent = entities
	var build_t: float = float(BUILD_TIMES.get(building_type, building.build_time))
	building.start_construction(build_t)
	_assign_builders(building)
	print("[BUILD] placed %s under construction (%.0fs) at %s" % [building_type, build_t, str(world_pos)])
	building_placed.emit(building)
	NotificationManager.show_message("Zakládám: %s" % building.display_name)
	return building


func _assign_builders(building: Building) -> void:
	var assigned := false
	for u in SelectionManager.selected_units:
		if u is Villager and is_instance_valid(u):
			(u as Villager).assign_build(building)
			assigned = true
	if assigned:
		return
	var best: Villager = null
	var best_d := 220.0
	for n in get_tree().get_nodes_in_group("villagers"):
		if not (n is Villager):
			continue
		var v := n as Villager
		if v.team != 0:
			continue
		var d := v.global_position.distance_to(building.global_position)
		if d < best_d:
			best_d = d
			best = v
	if best:
		best.assign_build(building)


func _process(_delta: float) -> void:
	if placing_type == "":
		return
	var mouse := get_global_mouse_position()
	_ghost.global_position = mouse
	var ok := _can_place(placing_type, mouse) and GameManager.can_afford(COSTS[placing_type])
	_ghost.modulate = Color(0.35, 1.0, 0.45, 0.45) if ok else Color(1.0, 0.35, 0.35, 0.45)


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
		"archery_range":
			return ARCHERY_SCENE.instantiate() as Building
		"lumber_camp":
			return LUMBER_SCENE.instantiate() as Building
		"mill":
			return MILL_SCENE.instantiate() as Building
		"blacksmith":
			return BLACKSMITH_SCENE.instantiate() as Building
		_:
			return null


func _configure_ghost(building_type: String) -> void:
	var tex: Texture2D = GHOST_TEXTURES.get(building_type)
	var footprint: Vector2 = FOOTPRINTS[building_type]
	_ghost.texture = tex
	_ghost.centered = true
	if tex:
		_ghost.offset = Vector2(0.0, footprint.y * 0.5 - float(tex.get_height()) * 0.5)
	_ghost.modulate = Color(1, 1, 1, 0.45)


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