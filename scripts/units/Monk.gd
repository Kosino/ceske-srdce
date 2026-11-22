extends Unit
class_name Monk
## Mnich — NÁVRH: 100 Z, 51 s, 30 HP. Heal allies + convert enemies. No melee attack.

enum MonkState { IDLE, MOVE_TO_HEAL, HEALING, MOVE_TO_CONVERT, CONVERTING }

const HEAL_RANGE := 4.0 * 40.0
const HEAL_PER_SEC := 4.0
const CONVERT_RANGE := 4.0 * 40.0
const CONVERT_TIME := 8.0

var monk_state: MonkState = MonkState.IDLE
var heal_target: Unit
var convert_target: Unit
var _convert_progress: float = 0.0
var _heal_accum: float = 0.0


func _ready() -> void:
	unit_id = "monk"
	can_attack = false
	max_hp = 30.0
	speed = 56.0 # 0.7×
	attack_damage = 0.0
	attack_range = HEAL_RANGE
	super._ready()
	configure_facing_sprites("monk")
	add_to_group("monks")
	_apply_team_visual()


func _apply_team_visual() -> void:
	if _visual == null:
		return
	_visual.modulate = Color(1, 1, 1, 1) if team == 0 else Color(1.0, 0.55, 0.55, 1.0)


func command_attack(target: Node2D) -> void:
	# Monks don't attack — convert enemies / heal friendlies via dedicated commands.
	if target is Unit and is_friendly_target(target):
		assign_heal(target as Unit)
	elif target is Unit:
		assign_convert(target as Unit)
	else:
		print("[MONK] refuse attack -> %s" % (target.name if target else "null"))


func assign_heal(target: Unit) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not is_friendly_target(target):
		return
	if target.hp >= target.max_hp - 0.5:
		NotificationManager.show_message("Jednotka je zdravá.")
		return
	heal_target = target
	convert_target = null
	_convert_progress = 0.0
	attack_target = null
	monk_state = MonkState.MOVE_TO_HEAL
	set_movement_target(target.global_position)
	print("[MONK] heal assigned -> %s" % target.name)


func assign_convert(target: Unit) -> void:
	if target == null or not is_instance_valid(target):
		return
	if is_friendly_target(target):
		return
	convert_target = target
	heal_target = null
	_convert_progress = 0.0
	attack_target = null
	monk_state = MonkState.MOVE_TO_CONVERT
	set_movement_target(target.global_position)
	print("[MONK] convert assigned -> %s" % target.name)


func command_move(world_pos: Vector2, speed_cap: float = -1.0) -> void:
	_clear_orders()
	monk_state = MonkState.IDLE
	super.command_move(world_pos, speed_cap)


func command_stop() -> void:
	_clear_orders()
	monk_state = MonkState.IDLE
	super.command_stop()


func _clear_orders() -> void:
	heal_target = null
	convert_target = null
	_convert_progress = 0.0
	_heal_accum = 0.0


func _physics_process(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	match monk_state:
		MonkState.MOVE_TO_HEAL:
			if not _heal_valid():
				_clear_orders()
				monk_state = MonkState.IDLE
				stop_movement()
				return
			set_movement_target(heal_target.global_position)
			_steer_toward_target()
			if global_position.distance_to(heal_target.global_position) <= HEAL_RANGE:
				monk_state = MonkState.HEALING
				stop_movement()
		MonkState.HEALING:
			stop_movement()
			if not _heal_valid() or heal_target.hp >= heal_target.max_hp - 0.5:
				_clear_orders()
				monk_state = MonkState.IDLE
				return
			_heal_accum += HEAL_PER_SEC * delta
			if _heal_accum >= 1.0:
				var chunk := floorf(_heal_accum)
				_heal_accum -= chunk
				heal_target.hp = minf(heal_target.max_hp, heal_target.hp + chunk)
				heal_target.queue_redraw()
				print("[MONK] healed %s +%.0f" % [heal_target.name, chunk])
		MonkState.MOVE_TO_CONVERT:
			if not _convert_valid():
				_clear_orders()
				monk_state = MonkState.IDLE
				stop_movement()
				return
			set_movement_target(convert_target.global_position)
			_steer_toward_target()
			if global_position.distance_to(convert_target.global_position) <= CONVERT_RANGE:
				monk_state = MonkState.CONVERTING
				stop_movement()
		MonkState.CONVERTING:
			stop_movement()
			if not _convert_valid():
				_clear_orders()
				monk_state = MonkState.IDLE
				return
			if global_position.distance_to(convert_target.global_position) > CONVERT_RANGE:
				monk_state = MonkState.MOVE_TO_CONVERT
				return
			_convert_progress += delta
			if _convert_progress >= CONVERT_TIME:
				_finish_convert()
		_:
			super._physics_process(delta)


func _heal_valid() -> bool:
	return heal_target != null and is_instance_valid(heal_target) and heal_target.hp > 0.0


func _convert_valid() -> bool:
	return convert_target != null and is_instance_valid(convert_target) and convert_target.hp > 0.0


func _finish_convert() -> void:
	if not _convert_valid():
		_clear_orders()
		monk_state = MonkState.IDLE
		return
	var u := convert_target
	var old_team := u.team
	# Flip team groups.
	if u.team == 0:
		u.remove_from_group("player_units")
		if u is Villager:
			u.remove_from_group("villagers")
		u.team = 1
		u.add_to_group("enemy_units")
		if u is Villager:
			u.add_to_group("villagers")
		GameManager.change_population(-1)
	else:
		u.remove_from_group("enemy_units")
		u.team = 0
		u.add_to_group("player_units")
		if u is Villager:
			u.add_to_group("villagers")
		GameManager.change_population(1)
	u.command_stop()
	u.queue_redraw()
	if u.has_method("_apply_team_visual"):
		u.call("_apply_team_visual")
	print("[MONK] converted %s team %d -> %d" % [u.name, old_team, u.team])
	NotificationManager.show_message("Konverze úspěšná.")
	_clear_orders()
	monk_state = MonkState.IDLE
