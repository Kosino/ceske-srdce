extends Building
class_name Farm

## T-19: pole u mlýna — food stockpile gather (DESIGN 0.33/s). Reseed deferred.

signal depleted

const TEX_EMPTY := preload("res://assets/sprites/buildings/farm_empty.png")
const TEX_SOWN := preload("res://assets/sprites/buildings/farm_sown.png")
const TEX_RIPE := preload("res://assets/sprites/buildings/farm_ripe.png")
const TEX_DEFAULT := preload("res://assets/sprites/buildings/farm.png")

const STOCKPILE := 175
const GATHER_RADIUS := 44.0

## Duck-typed like ResourceNode for Villager.assign_gather.
var resource_type: String = "food"
var amount_remaining: int = 0
var gather_radius: float = GATHER_RADIUS

## Visual: sown (new) → ripe (farming) → empty (depleted). Reseed = deferred.
var farm_state: String = "sown"

var _farmer: Villager = null


func _ready() -> void:
	building_id = "farm"
	display_name = "Farma"
	footprint = Vector2(80, 80)
	max_hp = 480.0
	build_time = 15.0
	if is_complete and amount_remaining <= 0:
		amount_remaining = STOCKPILE
		farm_state = "sown"
	_final_texture = _texture_for_state(farm_state)
	super._ready()
	add_to_group("farms")
	_apply_farm_sprite()


func _on_construction_finished() -> void:
	amount_remaining = STOCKPILE
	farm_state = "sown"
	_farmer = null
	_apply_farm_sprite()


func is_depleted() -> bool:
	return amount_remaining <= 0


func try_claim_farmer(villager: Villager) -> bool:
	if villager == null or not is_instance_valid(villager):
		return false
	if not is_complete or is_depleted():
		return false
	if _farmer != null and is_instance_valid(_farmer) and _farmer != villager:
		return false
	_farmer = villager
	if farm_state == "sown" and amount_remaining > 0:
		farm_state = "ripe"
		_apply_farm_sprite()
	return true


func release_farmer(villager: Villager) -> void:
	if _farmer == villager:
		_farmer = null


func has_farmer() -> bool:
	return _farmer != null and is_instance_valid(_farmer)


func harvest(amount: int) -> int:
	if amount <= 0 or is_depleted() or not is_complete:
		return 0
	var taken := mini(amount, amount_remaining)
	amount_remaining -= taken
	if amount_remaining > 0 and farm_state != "ripe":
		farm_state = "ripe"
		_apply_farm_sprite()
	if is_depleted():
		farm_state = "empty"
		_apply_farm_sprite()
		_farmer = null
		depleted.emit()
	return taken


func set_farm_state(state: String) -> void:
	farm_state = state
	_apply_farm_sprite()


func czech_type_name() -> String:
	return "Jídlo (farma)"


func info_line() -> String:
	return "%s — zbývá %d" % [czech_type_name(), amount_remaining]


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
