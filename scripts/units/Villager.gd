extends Unit
class_name Villager

enum State {
	IDLE, MOVING, MOVE_TO_RESOURCE, HARVESTING, MOVE_TO_DROPOFF,
	MOVE_TO_BUILD, BUILDING, MOVE_TO_REPAIR, REPAIRING
}

## DESIGN: wood 0.40/s; gold/stone = wood × 0.9; food bush 0.30; farm 0.33. Carry 10.
const WOOD_HARVEST_RATE := 0.40
const FARM_HARVEST_RATE := 0.33
const HARVEST_RATES := {
	"wood": WOOD_HARVEST_RATE,
	"food": 0.30,
	"gold": WOOD_HARVEST_RATE * 0.9,
	"stone": WOOD_HARVEST_RATE * 0.9,
}

const BUILD_RANGE := 40.0
const REPAIR_HP_PER_SEC := 1.0

@export var carry_capacity: int = 10

var state: State = State.IDLE
## ResourceNode or Farm (duck-typed harvest / is_depleted / gather_radius).
var target_resource: Node2D
var target_dropoff: Node2D
var target_building: Building
var target_repair: Building
var carried_type: String = ""
var carried_amount: int = 0
var _harvest_accumulator: float = 0.0
var _repair_accum: float = 0.0
var _build_chain: Array = []

@onready var carry_label: Label = $CarryLabel


func _ready() -> void:
	unit_id = "villager"
	can_attack = false
	max_hp = 25.0
	speed = 80.0
	attack_damage = 3.0
	sight_range = 4.0 * 40.0
	super._ready()
	configure_facing_sprites("villager")
	add_to_group("villagers")
	_refresh_carry_label()


func assign_gather(resource: Node2D, dropoff: Node2D = null) -> void:
	if resource == null or not is_instance_valid(resource):
		return
	if not resource.has_method("harvest") or not resource.has_method("is_depleted"):
		print("[GATHER] refuse harvest target (not a resource): %s" % resource.name)
		return
	if resource.call("is_depleted"):
		return
	if resource is Farm and not (resource as Farm).is_complete:
		return
	_leave_build_site()
	_release_farm_claim()
	target_resource = null
	target_dropoff = dropoff
	if resource is Farm:
		if not (resource as Farm).try_claim_farmer(self):
			NotificationManager.show_message("Farma už má zemědělce.")
			return
	target_resource = resource
	if target_resource.has_signal("depleted") and not target_resource.depleted.is_connected(_on_resource_depleted):
		target_resource.depleted.connect(_on_resource_depleted, CONNECT_ONE_SHOT)
	_go_to_resource()


func assign_build(building: Building) -> void:
	if building == null or not is_instance_valid(building) or building.is_complete:
		return
	_interrupt_gather_orders()
	_leave_repair()
	_build_chain.clear()
	target_building = building
	state = State.MOVE_TO_BUILD
	attack_target = null
	set_movement_target(building.global_position)
	print("[BUILD] villager assigned to %s" % building.display_name)


func assign_build_chain(segments: Array) -> void:
	var chain: Array = []
	for s in segments:
		if s is Building and is_instance_valid(s) and not (s as Building).is_complete:
			chain.append(s)
	if chain.is_empty():
		return
	var first: Building = chain.pop_front() as Building
	assign_build(first)
	_build_chain = chain


func assign_repair(building: Building) -> void:
	if building == null or not is_instance_valid(building) or not building.needs_repair():
		return
	if building.team != team:
		return
	_interrupt_gather_orders()
	_leave_build_site()
	_build_chain.clear()
	target_repair = building
	state = State.MOVE_TO_REPAIR
	attack_target = null
	_repair_accum = 0.0
	set_movement_target(building.global_position)
	print("[REPAIR] villager assigned to %s" % building.display_name)


func notify_build_finished(building: Building) -> void:
	if target_building != null and target_building != building and is_instance_valid(target_building):
		return
	_leave_build_site()
	# Sequential chain: next unfinished segment (preserve remainder).
	var rest: Array = _build_chain.duplicate()
	_build_chain.clear()
	while not rest.is_empty():
		var next: Building = rest.pop_front() as Building
		if next != null and is_instance_valid(next) and not next.is_complete:
			assign_build(next)
			_build_chain = rest
			return
	state = State.IDLE
	stop_movement()


func _harvest_rate_for(resource_type: String) -> float:
	var base: float
	if target_resource is Farm:
		base = FARM_HARVEST_RATE
	else:
		base = float(HARVEST_RATES.get(resource_type, 0.30))
	return base * GameManager.gather_rate_mult(team, resource_type)


