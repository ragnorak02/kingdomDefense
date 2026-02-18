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
var _anim_sprite: AnimatedSprite2D
var _slow_factor: float = 1.0
var _slow_timer: float = 0.0
var _base_speed: float = 0.0
var _sprite_ready: bool = false

func setup(wave: int, grid_mgr: Node2D, game_mgr: Node, type: String = "goblin") -> void:
	_grid_manager = grid_mgr
	_game_manager = game_mgr
	_grid_manager.grid_changed.connect(_on_grid_changed)
	enemy_type = type
	var type_data: Dictionary = Constants.ENEMY_TYPES[type]
	max_hp = int(Constants.ENEMY_BASE_HP * type_data["hp_mult"] * (1.0 + Constants.ENEMY_HP_SCALE_PER_WAVE * (wave - 1)))
	hp = max_hp
	speed = Constants.ENEMY_BASE_SPEED * type_data["speed_mult"] * (1.0 + Constants.ENEMY_SPEED_SCALE_PER_WAVE * (wave - 1))
	_base_speed = speed
	base_damage = type_data["damage"]
	gold_mult = type_data["gold_mult"]
	_recalculate_path()

func _ready() -> void:
	_anim_sprite = AnimatedSprite2D.new()
	_anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim_sprite.offset = Vector2(0, -16)
	add_child(_anim_sprite)

func _setup_sprite() -> void:
	var type_data: Dictionary = Constants.ENEMY_TYPES.get(enemy_type, Constants.ENEMY_TYPES["goblin"])
	var walk_sheet: Texture2D = load(type_data["walk_sheet"])
	var frame_count: int = type_data["frame_count"]

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("walk", true)
	for i in range(frame_count):
		var atlas := AtlasTexture.new()
		atlas.atlas = walk_sheet
		atlas.region = Rect2(i * 32, 0, 32, 32)
		frames.add_frame("walk", atlas)

	_anim_sprite.sprite_frames = frames
	_anim_sprite.play("walk")
	_sprite_ready = true

func _on_grid_changed() -> void:
	if not is_queued_for_deletion():
		_recalculate_path()

func _recalculate_path() -> void:
	_path = _grid_manager.get_path_to_goal(position)
	_path_idx = 1  # Skip current position

func _process(delta: float) -> void:
	# Load correct sprite once (after setup has run)
	if not _sprite_ready:
		_setup_sprite()

	# Slow timer
	if _slow_timer > 0:
		_slow_timer -= delta
		if _slow_timer <= 0:
			_slow_factor = 1.0
			speed = _base_speed
			if _anim_sprite:
				_anim_sprite.modulate = Color.WHITE

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
		if _anim_sprite and abs(dir.x) > 0.1:
			_anim_sprite.flip_h = dir.x < 0

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
	if _anim_sprite:
		_anim_sprite.modulate = Color(3, 0.5, 0.5)
		var restore_color := Color(0.5, 0.7, 1.0) if _slow_timer > 0 else Color.WHITE
		var tween := create_tween()
		tween.tween_property(_anim_sprite, "modulate", restore_color, 0.15)
	if hp <= 0:
		AudioManager.play("enemy_death")
		died.emit()
		queue_free()
	else:
		AudioManager.play("enemy_hit")

func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = factor
	_slow_timer = duration
	speed = _base_speed * _slow_factor
	if _anim_sprite:
		_anim_sprite.modulate = Color(0.5, 0.7, 1.0)

func _draw() -> void:
	# Enhanced HP bar with border and gradient
	var bar_w := 22.0
	var bar_h := 4.0
	var bar_y := -32.0
	var hp_ratio := float(hp) / float(max_hp)

	# Black border
	draw_rect(Rect2(-bar_w / 2 - 1, bar_y - 1, bar_w + 2, bar_h + 2), Color(0.0, 0.0, 0.0, 0.8))
	# Background
	draw_rect(Rect2(-bar_w / 2, bar_y, bar_w, bar_h), Color(0.15, 0.15, 0.15))

	# HP fill color
	var bar_color: Color
	if hp_ratio > 0.5:
		bar_color = Color(0.1, 0.85, 0.1)
	elif hp_ratio > 0.25:
		bar_color = Color(0.85, 0.85, 0.1)
	else:
		bar_color = Color(0.85, 0.1, 0.1)

	# Main fill
	var fill_w := bar_w * hp_ratio
	draw_rect(Rect2(-bar_w / 2, bar_y, fill_w, bar_h), bar_color)
	# Gradient highlight on top half
	var highlight := Color(bar_color.r + 0.2, bar_color.g + 0.2, bar_color.b + 0.2, 0.5)
	draw_rect(Rect2(-bar_w / 2, bar_y, fill_w, bar_h * 0.5), highlight)
