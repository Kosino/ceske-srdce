extends Unit
class_name FishingBoat
## DESIGN: Rybářská loď 75 D — water-only, gathers fish schools, carry 15, drop-off dock.

enum State { IDLE, MOVING, MOVE_TO_FISH, HARVESTING, MOVE_TO_DOCK }

const FISH_HARVEST_RATE := 0.40
const CARRY_DEFAULT := 15

@export var carry_capacity: int = CARRY_DEFAULT

var state: State = State.IDLE
var target_fish: ResourceNode
var target_dock: Node2D
var carried_type: String = ""
var carried_amount: int = 0
var _harvest_accumulator: float = 0.0

@onready var carry_label: Label = $CarryLabel


func _ready() -> void:
	unit_id = "fishing_boat"
	can_attack = false
	max_hp = 60.0
	speed = 70.0
	attack_damage = 0.0
	sight_range = 5.0 * 40.0
	is_watercraft = true
	super._ready()
	configure_facing_sprites("fishing_boat")
	add_to_group("fishing_boats")
	_refresh_carry_label()


func assign_fish(resource: ResourceNode, dock: Node2D = null) -> void:
	if resource == null or not is_instance_valid(resource):
		return
	if not resource.is_fish():
		NotificationManager.show_message("Loď loví jen hejna ryb.")
		return
	if resource.is_depleted():
		return
	target_fish = resource
	target_dock = dock
	if target_fish.depleted.is_connected(_on_fish_depleted) == false:
		target_fish.depleted.connect(_on_fish_depleted, CONNECT_ONE_SHOT)
	_go_to_fish()


func command_move(world_pos: Vector2, speed_cap: float = -1.0) -> void:
	_interrupt_orders()
	state = State.MOVING
	super.command_move(world_pos, speed_cap)


func command_stop() -> void:
	_interrupt_orders()
	state = State.IDLE
	super.command_stop()


func command_attack(_target: Node2D) -> void:
	return


func _physics_process(delta: float) -> void:
	match state:
		State.MOVING:
			_steer_toward_target()
			if is_navigation_finished():
				state = State.IDLE
				stop_movement()
		State.MOVE_TO_FISH:
			_steer_toward_target()
			if _reached_fish():
				_begin_harvest()
		State.HARVESTING:
			stop_movement()
			_harvest(delta)
		State.MOVE_TO_DOCK:
			_steer_toward_target()
			if _reached_dock():
				_deposit()
		State.IDLE:
			stop_movement()


func _interrupt_orders() -> void:
	target_fish = null
	target_dock = null


func _go_to_fish() -> void:
	if not is_instance_valid(target_fish) or target_fish.is_depleted():
		state = State.IDLE
		stop_movement()
		return
	state = State.MOVE_TO_FISH
	attack_target = null
	set_movement_target(target_fish.global_position)


func _begin_harvest() -> void:
	if not is_instance_valid(target_fish) or target_fish.is_depleted():
		state = State.IDLE
		return
	state = State.HARVESTING
	carried_type = "food"
	_harvest_accumulator = 0.0
	stop_movement()
	print("[FISH] harvesting food")


func _harvest(delta: float) -> void:
	if not is_instance_valid(target_fish) or target_fish.is_depleted():
		if carried_amount > 0:
			_go_to_dock()
		else:
			state = State.IDLE
		return
	_harvest_accumulator += FISH_HARVEST_RATE * GameManager.gather_rate_mult(team, "food") * delta
	var chunk := int(_harvest_accumulator)
	if chunk <= 0:
		return
	_harvest_accumulator -= float(chunk)
	var room := carry_capacity - carried_amount
	var taken := target_fish.harvest(mini(chunk, room))
	carried_amount += taken
	_refresh_carry_label()
	if carried_amount >= carry_capacity or not is_instance_valid(target_fish) or target_fish.is_depleted():
		_go_to_dock()


func _go_to_dock() -> void:
	target_dock = _find_nearest_dock()
	if not is_instance_valid(target_dock):
		state = State.IDLE
		stop_movement()
		NotificationManager.show_message("Není přístaviště pro jídlo.")
		return
	state = State.MOVE_TO_DOCK
	set_movement_target(target_dock.global_position)


func _deposit() -> void:
	if carried_amount > 0:
		if team == 0:
			GameManager.add_resource("food", carried_amount)
			print("[FISH] deposited food +%d (food=%d)" % [carried_amount, GameManager.food])
			NotificationManager.show_message("+%d jídlo" % carried_amount)
		else:
			var ai := _ai_for_team()
			if ai:
				ai.add_resource("food", carried_amount)
	carried_amount = 0
	carried_type = ""
	_refresh_carry_label()
	_go_to_fish()


func _find_nearest_dock() -> Node2D:
	var best: Node2D = null
	var best_dist := INF
	for node in get_tree().get_nodes_in_group("dropoffs"):
		if not (node is Node2D):
			continue
		if "team" in node and int(node.get("team")) != team:
			continue
		# Prefer docks; also allow TC/mill that accept food as fallback.
		if node.has_method("accepts") and not node.call("accepts", "food"):
			continue
		var d := global_position.distance_to((node as Node2D).global_position)
		# Prefer actual docks when equidistant-ish.
		if node is Dock:
			d *= 0.5
		if d < best_dist:
			best_dist = d
			best = node
	return best


func _ai_for_team() -> SimpleEnemyAI:
	for n in get_tree().get_nodes_in_group("ai_controllers"):
		if n is SimpleEnemyAI and (n as SimpleEnemyAI).team == team:
			return n as SimpleEnemyAI
	return null


func _reached_fish() -> bool:
	if not is_instance_valid(target_fish):
		return false
	var radius := float(target_fish.gather_radius)
	return global_position.distance_to(target_fish.global_position) <= radius + 8.0


func _reached_dock() -> bool:
	if not is_instance_valid(target_dock):
		return false
	var radius := 56.0
	if "dropoff_radius" in target_dock:
		radius = float(target_dock.get("dropoff_radius"))
	return global_position.distance_to(target_dock.global_position) <= radius + 12.0


func _on_fish_depleted() -> void:
	if state == State.HARVESTING or state == State.MOVE_TO_FISH:
		if carried_amount > 0:
			_go_to_dock()
		else:
			state = State.IDLE
			stop_movement()


func _refresh_carry_label() -> void:
	if carry_label == null:
		return
	if carried_amount <= 0:
		carry_label.visible = false
		carry_label.text = ""
	else:
		carry_label.visible = true
		carry_label.text = str(carried_amount)
