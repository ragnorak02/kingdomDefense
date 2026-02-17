extends Node

# Runtime / game-logic tests — runs as a scene with autoloads active
# Run: see run_tests.sh or run via the TestRuntime.tscn scene

var _pass := 0
var _fail := 0
var _ran := false

func _ready() -> void:
	# Load and add the main scene as child
	var scene = load("res://scenes/Main.tscn").instantiate()
	add_child(scene)

func _process(_delta: float) -> void:
	if _ran:
		return
	_ran = true

	# By now _ready() has fired on all children
	print("\n=== RUNTIME TESTS ===\n")

	var scene = get_child(0)
	var game_mgr = scene.get_node("GameManager")
	var grid_mgr = scene.get_node("GridManager")

	_test_initial_state(game_mgr)
	_test_gold_spend_refund(game_mgr)
	_test_state_transitions(game_mgr)
	_test_occupancy(grid_mgr)
	_test_pathfinding(grid_mgr)
	_test_would_block_path(grid_mgr)

	print("\n--- Results: %d passed, %d failed ---" % [_pass, _fail])
	if _fail > 0:
		print("SOME TESTS FAILED!")
	else:
		print("ALL TESTS PASSED!")

	get_tree().quit()

# ── Helpers ──

func _assert_true(condition: bool, desc: String) -> void:
	if condition:
		_pass += 1
		print("  PASS: %s" % desc)
	else:
		_fail += 1
		print("  FAIL: %s" % desc)

func _assert_eq(a, b, desc: String) -> void:
	if a == b:
		_pass += 1
		print("  PASS: %s" % desc)
	else:
		_fail += 1
		print("  FAIL: %s (got %s, expected %s)" % [desc, str(a), str(b)])

# ── Tests ──

func _test_initial_state(gm: Node) -> void:
	print("[Initial game state]")
	_assert_eq(gm.current_phase, 0, "Initial phase is PLANNING (0)")
	_assert_eq(gm.gold, Constants.STARTING_GOLD, "Starting gold = %d" % Constants.STARTING_GOLD)
	_assert_eq(gm.base_hp, Constants.BASE_MAX_HP, "Starting HP = %d" % Constants.BASE_MAX_HP)
	_assert_eq(gm.current_wave, 0, "Current wave = 0")

func _test_gold_spend_refund(gm: Node) -> void:
	print("[Gold economy]")
	var starting = gm.gold

	var success = gm.spend_gold(50)
	_assert_true(success, "spend_gold(50) succeeds with %d gold" % starting)
	_assert_eq(gm.gold, starting - 50, "Gold reduced to %d" % (starting - 50))

	var fail = gm.spend_gold(999999)
	_assert_true(not fail, "spend_gold(999999) fails")
	_assert_eq(gm.gold, starting - 50, "Gold unchanged after failed spend")

	gm.refund_gold(50)
	_assert_eq(gm.gold, starting, "Gold restored after refund")

func _test_state_transitions(gm: Node) -> void:
	print("[State transitions]")
	_assert_eq(gm.current_phase, 0, "Starts in PLANNING")

	gm.start_wave()
	_assert_eq(gm.current_phase, 1, "After start_wave: phase = WAVE (1)")
	_assert_eq(gm.current_wave, 1, "Wave incremented to 1")

	gm.restart_game()
	_assert_eq(gm.current_phase, 0, "After restart: phase = PLANNING (0)")
	_assert_eq(gm.current_wave, 0, "After restart: wave = 0")
	_assert_eq(gm.gold, Constants.STARTING_GOLD, "After restart: gold reset")

func _test_occupancy(grid: Node2D) -> void:
	print("[Occupancy tracking]")
	var test_pos := Vector2i(5, 5)

	_assert_true(not grid.is_occupied(test_pos), "5,5 initially unoccupied")

	grid.set_occupied(test_pos, Constants.BuildItem.WALL, null)
	_assert_true(grid.is_occupied(test_pos), "5,5 occupied after set")

	var data = grid.get_occupant(test_pos)
	_assert_eq(data["item"], Constants.BuildItem.WALL, "Occupant is WALL")

	grid.clear_occupied(test_pos)
	_assert_true(not grid.is_occupied(test_pos), "5,5 clear after remove")

func _test_pathfinding(grid: Node2D) -> void:
	print("[Pathfinding]")
	_assert_true(grid.has_path_from_spawns(), "Path exists from all spawns")

	var spawn_world = Constants.grid_to_world(
		grid.spawn_points[0].x, grid.spawn_points[0].y)
	var path = grid.get_path_to_goal(spawn_world)
	_assert_true(path.size() > 0, "Path from spawn 0 has waypoints")

func _test_would_block_path(grid: Node2D) -> void:
	print("[Would-block-path check]")
	_assert_true(grid.would_block_path(grid.goal_point),
		"Blocking goal tile would block path")

	var mid := Vector2i(10, 7)
	_assert_true(not grid.would_block_path(mid),
		"Blocking mid tile 10,7 does not block path (empty grid)")
