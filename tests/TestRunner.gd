extends SceneTree

# Unified Test Runner for Hybrid Nights Studio OS
# Run: godot --headless --script res://tests/TestRunner.gd
# Output: JSON on last stdout line prefixed with "JSON:" for launcher parsing

const C = preload("res://scripts/Constants.gd")

var _details: Array = []
var _pass_count: int = 0
var _fail_count: int = 0
var _start_time: int = 0
var _test_failed: bool = false
var _test_message: String = ""

func _init() -> void:
	_start_time = Time.get_ticks_msec()

	# Phase 1: Tests that don't need autoloads or scene tree
	_run_build_tests()
	_run_asset_validation()

	# Phase 2 deferred to first process frame (autoloads ready for scene scripts)
	process_frame.connect(_run_phase2)

func _run_phase2() -> void:
	process_frame.disconnect(_run_phase2)
	_run_scene_loading()
	_run_runtime_tests()
	_run_performance_test()
	_output_json()
	quit(1 if _fail_count > 0 else 0)

# ── Per-test tracking ──

func _begin() -> void:
	_test_failed = false
	_test_message = ""

func _end(test_name: String) -> void:
	if _test_failed:
		_fail_count += 1
		_details.append({"name": test_name, "status": "fail", "message": _test_message})
	else:
		_pass_count += 1
		_details.append({"name": test_name, "status": "pass", "message": ""})

func _check(condition: bool, msg: String = "") -> void:
	if not condition and not _test_failed:
		_test_failed = true
		_test_message = msg if msg != "" else "Assertion failed"

func _check_eq(a, b) -> void:
	if a != b and not _test_failed:
		_test_failed = true
		_test_message = "got %s, expected %s" % [str(a), str(b)]

# ── Build Tests (ported from test_build.gd) ──

func _run_build_tests() -> void:
	_test_build_data_keys()
	_test_enemy_types_keys()
	_test_coordinate_round_trip()
	_test_grid_boundary()
	_test_upgrade_costs()
	_test_wave_configs()
	_test_wave_config_scaling()

func _test_build_data_keys() -> void:
	_begin()
	var required := ["name", "cost", "blocking", "color", "description"]
	for item_key in C.BUILD_DATA:
		var data: Dictionary = C.BUILD_DATA[item_key]
		for k in required:
			_check(data.has(k), "BUILD_DATA[%s] missing '%s'" % [item_key, k])
		_check(data["cost"] > 0, "BUILD_DATA[%s] cost <= 0" % item_key)
	_end("BUILD_DATA integrity")

func _test_enemy_types_keys() -> void:
	_begin()
	var required := ["hp_mult", "speed_mult", "damage", "gold_mult", "sprite"]
	for etype in C.ENEMY_TYPES:
		var data: Dictionary = C.ENEMY_TYPES[etype]
		for k in required:
			_check(data.has(k), "ENEMY_TYPES['%s'] missing '%s'" % [etype, k])
		_check(data["hp_mult"] > 0, "ENEMY_TYPES['%s'] hp_mult <= 0" % etype)
		_check(data["speed_mult"] > 0, "ENEMY_TYPES['%s'] speed_mult <= 0" % etype)
	_end("ENEMY_TYPES integrity")

func _test_coordinate_round_trip() -> void:
	_begin()
	for gx in [0, 5, 10, 19]:
		for gy in [0, 3, 7, 13]:
			var world = C.grid_to_world(gx, gy)
			var back = C.world_to_grid(world)
			_check_eq(back, Vector2i(gx, gy))
	_end("Coordinate round-trip")

func _test_grid_boundary() -> void:
	_begin()
	_check(C.is_in_grid(0, 0), "0,0 should be in grid")
	_check(C.is_in_grid(19, 13), "19,13 should be in grid")
	_check(not C.is_in_grid(-1, 0), "-1,0 should not be in grid")
	_check(not C.is_in_grid(0, -1), "0,-1 should not be in grid")
	_check(not C.is_in_grid(20, 0), "20,0 should not be in grid")
	_check(not C.is_in_grid(0, 14), "0,14 should not be in grid")
	_end("Grid boundary checks")

func _test_upgrade_costs() -> void:
	_begin()
	var wall_cost: int = C.BUILD_DATA[C.BuildItem.WALL]["cost"]
	_check_eq(C.get_upgrade_cost(C.BuildItem.WALL, 1), int(wall_cost * 0.6))
	_check_eq(C.get_upgrade_cost(C.BuildItem.WALL, 2), int(wall_cost * 1.0))
	_check_eq(C.get_upgrade_cost(C.BuildItem.WALL, 3), 0)
	_check_eq(C.get_upgrade_cost(999, 1), 0)
	_end("Upgrade cost calculations")

func _test_wave_configs() -> void:
	_begin()
	_check_eq(C.WAVE_CONFIGS.size(), 10)
	for i in C.WAVE_CONFIGS.size():
		var cfg: Dictionary = C.WAVE_CONFIGS[i]
		_check(cfg.has("count"), "Wave %d missing 'count'" % (i + 1))
		_check(cfg.has("types"), "Wave %d missing 'types'" % (i + 1))
		_check(cfg["count"] > 0, "Wave %d count <= 0" % (i + 1))
		for t in cfg["types"]:
			_check(C.ENEMY_TYPES.has(t), "Wave %d unknown type '%s'" % [i + 1, t])
	_end("Wave configs valid")

func _test_wave_config_scaling() -> void:
	_begin()
	var cfg11 = C.get_wave_config(11)
	_check(cfg11["count"] > C.WAVE_CONFIGS[-1]["count"], "Wave 11 should scale beyond wave 10")
	var cfg20 = C.get_wave_config(20)
	_check(cfg20["count"] > cfg11["count"], "Wave 20 should scale beyond wave 11")
	for t in cfg11["types"]:
		_check(C.ENEMY_TYPES.has(t), "Scaled wave type '%s' unknown" % t)
	_end("Infinite wave scaling")

