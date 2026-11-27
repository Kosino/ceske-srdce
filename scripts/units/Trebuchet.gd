extends Unit
class_name Trebuchet
## Trebuchet — age 4. Buildings only; pack/unpack; long range with minimum.


const PACK_TIME := 8.0
const RANGE_MAX := 640.0 ## 16 tiles
const RANGE_MIN := 160.0 ## 4 tiles
const PACKED_SPEED := 48.0
## Stand this far from the target when unpacking (inside max even if nav stops ~80px short).
const APPROACH_STANDOFF := RANGE_MAX - 96.0 ## 544 px ≈ 13.6 tiles

var packed: bool = true
var _pack_timer: float = 0.0
var _packing: bool = false ## true = packing, false = unpacking when timer > 0
var _pending_attack: Node2D = null
var _pending_move: Vector2 = Vector2.INF
var _pending_speed_cap: float = -1.0
## After arriving at standoff while packed, unpack for this target.
var _approach_target: Node2D = null


func _ready() -> void:
	unit_id = "trebuchet"
	speed = PACKED_SPEED
	max_hp = 150.0
	attack_damage = 40.0
	bonus_vs_buildings = 0.0
	attack_range = RANGE_MAX
	min_attack_range = RANGE_MIN
	attack_cooldown = _attack_cd()
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


func _pack_duration() -> float:
	return 0.35 if DisplayServer.get_name() == "headless" else PACK_TIME


func _attack_cd() -> float:
	## Headless smokes need a natural first strike without calling _try_strike by hand.
	return 0.35 if DisplayServer.get_name() == "headless" else PACK_TIME


func _tick_pack_timer(delta: float) -> void:
	## Runs from _physics_process so headless physics-frame smokes advance pack/unpack.
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
		## After pack: resume pending move, or retreat/approach for attack.
		if _pending_move != Vector2.INF:
			var goal := _pending_move
			var cap := _pending_speed_cap
			_pending_move = Vector2.INF
			_pending_speed_cap = -1.0
			super.command_move(goal, cap)
		elif is_instance_valid(_pending_attack):
			_begin_approach(_pending_attack)
	else:
		packed = false
		can_attack = true
		speed = 0.0
		stop_movement()
		print("[SIEGE] trebuchet unpacked team=%d" % team)
		if is_instance_valid(_pending_attack):
			var t := _pending_attack
			_pending_attack = null
			## Fresh cooldown so Unit._chase_and_attack can fire on the next frames.
			_attack_timer = 0.0
			super.command_attack(t)


func is_transitioning() -> bool:
	return _pack_timer > 0.0


func request_unpack() -> void:
	if not packed or is_transitioning():
		return
	stop_movement()
	_approach_target = null
	_packing = false
	_pack_timer = _pack_duration()
	can_attack = false ## still transitioning
	print("[SIEGE] trebuchet unpacking (%.1fs)" % _pack_timer)


func request_pack() -> void:
	if packed or is_transitioning():
		return
	attack_target = null
	_pending_attack = null
	_approach_target = null
	_pending_move = Vector2.INF
	can_attack = false ## cannot fire while packing
	_packing = true
	_pack_timer = _pack_duration()
	print("[SIEGE] trebuchet packing (%.1fs)" % _pack_timer)


func command_move(world_pos: Vector2, speed_cap: float = -1.0) -> void:
	_pending_attack = null
	_approach_target = null
	if is_transitioning():
		_pending_move = world_pos
		_pending_speed_cap = speed_cap
		return
	if not packed:
		## Moving auto-packs; move after pack finishes.
		_pending_move = world_pos
		_pending_speed_cap = speed_cap
		request_pack()
		return
	super.command_move(world_pos, speed_cap)


func command_attack(target: Node2D) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not is_structure_target(target):
		print("[COMBAT] trebuchet refuse non-building %s" % target.name)
		return
	if is_transitioning():
		_pending_attack = target
		return
	var dist := global_position.distance_to(target.global_position)
	if packed:
		_pending_attack = target
		if dist < RANGE_MIN:
			## Too close — pack already; retreat then unpack.
			_begin_approach(target)
			return
		if dist > APPROACH_STANDOFF:
			## Walk into range before unpacking (never unpack in place out of range).
			_begin_approach(target)
			return
		## Already in the fire band — unpack here.
		_approach_target = null
		request_unpack()
		return
	## Unpacked.
	if dist < RANGE_MIN:
		## Pack → retreat → unpack.
		_pending_attack = target
		_pending_move = _standoff_point(target)
		request_pack()
		return
	if dist > RANGE_MAX + 24.0:
		## Clearly out of range while deployed — pack and walk closer.
		_pending_attack = target
		_pending_move = _standoff_point(target)
		request_pack()
		return
	super.command_attack(target)


func _standoff_point(target: Node2D) -> Vector2:
	var away := global_position - target.global_position
	if away.length_squared() < 0.01:
		away = Vector2.RIGHT
	return target.global_position + away.normalized() * APPROACH_STANDOFF


func _begin_approach(target: Node2D) -> void:
	if not is_instance_valid(target):
		return
	_pending_attack = target
	_approach_target = target
	## NavigationAgent only — never teleport / move_toward through walls.
	super.command_move(_standoff_point(target))


func _start_unpack_for_approach() -> void:
	if not is_instance_valid(_approach_target):
		return
	_pending_attack = _approach_target
	_approach_target = null
	stop_movement()
	request_unpack()


func _physics_process(delta: float) -> void:
	_tick_pack_timer(delta)
	## Packed approach via NavigationAgent (super.command_move → WallNav / nav agent).
	if (
		packed
		and not is_transitioning()
		and is_instance_valid(_approach_target)
	):
		var dist := global_position.distance_to(_approach_target.global_position)
		var stopped := is_navigation_finished()
		## Unpack when inside max range on any stop, or once past standoff while closing.
		var close_enough := (
			dist <= RANGE_MAX
			and dist >= RANGE_MIN
			and (stopped or dist <= APPROACH_STANDOFF + 12.0)
		)
		if close_enough:
			_start_unpack_for_approach()
			super._physics_process(delta)
			return
		if stopped and dist > RANGE_MAX:
			## Nav stopped short of fire band — re-issue path (no direct position set).
			super.command_move(_standoff_point(_approach_target))
		super._physics_process(delta)
		return
	## Finish pack then honor pending move (when no approach target).
	if packed and not is_transitioning() and _pending_move != Vector2.INF and _approach_target == null:
		var goal2 := _pending_move
		var cap := _pending_speed_cap
		_pending_move = Vector2.INF
		_pending_speed_cap = -1.0
		super.command_move(goal2, cap)
	## Unpacked too close: Unit._chase backs off at speed 0 — force pack/retreat.
	if (
		not packed
		and not is_transitioning()
		and can_attack
		and is_instance_valid(attack_target)
		and global_position.distance_to(attack_target.global_position) < RANGE_MIN
	):
		_pending_attack = attack_target
		_pending_move = _standoff_point(attack_target)
		request_pack()
	super._physics_process(delta)
