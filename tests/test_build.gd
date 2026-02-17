extends SceneTree

# Build / data-validation tests — no scene tree needed
# Run: Godot --headless --script res://tests/test_build.gd

const C = preload("res://scripts/Constants.gd")

var _pass := 0
var _fail := 0

func _init() -> void:
	print("\n=== BUILD TESTS ===\n")

	_test_build_data_keys()
	_test_enemy_types_keys()
	_test_coordinate_round_trip()
	_test_grid_boundary()
	_test_upgrade_costs()
	_test_wave_configs()
	_test_wave_config_scaling()

	print("\n--- Results: %d passed, %d failed ---" % [_pass, _fail])
	if _fail > 0:
		print("SOME TESTS FAILED!")
	else:
		print("ALL TESTS PASSED!")
	quit()

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

func _test_build_data_keys() -> void:
	print("[BUILD_DATA integrity]")
	var required_keys := ["name", "cost", "blocking", "color", "description"]
	for item_key in C.BUILD_DATA:
		var data: Dictionary = C.BUILD_DATA[item_key]
		for k in required_keys:
			_assert_true(data.has(k), "BUILD_DATA[%s] has '%s'" % [item_key, k])
		_assert_true(data["cost"] > 0, "BUILD_DATA[%s] cost > 0" % item_key)

func _test_enemy_types_keys() -> void:
	print("[ENEMY_TYPES integrity]")
	var required_keys := ["hp_mult", "speed_mult", "damage", "gold_mult", "sprite"]
	for etype in C.ENEMY_TYPES:
		var data: Dictionary = C.ENEMY_TYPES[etype]
		for k in required_keys:
			_assert_true(data.has(k), "ENEMY_TYPES['%s'] has '%s'" % [etype, k])
		_assert_true(data["hp_mult"] > 0, "ENEMY_TYPES['%s'] hp_mult > 0" % etype)
		_assert_true(data["speed_mult"] > 0, "ENEMY_TYPES['%s'] speed_mult > 0" % etype)

func _test_coordinate_round_trip() -> void:
	print("[Coordinate round-trip]")
	for gx in [0, 5, 10, 19]:
		for gy in [0, 3, 7, 13]:
			var world = C.grid_to_world(gx, gy)
			var back = C.world_to_grid(world)
			_assert_eq(back, Vector2i(gx, gy),
				"grid(%d,%d) -> world -> grid = (%d,%d)" % [gx, gy, back.x, back.y])

func _test_grid_boundary() -> void:
	print("[Grid boundary checks]")
	_assert_true(C.is_in_grid(0, 0), "0,0 in grid")
	_assert_true(C.is_in_grid(19, 13), "19,13 in grid")
	_assert_true(not C.is_in_grid(-1, 0), "-1,0 NOT in grid")
	_assert_true(not C.is_in_grid(0, -1), "0,-1 NOT in grid")
	_assert_true(not C.is_in_grid(20, 0), "20,0 NOT in grid")
	_assert_true(not C.is_in_grid(0, 14), "0,14 NOT in grid")

func _test_upgrade_costs() -> void:
	print("[Upgrade costs]")
	var wall_cost: int = C.BUILD_DATA[C.BuildItem.WALL]["cost"]
	var up1 = C.get_upgrade_cost(C.BuildItem.WALL, 1)
	_assert_eq(up1, int(wall_cost * 0.6), "Wall upgrade L1->L2 = %d" % up1)

	var up2 = C.get_upgrade_cost(C.BuildItem.WALL, 2)
	_assert_eq(up2, int(wall_cost * 1.0), "Wall upgrade L2->L3 = %d" % up2)

	var up3 = C.get_upgrade_cost(C.BuildItem.WALL, 3)
	_assert_eq(up3, 0, "Wall upgrade at max returns 0")

	var bad = C.get_upgrade_cost(999, 1)
	_assert_eq(bad, 0, "Invalid item upgrade returns 0")

func _test_wave_configs() -> void:
	print("[Wave configs]")
	_assert_eq(C.WAVE_CONFIGS.size(), 10, "10 wave configs defined")
	for i in C.WAVE_CONFIGS.size():
		var cfg: Dictionary = C.WAVE_CONFIGS[i]
		_assert_true(cfg.has("count"), "Wave %d has 'count'" % (i + 1))
		_assert_true(cfg.has("types"), "Wave %d has 'types'" % (i + 1))
		_assert_true(cfg["count"] > 0, "Wave %d count > 0" % (i + 1))
		for t in cfg["types"]:
			_assert_true(C.ENEMY_TYPES.has(t),
				"Wave %d type '%s' exists" % [i + 1, t])

func _test_wave_config_scaling() -> void:
	print("[Wave config scaling for infinite waves]")
	var cfg11 = C.get_wave_config(11)
	_assert_true(cfg11["count"] > C.WAVE_CONFIGS[-1]["count"],
		"Wave 11 count > wave 10 count")
	var cfg20 = C.get_wave_config(20)
	_assert_true(cfg20["count"] > cfg11["count"],
		"Wave 20 count > wave 11 count")
	for t in cfg11["types"]:
		_assert_true(C.ENEMY_TYPES.has(t),
			"Wave 11 type '%s' exists" % t)