func _physics_process(delta: float) -> void:
	match state:
		State.MOVING:
			_steer_toward_target()
			if is_navigation_finished():
				state = State.IDLE
				stop_movement()
		State.MOVE_TO_RESOURCE:
			_steer_toward_target()
			if _reached_resource():
				_begin_harvest()
		State.HARVESTING:
			stop_movement()
			_harvest(delta)
		State.MOVE_TO_DROPOFF:
			_steer_toward_target()
			if _reached_dropoff():
				_deposit()
		State.MOVE_TO_BUILD:
			if not _building_valid():
				_leave_build_site()
				state = State.IDLE
				stop_movement()
				return
			set_movement_target(target_building.global_position)
			_steer_toward_target()
			if global_position.distance_to(target_building.global_position) <= _build_reach():
				_begin_building()
		State.BUILDING:
			stop_movement()
			if not _building_valid():
				_leave_build_site()
				state = State.IDLE
				return
			if target_building.is_complete:
				# notify_build_finished already ran from Building._finish_construction
				return
			target_building.register_builder(self)
		State.MOVE_TO_REPAIR:
			if not _repair_valid():
				_leave_repair()
				state = State.IDLE
				stop_movement()
				return
			set_movement_target(target_repair.global_position)
			_steer_toward_target()
			if global_position.distance_to(target_repair.global_position) <= _repair_reach():
				state = State.REPAIRING
				_repair_accum = 0.0
				stop_movement()
				target_repair.register_repairer(self)
		State.REPAIRING:
			stop_movement()
			if not _repair_valid() or not target_repair.needs_repair():
				_leave_repair()
				state = State.IDLE
				return
			target_repair.register_repairer(self)
			_repair_accum += REPAIR_HP_PER_SEC * delta
			if _repair_accum >= 1.0:
				var chunk := floorf(_repair_accum)
				_repair_accum -= chunk
				var done := target_repair.apply_repair(chunk)
				if done <= 0.0:
					# Out of resources — idle.
					_leave_repair()
					state = State.IDLE
					NotificationManager.show_message("Nedostatek surovin na opravu.")
		State.IDLE:
			stop_movement()


func command_move(world_pos: Vector2, speed_cap: float = -1.0) -> void:
	_leave_build_site()
	_leave_repair()
	_build_chain.clear()
	_interrupt_gather_orders()
	state = State.MOVING
	super.command_move(world_pos, speed_cap)


func command_stop() -> void:
	_leave_build_site()
	_leave_repair()
	_build_chain.clear()
	_interrupt_gather_orders()
	state = State.IDLE
	super.command_stop()


func command_attack(target: Node2D) -> void:
	# Villagers never attack; keep gather/move/build only.
	print("[COMBAT] villager refuse attack -> %s" % (target.name if target else "null"))
	return


func _interrupt_gather_orders() -> void:
	_release_farm_claim()
	target_resource = null
	target_dropoff = null


func _release_farm_claim() -> void:
	if target_resource is Farm and is_instance_valid(target_resource):
		(target_resource as Farm).release_farmer(self)


func _leave_build_site() -> void:
	if target_building != null and is_instance_valid(target_building):
		target_building.unregister_builder(self)
	target_building = null


func _leave_repair() -> void:
	if target_repair != null and is_instance_valid(target_repair):
		target_repair.unregister_repairer(self)
	target_repair = null


func _building_valid() -> bool:
	return target_building != null and is_instance_valid(target_building)


func _repair_valid() -> bool:
	return target_repair != null and is_instance_valid(target_repair)


func _build_reach() -> float:
	if not _building_valid():
		return BUILD_RANGE
	return BUILD_RANGE + target_building.footprint.length() * 0.2


func _repair_reach() -> float:
	if not _repair_valid():
		return BUILD_RANGE
	return BUILD_RANGE + target_repair.footprint.length() * 0.2


func _begin_building() -> void:
	if not _building_valid() or target_building.is_complete:
		_leave_build_site()
		state = State.IDLE
		return
	state = State.BUILDING
	stop_movement()
	target_building.register_builder(self)


func _go_to_resource() -> void:
	if not is_instance_valid(target_resource):
		_release_farm_claim()
		state = State.IDLE
		stop_movement()
		return
	if target_resource.call("is_depleted"):
		if target_resource is Farm:
			_try_auto_reseed_farm()
			return
		_release_farm_claim()
		state = State.IDLE
		stop_movement()
		return
	if not target_resource.has_method("harvest"):
		print("[GATHER] refuse non-resource gather target")
		_release_farm_claim()
		target_resource = null
		state = State.IDLE
		return
	if target_resource is Farm and not (target_resource as Farm).try_claim_farmer(self):
		NotificationManager.show_message("Farma už má zemědělce.")
		target_resource = null
		state = State.IDLE
		stop_movement()
		return
	state = State.MOVE_TO_RESOURCE
	attack_target = null
	set_movement_target(target_resource.global_position)


func _begin_harvest() -> void:
	if not is_instance_valid(target_resource):
		_release_farm_claim()
		state = State.IDLE
		return
	if target_resource.call("is_depleted"):
		if target_resource is Farm:
			_try_auto_reseed_farm()
			return
		_release_farm_claim()
		state = State.IDLE
		return
	if not target_resource.has_method("harvest"):
		print("[GATHER] refuse harvesting non-resource %s" % target_resource.name)
		_release_farm_claim()
		target_resource = null
		state = State.IDLE
		return
	if target_resource is Farm and not (target_resource as Farm).try_claim_farmer(self):
		NotificationManager.show_message("Farma už má zemědělce.")
		target_resource = null
		state = State.IDLE
		return
	state = State.HARVESTING
	carried_type = str(target_resource.get("resource_type"))
	_harvest_accumulator = 0.0
	stop_movement()
	print("[GATHER] harvesting %s" % carried_type)


