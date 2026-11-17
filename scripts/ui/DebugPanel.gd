extends CanvasLayer

@onready var stats_label: Label = $Panel/Margin/VBox/StatsLabel
@onready var fps_label: Label = $Panel/Margin/VBox/FpsLabel

func _ready() -> void:
	GameManager.resources_changed.connect(_refresh_stats)
	GameManager.population_changed.connect(_refresh_stats)
	GameManager.age_changed.connect(_refresh_stats)
	_refresh_stats()
	_refresh_fps()

func _process(_delta: float) -> void:
	if visible:
		_refresh_fps()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("debug_toggle"):
		return
	visible = not visible
	if visible:
		_refresh_stats()
		_refresh_fps()
	get_viewport().set_input_as_handled()

func _refresh_stats() -> void:
	stats_label.text = "Food: %d\nWood: %d\nGold: %d\nStone: %d\nPop: %d / %d\nAge: %d" % [
		GameManager.food,
		GameManager.wood,
		GameManager.gold,
		GameManager.stone,
		GameManager.population,
		GameManager.population_max,
		GameManager.current_age,
	]

func _refresh_fps() -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
