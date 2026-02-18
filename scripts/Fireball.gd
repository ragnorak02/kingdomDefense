extends Node2D

var direction := Vector2(1, 0)
var damage: int = 40
var aoe_radius: float = 50.0
var _speed: float = 250.0
var _max_range: float = 300.0
var _spawn_pos: Vector2
var _enemy_manager: Node
var _exploding: bool = false
var _anim_sprite: AnimatedSprite2D

func set_enemy_manager(em: Node) -> void:
	_enemy_manager = em

func _ready() -> void:
	_spawn_pos = position
	_speed = Constants.SPELL_DATA[Constants.Spell.FIREBALL]["speed"]
	_max_range = Constants.SPELL_DATA[Constants.Spell.FIREBALL]["max_range"]

	# Create animated sprite with fly and explode animations
	_anim_sprite = AnimatedSprite2D.new()
	_anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	# Fly animation (3 frames, 10 FPS, looping)
	frames.add_animation("fly")
	frames.set_animation_speed("fly", 10.0)
	frames.set_animation_loop("fly", true)
	var fly_sheet: Texture2D = load("res://assets/fireball_fly.png")
	for i in range(3):
		var atlas := AtlasTexture.new()
		atlas.atlas = fly_sheet
		atlas.region = Rect2(i * 32, 0, 32, 32)
		frames.add_frame("fly", atlas)

	# Explode animation (4 frames, 12 FPS, one-shot)
	frames.add_animation("explode")
	frames.set_animation_speed("explode", 12.0)
	frames.set_animation_loop("explode", false)
	var explode_sheet: Texture2D = load("res://assets/fireball_explode.png")
	for i in range(4):
		var atlas := AtlasTexture.new()
		atlas.atlas = explode_sheet
		atlas.region = Rect2(i * 48, 0, 48, 48)
		frames.add_frame("explode", atlas)

	_anim_sprite.sprite_frames = frames
	_anim_sprite.play("fly")
	_anim_sprite.animation_finished.connect(_on_animation_finished)
	add_child(_anim_sprite)

func _process(delta: float) -> void:
	if _exploding:
		return

	# Move in direction
	position += direction.normalized() * _speed * delta

	# Check for enemy collisions
	if _enemy_manager:
		var enemies = _enemy_manager.get_enemies()
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if position.distance_to(enemy.position) < 15.0:
				_explode()
				return

	# Max range check
	if position.distance_to(_spawn_pos) > _max_range:
		_explode()
		return

func _explode() -> void:
	_exploding = true
	AudioManager.play("fireball_explode")
	_anim_sprite.play("explode")

	# AoE damage
	if _enemy_manager:
		var enemies = _enemy_manager.get_enemies()
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if position.distance_to(enemy.position) <= aoe_radius:
				enemy.take_damage(damage)

func _on_animation_finished() -> void:
	if _exploding:
		queue_free()
