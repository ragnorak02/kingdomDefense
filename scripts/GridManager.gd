extends Node2D

# ── Occupancy grid: Vector2i -> { item: BuildItem, node: Node2D }
var _occupied := {}

# Spawn points and goal position (grid coords)
var spawn_points: Array[Vector2i] = []
var goal_point := Vector2i(-1, -1)

# AStar pathfinding
var _astar := AStar2D.new()

signal tile_hovered(grid_pos: Vector2i)
signal tile_clicked(grid_pos: Vector2i)
signal grid_changed

var _highlight_pos := Vector2i(-1, -1)
var _controller_cursor := Vector2.ZERO
var _using_controller := false

# Tile textures
var _tile_grass_1: Texture2D
var _tile_grass_2: Texture2D
var _tile_spawn: Texture2D
var _tile_goal: Texture2D
var _tile_highlight: Texture2D

func _ready() -> void:
	# Set up spawn points (left edge) and goal (right side)
	spawn_points = [
		Vector2i(0, 3),
		Vector2i(0, 7),
		Vector2i(0, 11),
	]
	goal_point = Vector2i(Constants.GRID_WIDTH - 1, Constants.GRID_HEIGHT / 2)
	_controller_cursor = Constants.grid_to_world(Constants.GRID_WIDTH / 2, Constants.GRID_HEIGHT / 2)
	# Load tile textures
	_tile_grass_1 = load("res://assets/tile_grass_1.png")
	_tile_grass_2 = load("res://assets/tile_grass_2.png")
	_tile_spawn = load("res://assets/tile_spawn.png")
	_tile_goal = load("res://assets/tile_goal.png")
	_tile_highlight = load("res://assets/highlight.png")
	_rebuild_astar()

func _process(_delta: float) -> void:
	# Controller cursor movement
	var cx := Input.get_axis("cursor_left", "cursor_right")
	var cy := Input.get_axis("cursor_up", "cursor_down")
	if abs(cx) > 0.1 or abs(cy) > 0.1:
		_using_controller = true
		_controller_cursor += Vector2(cx, cy) * 200.0 * _delta

	var mouse_pos := get_global_mouse_position()
	var pos: Vector2
	if _using_controller:
		pos = _controller_cursor
	else:
		pos = mouse_pos

	var gp := Constants.world_to_grid(pos)
	if Constants.is_in_grid(gp.x, gp.y) and gp != _highlight_pos:
		_highlight_pos = gp
		tile_hovered.emit(gp)
	elif not Constants.is_in_grid(gp.x, gp.y):
		_highlight_pos = Vector2i(-1, -1)
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_using_controller = false
	if event.is_action_pressed("place_item"):
		if Constants.is_in_grid(_highlight_pos.x, _highlight_pos.y):
			tile_clicked.emit(_highlight_pos)

func _draw() -> void:
	var hw := Constants.TILE_WIDTH * 0.5
	var hh := Constants.TILE_HEIGHT * 0.5
	# Draw all grid tiles using textures
	for gx in range(Constants.GRID_WIDTH):
		for gy in range(Constants.GRID_HEIGHT):
			var center := Constants.grid_to_world(gx, gy)
			var is_spawn := Vector2i(gx, gy) in spawn_points
			var is_goal := Vector2i(gx, gy) == goal_point

			var tile_tex: Texture2D
			if is_goal:
				tile_tex = _tile_goal
			elif is_spawn:
				tile_tex = _tile_spawn
			elif (gx + gy) % 2 == 0:
				tile_tex = _tile_grass_1
			else:
				tile_tex = _tile_grass_2

			var draw_pos := center - Vector2(hw, hh)
			draw_texture(tile_tex, draw_pos)

	# Draw highlight
	if Constants.is_in_grid(_highlight_pos.x, _highlight_pos.y):
		var center := Constants.grid_to_world(_highlight_pos.x, _highlight_pos.y)
		var draw_pos := center - Vector2(hw, hh)
		draw_texture(_tile_highlight, draw_pos)

func _closed_poly(pts: PackedVector2Array) -> PackedVector2Array:
	var closed := PackedVector2Array(pts)
	closed.append(pts[0])
	return closed

