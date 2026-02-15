extends Node2D

signal died
signal reached_goal

var hp: int = 40
var max_hp: int = 40
var speed: float = 60.0
var _path: PackedVector2Array = PackedVector2Array()
var _path_idx: int = 0
var _grid_manager: Node2D
var _game_manager: Node
var _repath_timer: float = 0.0
var _sprite: Sprite2D
var _hp_bar_bg: ColorRect
var _hp_bar_fill: ColorRect

func setup(wave: int, grid_mgr: Node2D, game_mgr: Node) -> void:
	_grid_manager = grid_mgr
	_game_manager = game_mgr
	_grid_manager.grid_changed.connect(_on_grid_changed)
	max_hp = int(Constants.ENEMY_BASE_HP * (1.0 + Constants.ENEMY_HP_SCALE_PER_WAVE * (wave - 1)))
	hp = max_hp
	speed = Constants.ENEMY_BASE_SPEED * (1.0 + Constants.ENEMY_SPEED_SCALE_PER_WAVE * (wave - 1))
	_recalculate_path()

func _ready() -> void:
	# Sprite
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/enemy.png")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0, -16)
	add_child(_sprite)

	# HP bar (using simple draw since ColorRect would need a SubViewport for world-space)

func _on_grid_changed() -> void:
	if not is_queued_for_deletion():
		_recalculate_path()

func _recalculate_path() -> void:
	_path = _grid_manager.get_path_to_goal(position)
	_path_idx = 1  # Skip current position

func _process(delta: float) -> void:
	if _path.size() == 0:
		_repath_timer -= delta
		if _repath_timer <= 0:
			_recalculate_path()
			_repath_timer = 0.5
		return

	if _path_idx >= _path.size():
		# Reached goal
		reached_goal.emit()
		queue_free()
		return

	var target: Vector2 = _path[_path_idx]
	var dir := (target - position)
	var dist := dir.length()

	if dist < 3.0:
		_path_idx += 1
	else:
		position += dir.normalized() * speed * delta
		# Flip sprite based on movement direction
		if abs(dir.x) > 0.1:
			_sprite.flip_h = dir.x < 0

	# Periodic repath as fallback (signal-driven repath handles most cases)
	_repath_timer -= delta
	if _repath_timer <= 0:
		_recalculate_path()
		_repath_timer = 5.0

	# Z-index for proper draw order
	var gp := Constants.world_to_grid(position)
	z_index = gp.x + gp.y + 1

	queue_redraw()

func take_damage(amount: int) -> void:
	hp -= amount
	# Flash red on hit
	_sprite.modulate = Color(3, 0.5, 0.5)
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.15)
	if hp <= 0:
		AudioManager.play("enemy_death")
		died.emit()
		queue_free()
	else:
		AudioManager.play("enemy_hit")

func _draw() -> void:
	# HP bar (drawn above sprite)
	var bar_w := 20.0
	var bar_h := 3.0
	var bar_y := -30.0
	var hp_ratio := float(hp) / float(max_hp)
	draw_rect(Rect2(-bar_w / 2, bar_y, bar_w, bar_h), Color(0.2, 0.2, 0.2))
	draw_rect(Rect2(-bar_w / 2, bar_y, bar_w * hp_ratio, bar_h), Color(0.1, 0.9, 0.1))
