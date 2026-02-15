extends Node

var all_spawned: bool = false
var _spawn_timer: float = 0.0
var _enemies_to_spawn: int = 0
var _current_wave: int = 0
var _active_enemies: Array[Node2D] = []

@onready var grid_manager: Node2D = get_node("../GridManager")
@onready var game_manager: Node = get_node("../GameManager")
@onready var enemy_container: Node2D = get_node("../Enemies")

func start_wave(wave_num: int, count: int) -> void:
	_current_wave = wave_num
	_enemies_to_spawn = count
	_spawn_timer = 0.0
	all_spawned = false

func _process(delta: float) -> void:
	if game_manager.current_phase != GameManager.Phase.WAVE:
		return
	if _enemies_to_spawn <= 0:
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0:
		_spawn_enemy()
		_spawn_timer = Constants.ENEMY_SPAWN_INTERVAL
		_enemies_to_spawn -= 1
		if _enemies_to_spawn <= 0:
			all_spawned = true

func _spawn_enemy() -> void:
	if grid_manager.spawn_points.size() == 0:
		return
	# Pick a random spawn point
	var sp: Vector2i = grid_manager.spawn_points[randi() % grid_manager.spawn_points.size()]
	var world_pos := Constants.grid_to_world(sp.x, sp.y)

	var enemy: Node2D = preload("res://scenes/Enemy.tscn").instantiate()
	enemy.position = world_pos
	enemy.setup(_current_wave, grid_manager, game_manager)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	enemy.reached_goal.connect(_on_enemy_reached_goal.bind(enemy))
	enemy_container.add_child(enemy)
	_active_enemies.append(enemy)

func _on_enemy_died(enemy: Node2D) -> void:
	_active_enemies.erase(enemy)
	game_manager.on_enemy_killed()

func _on_enemy_reached_goal(enemy: Node2D) -> void:
	_active_enemies.erase(enemy)
	game_manager.on_enemy_reached_goal()

func clear_all() -> void:
	for e in _active_enemies:
		if is_instance_valid(e):
			e.queue_free()
	_active_enemies.clear()
	_enemies_to_spawn = 0
	all_spawned = true

func get_enemies() -> Array[Node2D]:
	# Clean up invalid references
	_active_enemies = _active_enemies.filter(func(e): return is_instance_valid(e) and not e.is_queued_for_deletion())
	return _active_enemies
