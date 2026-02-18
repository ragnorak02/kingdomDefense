extends Node2D

signal mana_changed(current: int, maximum: int)
signal spell_changed(spell_name: String)

var _attack_cooldown: float = 0.0
var _facing := Vector2(1, 0)
var _attack_anim_timer: float = 0.0
var _is_attacking: bool = false
var _is_moving: bool = false
var _bounds_min: Vector2
var _bounds_max: Vector2
var _anim_sprite: AnimatedSprite2D

# Magic system
var _mana: int = Constants.HERO_MAX_MANA
var _mana_regen_accum: float = 0.0
var _current_spell: int = 0  # index into Constants.Spell values
var _spell_cooldowns := {}  # Spell enum -> remaining cooldown

@onready var enemy_manager: Node = get_node("../EnemyManager")
@onready var _projectile_container: Node2D = get_node("../Projectiles")

func _ready() -> void:
	# Compute grid bounding box for hero clamping
	var corners := [
		Constants.grid_to_world(0, 0),
		Constants.grid_to_world(Constants.GRID_WIDTH - 1, 0),
		Constants.grid_to_world(0, Constants.GRID_HEIGHT - 1),
		Constants.grid_to_world(Constants.GRID_WIDTH - 1, Constants.GRID_HEIGHT - 1),
	]
	_bounds_min = corners[0]
	_bounds_max = corners[0]
	for c in corners:
		_bounds_min.x = minf(_bounds_min.x, c.x)
		_bounds_min.y = minf(_bounds_min.y, c.y)
		_bounds_max.x = maxf(_bounds_max.x, c.x)
		_bounds_max.y = maxf(_bounds_max.y, c.y)

	# Create animated sprite
	_anim_sprite = AnimatedSprite2D.new()
	_anim_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anim_sprite.offset = Vector2(0, -16)
	var frames := SpriteFrames.new()
	frames.remove_animation("default")

	# Idle animation (4 frames, 4 FPS)
	frames.add_animation("idle")
	frames.set_animation_speed("idle", 4.0)
	frames.set_animation_loop("idle", true)
	var idle_sheet: Texture2D = load("res://assets/hero_idle.png")
	for i in range(4):
		var atlas := AtlasTexture.new()
		atlas.atlas = idle_sheet
		atlas.region = Rect2(i * 32, 0, 32, 32)
		frames.add_frame("idle", atlas)

	# Walk animation (4 frames, 8 FPS)
	frames.add_animation("walk")
	frames.set_animation_speed("walk", 8.0)
	frames.set_animation_loop("walk", true)
	var walk_sheet: Texture2D = load("res://assets/hero_walk.png")
	for i in range(4):
		var atlas := AtlasTexture.new()
		atlas.atlas = walk_sheet
		atlas.region = Rect2(i * 32, 0, 32, 32)
		frames.add_frame("walk", atlas)

	# Attack animation (3 frames, 10 FPS)
	frames.add_animation("attack")
	frames.set_animation_speed("attack", 10.0)
	frames.set_animation_loop("attack", false)
	var attack_sheet: Texture2D = load("res://assets/hero_attack.png")
	for i in range(3):
		var atlas := AtlasTexture.new()
		atlas.atlas = attack_sheet
		atlas.region = Rect2(i * 32, 0, 32, 32)
		frames.add_frame("attack", atlas)

	_anim_sprite.sprite_frames = frames
	_anim_sprite.play("idle")
	add_child(_anim_sprite)

	# Init spell cooldowns
	for spell_key in Constants.SPELL_DATA:
		_spell_cooldowns[spell_key] = 0.0

	# Emit initial state
	mana_changed.emit(_mana, Constants.HERO_MAX_MANA)
	spell_changed.emit(_get_current_spell_name())