func _harvest(delta: float) -> void:
	if not is_instance_valid(target_resource) or target_resource.call("is_depleted"):
		_release_farm_claim()
		if carried_amount > 0:
			_go_to_dropoff()
		elif target_resource is Farm and is_instance_valid(target_resource):
			# Already empty on this tick — reseed or idle at plot.
			_try_auto_reseed_farm()
		else:
			state = State.IDLE
		return

	_harvest_accumulator += _harvest_rate_for(carried_type) * delta
	var chunk := int(_harvest_accumulator)
	if chunk <= 0:
		return
	_harvest_accumulator -= float(chunk)

	var room := carry_capacity - carried_amount
	var taken: int = int(target_resource.call("harvest", mini(chunk, room)))
	carried_amount += taken
	if taken > 0:
		if carried_type == "wood":
			AudioManager.play_sfx("wood_chop")
		elif carried_type == "gold" or carried_type == "stone":
			AudioManager.play_sfx("mining")
	_refresh_carry_label()

	if carried_amount >= carry_capacity or not is_instance_valid(target_resource) or target_resource.call("is_depleted"):
		if is_instance_valid(target_resource) and target_resource.call("is_depleted"):
			_release_farm_claim()
			# Deposit first; `_go_to_resource` auto-reseeds empty farm after drop-off.
		_go_to_dropoff()


func _go_to_dropoff() -> void:
	target_dropoff = _find_nearest_dropoff(carried_type)
	if not is_instance_valid(target_dropoff):
		state = State.IDLE
		stop_movement()
		NotificationManager.show_message("Není drop-off pro %s" % carried_type)
		return
	state = State.MOVE_TO_DROPOFF
	set_movement_target(target_dropoff.global_position)


func _deposit() -> void:
	if carried_amount > 0 and carried_type != "":
		var ai := _ai_for_team()
		if ai:
			ai.add_resource(carried_type, carried_amount)
			print("[GATHER] AI team=%d deposited %s +%d" % [team, carried_type, carried_amount])
		elif team == 0:
			GameManager.add_resource(carried_type, carried_amount)
			print("[GATHER] deposited %s +%d (food=%d wood=%d gold=%d stone=%d)" % [
				carried_type, carried_amount, GameManager.food, GameManager.wood, GameManager.gold, GameManager.stone
			])
			NotificationManager.show_message("+%d %s" % [carried_amount, carried_type])
	carried_amount = 0
	carried_type = ""
	_refresh_carry_label()
	_go_to_resource()


func _ai_for_team() -> SimpleEnemyAI:
	for n in get_tree().get_nodes_in_group("ai_controllers"):
		if n is SimpleEnemyAI and (n as SimpleEnemyAI).team == team:
			return n as SimpleEnemyAI
	return null


func _find_nearest_dropoff(resource_type: String) -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("dropoffs"):
		if not (node is Node2D):
			continue
		if "team" in node and int(node.get("team")) != team:
			continue
		if node.has_method("accepts") and not node.call("accepts", resource_type):
			continue
		var d := global_position.distance_to((node as Node2D).global_position)
		if d < best_dist:
			best_dist = d
			best = node
	return best


func _reached_resource() -> bool:
	if not is_instance_valid(target_resource):
		return false
	var radius := 28.0
	if "gather_radius" in target_resource:
		radius = float(target_resource.get("gather_radius"))
	return global_position.distance_to(target_resource.global_position) <= radius


func _dropoff_radius(node: Node2D) -> float:
	if "dropoff_radius" in node:
		return float(node.get("dropoff_radius"))
	return 48.0


func _reached_dropoff() -> bool:
	if not is_instance_valid(target_dropoff):
		return false
	return global_position.distance_to(target_dropoff.global_position) <= _dropoff_radius(target_dropoff)


func _on_resource_depleted() -> void:
	_release_farm_claim()
	if state == State.HARVESTING or state == State.MOVE_TO_RESOURCE:
		# Farm: always route through drop-off (even 0 carry) so return path can reseed.
		if carried_amount > 0 or target_resource is Farm:
			_go_to_dropoff()
		else:
			state = State.IDLE
			stop_movement()


## T-25: after harvest finishes, reseed empty farm for 60 wood or idle at the plot.
func _try_auto_reseed_farm() -> void:
	stop_movement()
	var farm := target_resource as Farm
	if farm == null or not is_instance_valid(farm):
		state = State.IDLE
		return
	if not farm.is_depleted():
		# Already reseeded (e.g. manual button) — resume gather.
		var drop_ok := target_dropoff
		assign_gather(farm, drop_ok)
		return
	if farm.try_reseed(team, true):
		var drop := target_dropoff
		assign_gather(farm, drop)
		return
	# No wood — idle at farm.
	state = State.IDLE


func _refresh_carry_label() -> void:
	if carry_label == null:
		return
	carry_label.text = "" if carried_amount <= 0 else "%d %s" % [carried_amount, carried_type]