# ── Asset Validation ──

func _run_asset_validation() -> void:
	var assets := [
		"res://assets/archer_tower.png",
		"res://assets/arrow.png",
		"res://assets/enemy.png",
		"res://assets/enemy_demon.png",
		"res://assets/enemy_orc.png",
		"res://assets/enemy_swift.png",
		"res://assets/goal_overlay.png",
		"res://assets/ground_archer.png",
		"res://assets/hero.png",
		"res://assets/highlight.png",
		"res://assets/rock.png",
		"res://assets/spawn_overlay.png",
		"res://assets/wall.png",
	]
	for path in assets:
		_begin()
		_check(FileAccess.file_exists(path), "File not found: %s" % path)
		_end("Asset exists: %s" % path.get_file())

# ── Scene Loading ──

func _run_scene_loading() -> void:
	var scenes := [
		"res://scenes/Main.tscn",
		"res://scenes/Enemy.tscn",
		"res://scenes/Projectile.tscn",
		"res://scenes/ArcherTower.tscn",
		"res://scenes/GroundArcher.tscn",
		"res://scenes/Fireball.tscn",
	]
	for path in scenes:
		_begin()
		var scene = load(path)
		_check(scene != null, "Failed to load: %s" % path)
		_end("Scene loads: %s" % path.get_file())

# ── Runtime Tests (ported from test_runtime.gd) ──

func _run_runtime_tests() -> void:
	var main_scene = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main_scene)

	var game_mgr = main_scene.get_node("GameManager")
	var grid_mgr = main_scene.get_node("GridManager")

	_test_initial_state(game_mgr)
	_test_gold_spend_refund(game_mgr)
	_test_state_transitions(game_mgr)
	_test_occupancy(grid_mgr)
	_test_pathfinding(grid_mgr)
	_test_would_block_path(grid_mgr)

	main_scene.queue_free()

func _test_initial_state(gm: Node) -> void:
	_begin()
	_check_eq(gm.current_phase, 0)
	_check_eq(gm.gold, C.STARTING_GOLD)
	_check_eq(gm.base_hp, C.BASE_MAX_HP)
	_check_eq(gm.current_wave, 0)
	_end("Initial game state")

func _test_gold_spend_refund(gm: Node) -> void:
	_begin()
	var starting = gm.gold
	_check(gm.spend_gold(50), "spend_gold(50) should succeed")
	_check_eq(gm.gold, starting - 50)
	_check(not gm.spend_gold(999999), "spend_gold(999999) should fail")
	_check_eq(gm.gold, starting - 50)
	gm.refund_gold(50)
	_check_eq(gm.gold, starting)
	_end("Gold economy")

func _test_state_transitions(gm: Node) -> void:
	_begin()
	_check_eq(gm.current_phase, 0)
	gm.start_wave()
	_check_eq(gm.current_phase, 1)
	_check_eq(gm.current_wave, 1)
	gm.restart_game()
	_check_eq(gm.current_phase, 0)
	_check_eq(gm.current_wave, 0)
	_check_eq(gm.gold, C.STARTING_GOLD)
	_end("State transitions")

func _test_occupancy(grid: Node2D) -> void:
	_begin()
	var pos := Vector2i(5, 5)
	_check(not grid.is_occupied(pos), "5,5 should be unoccupied initially")
	grid.set_occupied(pos, C.BuildItem.WALL, null)
	_check(grid.is_occupied(pos), "5,5 should be occupied after set")
	var data = grid.get_occupant(pos)
	_check_eq(data["item"], C.BuildItem.WALL)
	grid.clear_occupied(pos)
	_check(not grid.is_occupied(pos), "5,5 should be clear after remove")
	_end("Occupancy tracking")

func _test_pathfinding(grid: Node2D) -> void:
	_begin()
	_check(grid.has_path_from_spawns(), "Path should exist from all spawns")
	var spawn_world = C.grid_to_world(grid.spawn_points[0].x, grid.spawn_points[0].y)
	var path = grid.get_path_to_goal(spawn_world)
	_check(path.size() > 0, "Path from spawn 0 should have waypoints")
	_end("Pathfinding")

func _test_would_block_path(grid: Node2D) -> void:
	_begin()
	_check(grid.would_block_path(grid.goal_point), "Blocking goal should block path")
	var mid := Vector2i(10, 7)
	_check(not grid.would_block_path(mid), "Blocking mid tile should not block path")
	_end("Would-block-path check")

# ── Performance Test ──

func _run_performance_test() -> void:
	_begin()
	var t0 = Time.get_ticks_msec()
	var scene = load("res://scenes/Main.tscn").instantiate()
	var elapsed = Time.get_ticks_msec() - t0
	if scene:
		scene.free()
	_check(elapsed < 5000, "Took %dms, limit 5000ms" % elapsed)
	_end("Performance: Main.tscn instantiation < 5s (%dms)" % elapsed)

# ── JSON Output ──

func _output_json() -> void:
	var duration = Time.get_ticks_msec() - _start_time
	var total = _pass_count + _fail_count
	var timestamp = Time.get_datetime_string_from_system(true) + "Z"
	var result := {
		"status": "pass" if _fail_count == 0 else "fail",
		"testsTotal": total,
		"testsPassed": _pass_count,
		"durationMs": duration,
		"timestamp": timestamp,
		"details": _details,
	}
	var json_str := JSON.stringify(result, "  ")
	var f := FileAccess.open("res://tests/test-results.json", FileAccess.WRITE)
	if f:
		f.store_string(json_str)
		f.close()
	print(json_str)