func _process(delta: float) -> void:
	# Movement
	var input := Vector2.ZERO
	input.x = Input.get_axis("move_left", "move_right")
	input.y = Input.get_axis("move_up", "move_down")

	_is_moving = input.length() > 0.1
	if _is_moving:
		# Convert to isometric movement
		var iso_input := Vector2(
			input.x - input.y,
			(input.x + input.y) * 0.5
		).normalized()
		position += iso_input * Constants.HERO_SPEED * delta
		position = position.clamp(_bounds_min, _bounds_max)
		_facing = iso_input.normalized()
		# Flip sprite based on horizontal direction
		_anim_sprite.flip_h = _facing.x < 0

	# Attack cooldown
	_attack_cooldown -= delta
	_attack_anim_timer -= delta
	if _attack_anim_timer <= 0:
		_is_attacking = false

	# Attack
	if Input.is_action_pressed("hero_attack") and _attack_cooldown <= 0:
		_perform_attack()

	# Spell cycling
	if Input.is_action_just_pressed("cycle_spell"):
		_cycle_spell()

	# Spell casting
	if Input.is_action_just_pressed("cast_spell"):
		_cast_spell()

	# Mana regen
	_mana_regen_accum += Constants.HERO_MANA_REGEN * delta
	if _mana_regen_accum >= 1.0:
		var gained := int(_mana_regen_accum)
		_mana = mini(_mana + gained, Constants.HERO_MAX_MANA)
		_mana_regen_accum -= gained
		mana_changed.emit(_mana, Constants.HERO_MAX_MANA)

	# Spell cooldowns
	for spell_key in _spell_cooldowns:
		if _spell_cooldowns[spell_key] > 0:
			_spell_cooldowns[spell_key] -= delta

	# Animation state switching
	if _is_attacking:
		if _anim_sprite.animation != "attack":
			_anim_sprite.play("attack")
		_anim_sprite.modulate = Color(1.5, 1.5, 0.8)
	elif _is_moving:
		if _anim_sprite.animation != "walk":
			_anim_sprite.play("walk")
		_anim_sprite.modulate = Color.WHITE
	else:
		if _anim_sprite.animation != "idle":
			_anim_sprite.play("idle")
		_anim_sprite.modulate = Color.WHITE

	# Z-index
	var gp := Constants.world_to_grid(position)
	z_index = gp.x + gp.y + 2

func _perform_attack() -> void:
	_attack_cooldown = Constants.HERO_ATTACK_COOLDOWN
	_is_attacking = true
	_attack_anim_timer = 0.3
	AudioManager.play("sword_attack")

	# Spawn slash effect
	_spawn_slash_effect()

	# Find enemies in range
	var enemies = enemy_manager.get_enemies()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := position.distance_to(enemy.position)
		if dist <= Constants.HERO_ATTACK_RANGE:
			enemy.take_damage(Constants.HERO_ATTACK_DAMAGE)

func _spawn_slash_effect() -> void:
	var slash := AnimatedSprite2D.new()
	slash.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var slash_frames := SpriteFrames.new()
	slash_frames.remove_animation("default")
	slash_frames.add_animation("slash")
	slash_frames.set_animation_speed("slash", 10.0)
	slash_frames.set_animation_loop("slash", false)
	var slash_sheet: Texture2D = load("res://assets/slash_effect.png")
	for i in range(3):
		var atlas := AtlasTexture.new()
		atlas.atlas = slash_sheet
		atlas.region = Rect2(i * 64, 0, 64, 64)
		slash_frames.add_frame("slash", atlas)
	slash.sprite_frames = slash_frames
	slash.rotation = _facing.angle()
	slash.animation_finished.connect(slash.queue_free)
	add_child(slash)
	slash.play("slash")

# ── Magic System ──

func _get_current_spell_name() -> String:
	var spell_key: int = Constants.Spell.values()[_current_spell]
	return Constants.SPELL_DATA[spell_key]["name"]

func _cycle_spell() -> void:
	_current_spell = (_current_spell + 1) % Constants.Spell.size()
	AudioManager.play("select")
	spell_changed.emit(_get_current_spell_name())

func _cast_spell() -> void:
	var spell_key: int = Constants.Spell.values()[_current_spell]
	var data: Dictionary = Constants.SPELL_DATA[spell_key]

	# Check cooldown
	if _spell_cooldowns[spell_key] > 0:
		return

	# Check mana
	if _mana < data["cost"]:
		return

	# Spend mana and set cooldown
	_mana -= data["cost"]
	_spell_cooldowns[spell_key] = data["cooldown"]
	mana_changed.emit(_mana, Constants.HERO_MAX_MANA)

	match spell_key:
		Constants.Spell.FIREBALL:
			_cast_fireball()
		Constants.Spell.ICE_BLAST:
			_cast_ice_blast()

func _cast_fireball() -> void:
	AudioManager.play("fireball_cast")
	var fireball = preload("res://scenes/Fireball.tscn").instantiate()
	fireball.position = position
	fireball.direction = _facing
	fireball.damage = Constants.SPELL_DATA[Constants.Spell.FIREBALL]["damage"]
	fireball.aoe_radius = Constants.SPELL_DATA[Constants.Spell.FIREBALL]["aoe_radius"]
	fireball.set_enemy_manager(enemy_manager)
	_projectile_container.add_child(fireball)

func _cast_ice_blast() -> void:
	AudioManager.play("ice_blast")
	var data: Dictionary = Constants.SPELL_DATA[Constants.Spell.ICE_BLAST]
	# Instant AoE around hero
	var enemies = enemy_manager.get_enemies()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := position.distance_to(enemy.position)
		if dist <= data["aoe_radius"]:
			enemy.take_damage(data["damage"])
			enemy.apply_slow(data["slow_factor"], data["slow_duration"])
