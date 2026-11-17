extends Unit
class_name Villager

enum State { IDLE, MOVE_TO_RESOURCE, HARVESTING, MOVE_TO_DROPOFF }

@export var carry_capacity: int = 10
## DESIGN: drevo 0.40 / jidlo kere 0.30 za sekundu.
@export var harvest_per_second: float = 0.40

var state: State = State.IDLE
var target_resource: ResourceNode
var target_dropoff: DropOff
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


func assign_gather(resource: ResourceNode, dropoff: DropOff) -> void:
	target_resource = resource
	target_dropoff = dropoff
	if is_instance_valid(target_resource):
		harvest_per_second = 0.40 if target_resource.resource_type == "wood" else 0.30
		target_resource.depleted.connect(_on_resource_depleted, CONNECT_ONE_SHOT)
	_go_to_resource()


func _physics_process(delta: float) -> void:
	match state:
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
	state = State.IDLE
	super.command_move(world_pos)


func _go_to_resource() -> void:
	if not is_instance_valid(target_resource) or target_resource.is_depleted():
		state = State.IDLE
		stop_movement()
		return
	state = State.MOVE_TO_RESOURCE
	set_movement_target(target_resource.global_position)


func _begin_harvest() -> void:
	if not is_instance_valid(target_resource) or target_resource.is_depleted():
		state = State.IDLE
		return
	state = State.HARVESTING
	carried_type = target_resource.resource_type
	_harvest_accumulator = 0.0
	stop_movement()


func _harvest(delta: float) -> void:
	if not is_instance_valid(target_resource) or target_resource.is_depleted():
		if carried_amount > 0 and is_instance_valid(target_dropoff):
			_go_to_dropoff()
		else:
			state = State.IDLE
		return

	_harvest_accumulator += harvest_per_second * delta
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
	if not is_instance_valid(target_dropoff):
		state = State.IDLE
		stop_movement()
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


func _reached_resource() -> bool:
	if not is_instance_valid(target_resource):
		return false
	return global_position.distance_to(target_resource.global_position) <= target_resource.gather_radius


func _reached_dropoff() -> bool:
	if not is_instance_valid(target_dropoff):
		return false
	return global_position.distance_to(target_dropoff.global_position) <= target_dropoff.dropoff_radius


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
