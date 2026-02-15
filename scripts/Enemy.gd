extends Node2D

signal died
signal reached_goal

var hp: int = 40
var max_hp: int = 40
var speed: float = 60.0
var base_damage: int = 1
var gold_mult: float = 1.0
var enemy_type: String = "goblin"
var _path: PackedVector2Array = PackedVector2Array()
var _path_idx: int = 0
var _grid_manager: Node2D
var _game_manager: Node
var _repath_timer: float = 0.0
var _sprite: Sprite2D

func setup(wave: int, grid_mgr: Node2D, game_mgr: Node, type: String = "goblin") -> void:
	_grid_manager = grid_mgr
	_game_manager = game_mgr
	_grid_manager.grid_changed.connect(_on_grid_changed)
	enemy_type = type
	var type_data: Dictionary = Constants.ENEMY_TYPES[type]
	max_hp = int(Constants.ENEMY_BASE_HP * type_data["hp_mult"] * (1.0 + Constants.ENEMY_HP_SCALE_PER_WAVE * (wave - 1)))
	hp = max_hp
	speed = Constants.ENEMY_BASE_SPEED * type_data["speed_mult"] * (1.0 + Constants.ENEMY_SPEED_SCALE_PER_WAVE * (wave - 1))
	base_damage = type_data["damage"]
	gold_mult = type_data["gold_mult"]
	_recalculate_path()

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/enemy.png")  # Default, overridden in _setup_sprite
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0, -16)
	add_child(_sprite)

func _setup_sprite() -> void:
	var type_data: Dictionary = Constants.ENEMY_TYPES.get(enemy_type, Constants.ENEMY_TYPES["goblin"])
	_sprite.texture = load(type_data["sprite"])

func _on_grid_changed() -> void:
	if not is_queued_for_deletion():
		_recalculate_path()

func _recalculate_path() -> void:
	_path = _grid_manager.get_path_to_goal(position)
	_path_idx = 1  # Skip current position

func _process(delta: float) -> void:
	# Load correct sprite once (after setup has run)
	if _sprite and _sprite.texture and _sprite.texture.resource_path == "res://assets/enemy.png" and enemy_type != "goblin":
		_setup_sprite()

	if _path.size() == 0:
		_repath_timer -= delta
		if _repath_timer <= 0:
			_recalculate_path()
			_repath_timer = 0.5
		return

	if _path_idx >= _path.size():
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
		if _sprite and abs(dir.x) > 0.1:
			_sprite.flip_h = dir.x < 0

	# Periodic repath as fallback
	_repath_timer -= delta
	if _repath_timer <= 0:
		_recalculate_path()
		_repath_timer = 5.0

	var gp := Constants.world_to_grid(position)
	z_index = gp.x + gp.y + 1

	queue_redraw()

func take_damage(amount: int) -> void:
	hp -= amount
	if _sprite:
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
	# HP bar
	var bar_w := 20.0
	var bar_h := 3.0
	var bar_y := -30.0
	var hp_ratio := float(hp) / float(max_hp)
	draw_rect(Rect2(-bar_w / 2, bar_y, bar_w, bar_h), Color(0.2, 0.2, 0.2))
	var bar_color := Color(0.1, 0.9, 0.1) if hp_ratio > 0.5 else Color(0.9, 0.9, 0.1) if hp_ratio > 0.25 else Color(0.9, 0.1, 0.1)
	draw_rect(Rect2(-bar_w / 2, bar_y, bar_w * hp_ratio, bar_h), bar_color)
