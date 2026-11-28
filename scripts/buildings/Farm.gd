extends Building
class_name Farm

## T-19: visual + placement only (pole u mlýna). No gather loop yet.
## DESIGN: mill drop-off food + farms; gather rate 0.33 noted for a later pass.

const TEX_EMPTY := preload("res://assets/sprites/buildings/farm_empty.png")
const TEX_SOWN := preload("res://assets/sprites/buildings/farm_sown.png")
const TEX_RIPE := preload("res://assets/sprites/buildings/farm_ripe.png")
const TEX_DEFAULT := preload("res://assets/sprites/buildings/farm.png")

## Visual growth state — empty / sown / ripe (default ripe for screenshots).
@export var farm_state: String = "ripe"


func _ready() -> void:
	building_id = "farm"
	display_name = "Farma"
	footprint = Vector2(80, 80)
	max_hp = 480.0
	build_time = 15.0
	_final_texture = _texture_for_state(farm_state)
	super._ready()
	add_to_group("farms")
	_apply_farm_sprite()


func set_farm_state(state: String) -> void:
	farm_state = state
	_apply_farm_sprite()


func _texture_for_state(state: String) -> Texture2D:
	match state:
		"empty":
			return TEX_EMPTY
		"sown":
			return TEX_SOWN
		"ripe":
			return TEX_RIPE
		_:
			return TEX_DEFAULT


func _apply_farm_sprite() -> void:
	var tex := _texture_for_state(farm_state)
	_final_texture = tex
	if _visual == null:
		_visual = get_node_or_null("Visual") as Sprite2D
	if _visual == null:
		return
	if is_complete:
		_visual.texture = tex
		_anchor_sprite(_visual, tex)
	_apply_team_visual()
