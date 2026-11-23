extends Unit
class_name Trebuchet
## Trebuchet — age 4. Buildings only; pack/unpack; long range with minimum.


const PACK_TIME := 8.0
const RANGE_MAX := 640.0 ## 16 tiles
const RANGE_MIN := 160.0 ## 4 tiles
const PACKED_SPEED := 48.0

var packed: bool = true
var _pack_timer: float = 0.0
var _packing: bool = false ## true = packing, false = unpacking when timer > 0
var _pending_attack: Node2D = null


func _ready() -> void:
	unit_id = "trebuchet"
	speed = PACKED_SPEED
	max_hp = 150.0
	attack_damage = 40.0
	bonus_vs_buildings = 0.0
	attack_range = RANGE_MAX
	min_attack_range = RANGE_MIN
	attack_cooldown = 8.0
	can_attack = false ## only when unpacked
	attack_type = "pierce"
	melee_armor = 2.0
	pierce_armor = 8.0
	buildings_only = true
	super._ready()
	configure_facing_sprites("trebuchet")
	add_to_group("soldiers")
	add_to_group("siege")
	if _visual:
		_visual.modulate = Color(0.7, 0.8, 0.95, 1.0) if team == 0 else Color(1.0, 0.5, 0.55, 1.0)


func _process(delta: float) -> void:
	if _pack_timer <= 0.0:
		return
	_pack_timer -= delta
	if _pack_timer > 0.0:
		return
	if _packing:
		packed = true
		can_attack = false
		speed = PACKED_SPEED
		print("[SIEGE] trebuchet packed team=%d" % team)
	else:
		packed = false
		can_attack = true
		speed = 0.0
		stop_movement()
		print("[SIEGE] trebuchet unpacked team=%d" % team)
		if is_instance_valid(_pending_attack):
			command_attack(_pending_attack)
			_pending_attack = null


func is_transitioning() -> bool:
	return _pack_timer > 0.0


func request_unpack() -> void:
	if not packed or is_transitioning():
		return
	stop_movement()
	_packing = false
	_pack_timer = 0.35 if DisplayServer.get_name() == "headless" else PACK_TIME
	print("[SIEGE] trebuchet unpacking (%.1fs)" % _pack_timer)


func request_pack() -> void:
	if packed or is_transitioning():
		return
	attack_target = null
	_packing = true
	_pack_timer = 0.35 if DisplayServer.get_name() == "headless" else PACK_TIME
	print("[SIEGE] trebuchet packing (%.1fs)" % _pack_timer)


func command_move(world_pos: Vector2, speed_cap: float = -1.0) -> void:
	_pending_attack = null
	if is_transitioning():
		return
	if not packed:
		## Pack first; move after pack finishes via pending goal.
		_pending_move = world_pos
		_pending_speed_cap = speed_cap
		request_pack()
		return
	super.command_move(world_pos, speed_cap)


var _pending_move: Vector2 = Vector2.INF
var _pending_speed_cap: float = -1.0


func command_attack(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not is_structure_target(target):
		print("[COMBAT] trebuchet refuse non-building %s" % target.name)
		return
	if is_transitioning():
		_pending_attack = target
		return
	if packed:
		_pending_attack = target
		request_unpack()
		return
	super.command_attack(target)


func _physics_process(delta: float) -> void:
	## Finish pack then honor pending move.
	if packed and not is_transitioning() and _pending_move != Vector2.INF:
		var goal := _pending_move
		var cap := _pending_speed_cap
		_pending_move = Vector2.INF
		_pending_speed_cap = -1.0
		super.command_move(goal, cap)
	super._physics_process(delta)
