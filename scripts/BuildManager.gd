extends Node

const GameManagerClass = preload("res://scripts/GameManager.gd")

var selected_item: int = Constants.BuildItem.NONE
var _placed_structures: Array[Node2D] = []

@onready var grid_manager: Node2D = get_node("../GridManager")
@onready var game_manager: Node = get_node("../GameManager")

signal item_selected(item: int)
signal placement_failed(reason: String)
signal item_placed(item: int, grid_pos: Vector2i)
signal item_removed(grid_pos: Vector2i)
signal item_upgraded(grid_pos: Vector2i, new_level: int)

func _ready() -> void:
	grid_manager.tile_clicked.connect(_on_tile_clicked)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_build"):
		deselect()
	if event.is_action_pressed("toggle_build"):
		pass

func select_item(item: int) -> void:
	selected_item = item
	item_selected.emit(item)
	AudioManager.play("select")

func deselect() -> void:
	selected_item = Constants.BuildItem.NONE
	item_selected.emit(selected_item)

func _on_tile_clicked(grid_pos: Vector2i) -> void:
	if game_manager.current_phase != GameManagerClass.Phase.PLANNING:
		return
	if selected_item == Constants.BuildItem.NONE:
		return

	if selected_item == Constants.BuildItem.REMOVE:
		_try_remove(grid_pos)
		return

	if selected_item == Constants.BuildItem.UPGRADE:
		_try_upgrade(grid_pos)
		return

	_try_place(grid_pos, selected_item)

func _try_place(grid_pos: Vector2i, item: int) -> void:
	if grid_manager.is_occupied(grid_pos):
		placement_failed.emit("Tile is occupied")
		AudioManager.play("build_fail")
		return
	if grid_manager.is_special_tile(grid_pos):
		placement_failed.emit("Cannot build on spawn/goal")
		AudioManager.play("build_fail")
		return
	var data: Dictionary = Constants.BUILD_DATA[item]
	if game_manager.gold < data["cost"]:
		placement_failed.emit("Not enough gold")
		AudioManager.play("build_fail")
		return
	if data["blocking"] and grid_manager.would_block_path(grid_pos):
		placement_failed.emit("Would block all enemy paths!")
		AudioManager.play("build_fail")
		return

	game_manager.spend_gold(data["cost"])
	var structure := _create_structure(grid_pos, item)
	grid_manager.set_occupied(grid_pos, item, structure)
	_placed_structures.append(structure)
	item_placed.emit(item, grid_pos)
	AudioManager.play("build_place")

func _try_remove(grid_pos: Vector2i) -> void:
	if not grid_manager.is_occupied(grid_pos):
		placement_failed.emit("Nothing to remove")
		AudioManager.play("build_fail")
		return
	var occupant = grid_manager.get_occupant(grid_pos)
	var item_type: int = occupant["item"]
	var node: Node2D = occupant["node"]
	var data: Dictionary = Constants.BUILD_DATA[item_type]
	var refund := int(data["cost"] * Constants.REFUND_RATIO)
	game_manager.refund_gold(refund)
	grid_manager.clear_occupied(grid_pos)
	if node and is_instance_valid(node):
		_placed_structures.erase(node)
		node.queue_free()
	item_removed.emit(grid_pos)
	AudioManager.play("build_remove")

func _try_upgrade(grid_pos: Vector2i) -> void:
	if not grid_manager.is_occupied(grid_pos):
		placement_failed.emit("Nothing to upgrade")
		AudioManager.play("build_fail")
		return
	var occupant = grid_manager.get_occupant(grid_pos)
	var item_type: int = occupant["item"]
	var node: Node2D = occupant["node"]

	# Only towers and archers can be upgraded
	if item_type != Constants.BuildItem.ARCHER_TOWER and item_type != Constants.BuildItem.GROUND_ARCHER:
		placement_failed.emit("Can only upgrade towers/archers")
		AudioManager.play("build_fail")
		return

	if not node or not is_instance_valid(node) or not node.has_method("upgrade"):
		placement_failed.emit("Cannot upgrade this")
		AudioManager.play("build_fail")
		return

	var current_level: int = node.level
	if current_level >= Constants.MAX_UPGRADE_LEVEL:
		placement_failed.emit("Already max level!")
		AudioManager.play("build_fail")
		return

	var cost := Constants.get_upgrade_cost(item_type, current_level)
	if game_manager.gold < cost:
		placement_failed.emit("Not enough gold (%dg needed)" % cost)
		AudioManager.play("build_fail")
		return

	game_manager.spend_gold(cost)
	node.upgrade()
	item_upgraded.emit(grid_pos, node.level)

func _create_structure(grid_pos: Vector2i, item: int) -> Node2D:
	var world_pos := Constants.grid_to_world(grid_pos.x, grid_pos.y)
	var node: Node2D

	if item == Constants.BuildItem.ARCHER_TOWER:
		node = preload("res://scenes/ArcherTower.tscn").instantiate()
	elif item == Constants.BuildItem.GROUND_ARCHER:
		node = preload("res://scenes/GroundArcher.tscn").instantiate()
	else:
		node = Node2D.new()
		var sprite := Sprite2D.new()
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		if item == Constants.BuildItem.WALL:
			sprite.texture = load("res://assets/wall.png")
			sprite.offset = Vector2(0, -12)
		else:
			sprite.texture = load("res://assets/rock.png")
			sprite.offset = Vector2(0, -12)
		node.add_child(sprite)

	node.position = world_pos
	node.z_index = grid_pos.x + grid_pos.y
	get_node("../Structures").add_child(node)
	return node

func clear_all() -> void:
	for s in _placed_structures:
		if is_instance_valid(s):
			s.queue_free()
	_placed_structures.clear()
	grid_manager.clear_all_occupancy()
	deselect()