func _iso_diamond(center: Vector2) -> PackedVector2Array:
	var hw := Constants.TILE_WIDTH * 0.5
	var hh := Constants.TILE_HEIGHT * 0.5
	return PackedVector2Array([
		center + Vector2(0, -hh),   # top
		center + Vector2(hw, 0),    # right
		center + Vector2(0, hh),    # bottom
		center + Vector2(-hw, 0),   # left
	])

# ── Occupancy ──
func is_occupied(gp: Vector2i) -> bool:
	return _occupied.has(gp)

func get_occupant(gp: Vector2i):
	return _occupied.get(gp, null)

func set_occupied(gp: Vector2i, item_type: int, node: Node2D) -> void:
	_occupied[gp] = {"item": item_type, "node": node}
	if Constants.BUILD_DATA.has(item_type) and Constants.BUILD_DATA[item_type]["blocking"]:
		_rebuild_astar()

func clear_occupied(gp: Vector2i) -> void:
	if _occupied.has(gp):
		var data = _occupied[gp]
		_occupied.erase(gp)
		if Constants.BUILD_DATA.has(data["item"]) and Constants.BUILD_DATA[data["item"]]["blocking"]:
			_rebuild_astar()

func is_special_tile(gp: Vector2i) -> bool:
	return gp in spawn_points or gp == goal_point

# ── Pathfinding ──
func _point_id(gx: int, gy: int) -> int:
	return gy * Constants.GRID_WIDTH + gx

func _rebuild_astar() -> void:
	_astar.clear()
	# Add points
	for gx in range(Constants.GRID_WIDTH):
		for gy in range(Constants.GRID_HEIGHT):
			var pid := _point_id(gx, gy)
			var world_pos := Constants.grid_to_world(gx, gy)
			_astar.add_point(pid, world_pos)
			var gp := Vector2i(gx, gy)
			# Disable blocked cells (but not spawn/goal)
			if _occupied.has(gp):
				var data = _occupied[gp]
				if Constants.BUILD_DATA.has(data["item"]) and Constants.BUILD_DATA[data["item"]]["blocking"]:
					_astar.set_point_disabled(pid, true)

	# Connect neighbors (4-directional for grid pathfinding)
	for gx in range(Constants.GRID_WIDTH):
		for gy in range(Constants.GRID_HEIGHT):
			var pid := _point_id(gx, gy)
			# Right
			if gx + 1 < Constants.GRID_WIDTH:
				_astar.connect_points(pid, _point_id(gx + 1, gy))
			# Down
			if gy + 1 < Constants.GRID_HEIGHT:
				_astar.connect_points(pid, _point_id(gx, gy + 1))
	grid_changed.emit()

func get_path_to_goal(from_world: Vector2) -> PackedVector2Array:
	var from_grid := Constants.world_to_grid(from_world)
	if not Constants.is_in_grid(from_grid.x, from_grid.y):
		return PackedVector2Array()
	var from_id := _point_id(from_grid.x, from_grid.y)
	var to_id := _point_id(goal_point.x, goal_point.y)
	if _astar.is_point_disabled(from_id):
		# Try to find nearest non-disabled point
		var closest := _astar.get_closest_point(Constants.grid_to_world(from_grid.x, from_grid.y))
		from_id = closest
	if _astar.is_point_disabled(to_id):
		return PackedVector2Array()
	var path := _astar.get_point_path(from_id, to_id)
	return path

func has_path_from_spawns() -> bool:
	var to_id := _point_id(goal_point.x, goal_point.y)
	if _astar.is_point_disabled(to_id):
		return false
	for sp in spawn_points:
		var from_id := _point_id(sp.x, sp.y)
		if _astar.is_point_disabled(from_id):
			return false
		var path := _astar.get_point_path(from_id, to_id)
		if path.size() == 0:
			return false
	return true

func would_block_path(gp: Vector2i) -> bool:
	# Temporarily disable this point and check if paths still exist
	var pid := _point_id(gp.x, gp.y)
	_astar.set_point_disabled(pid, true)
	var still_has_path := has_path_from_spawns()
	_astar.set_point_disabled(pid, false)
	return not still_has_path

func clear_all_occupancy() -> void:
	_occupied.clear()
	_rebuild_astar()

func get_highlight_pos() -> Vector2i:
	return _highlight_pos
