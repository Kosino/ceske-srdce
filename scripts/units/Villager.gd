extends Unit
class_name Villager

enum State { IDLE, MOVING, MOVE_TO_RESOURCE, HARVESTING, MOVE_TO_DROPOFF }

const HARVEST_RATES := {
	"wood": 0.40,
	"food": 0.30,
	"gold": 0.35,
	"stone": 0.35,
}

@export var carry_capacity: int = 10

var state: State = State.IDLE
var target_resource: ResourceNode
var target_dropoff: Node2D
var carried_type: String = ""
var carried_amount: int = 0
var _harvest_accumulator: float = 0.0

@onready var carry_label: Label = $CarryLabel


func _ready() -> void:
	can_attack = false
	max_hp = 25.0
	speed = 80.0
	attack_damage = 3.0
	super._ready()
	_refresh_carry_label()


func assign_gather(resource: ResourceNode, dropoff: Node2D = null) -> void:
	if resource == null or not is_instance_valid(resource):
		return
	if not resource.has_method("harvest"):
		print("[GATHER] refuse harvest target (not a resource): %s" % resource.name)
		return
	target_resource = resource
	target_dropoff = dropoff
	if is_instance_valid(target_resource):
		target_resource.depleted.connect(_on_resource_depleted, CONNECT_ONE_SHOT)
	_go_to_resource()


func _harvest_rate_for(resource_type: String) -> float:
	return float(HARVEST_RATES.get(resource_type, 0.30))


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
		State.IDLE:
			stop_movement()


func command_move(world_pos: Vector2) -> void:
	_interrupt_gather_orders()
	state = State.MOVING
	super.command_move(world_pos)


func command_stop() -> void:
	_interrupt_gather_orders()
	state = State.IDLE
	super.command_stop()


func command_attack(target: Node2D) -> void:
	# Villagers never attack; keep gather/move only.
	print("[COMBAT] villager refuse attack -> %s" % (target.name if target else "null"))
	return


func _interrupt_gather_orders() -> void:
	target_resource = null
	target_dropoff = null


func _go_to_resource() -> void:
	if not is_instance_valid(target_resource) or target_resource.is_depleted():
		state = State.IDLE
		stop_movement()
		return
	if not (target_resource is ResourceNode):
		print("[GATHER] refuse non-resource gather target")
		target_resource = null
		state = State.IDLE
		return
	state = State.MOVE_TO_RESOURCE
	set_movement_target(target_resource.global_position)


func _begin_harvest() -> void:
	if not is_instance_valid(target_resource) or target_resource.is_depleted():
		state = State.IDLE
		return
	if not target_resource.has_method("harvest"):
		print("[GATHER] refuse harvesting non-resource %s" % target_resource.name)
		target_resource = null
		state = State.IDLE
		return
	state = State.HARVESTING
	carried_type = target_resource.resource_type
	_harvest_accumulator = 0.0
	stop_movement()


func _harvest(delta: float) -> void:
	if not is_instance_valid(target_resource) or target_resource.is_depleted():
		if carried_amount > 0:
			_go_to_dropoff()
		else:
			state = State.IDLE
		return

	_harvest_accumulator += _harvest_rate_for(carried_type) * delta
	var chunk := int(_harvest_accumulator)
	if chunk <= 0:
		return
	_harvest_accumulator -= float(chunk)

	var room := carry_capacity - carried_amount
	var taken := target_resource.harvest(mini(chunk, room))
	carried_amount += taken
	_refresh_carry_label()

	if carried_amount >= carry_capacity or not is_instance_valid(target_resource):
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
		GameManager.add_resource(carried_type, carried_amount)
		print("[GATHER] deposited %s +%d (food=%d wood=%d gold=%d stone=%d)" % [carried_type, carried_amount, GameManager.food, GameManager.wood, GameManager.gold, GameManager.stone])
		NotificationManager.show_message("+%d %s" % [carried_amount, carried_type])
	carried_amount = 0
	carried_type = ""
	_refresh_carry_label()
	_go_to_resource()


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
	return global_position.distance_to(target_resource.global_position) <= target_resource.gather_radius


func _dropoff_radius(node: Node2D) -> float:
	if "dropoff_radius" in node:
		return float(node.get("dropoff_radius"))
	return 48.0


func _reached_dropoff() -> bool:
	if not is_instance_valid(target_dropoff):
		return false
	return global_position.distance_to(target_dropoff.global_position) <= _dropoff_radius(target_dropoff)


func _on_resource_depleted() -> void:
	if state == State.HARVESTING or state == State.MOVE_TO_RESOURCE:
		if carried_amount > 0:
			_go_to_dropoff()
		else:
			state = State.IDLE
			stop_movement()


func _refresh_carry_label() -> void:
	if carry_label == null:
		return
	carry_label.text = "" if carried_amount <= 0 else "%d %s" % [carried_amount, carried_type]