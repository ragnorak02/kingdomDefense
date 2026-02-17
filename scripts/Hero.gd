extends Node2D

signal mana_changed(current: int, maximum: int)
signal spell_changed(spell_name: String)

var _attack_cooldown: float = 0.0
var _facing := Vector2(1, 0)
var _attack_anim_timer: float = 0.0
var _attack_arc_timer: float = 0.0
var _attack_arc_facing := Vector2(1, 0)
var _is_attacking: bool = false
var _bounds_min: Vector2
var _bounds_max: Vector2
var _sprite: Sprite2D

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

	# Create sprite
	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/hero.png")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0, -16)
	add_child(_sprite)

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

	if input.length() > 0.1:
		# Convert to isometric movement
		var iso_input := Vector2(
			input.x - input.y,
			(input.x + input.y) * 0.5
		).normalized()
		position += iso_input * Constants.HERO_SPEED * delta
		position = position.clamp(_bounds_min, _bounds_max)
		_facing = iso_input.normalized()
		# Flip sprite based on horizontal direction
		_sprite.flip_h = _facing.x < 0

	# Attack cooldown
	_attack_cooldown -= delta
	_attack_anim_timer -= delta
	_attack_arc_timer -= delta
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

	# Attack visual feedback
	_sprite.modulate = Color(1.5, 1.5, 0.8) if _is_attacking else Color.WHITE

	# Z-index
	var gp := Constants.world_to_grid(position)
	z_index = gp.x + gp.y + 2

	queue_redraw()

func _perform_attack() -> void:
	_attack_cooldown = Constants.HERO_ATTACK_COOLDOWN
	_is_attacking = true
	_attack_anim_timer = 0.2
	_attack_arc_timer = 0.3
	_attack_arc_facing = _facing
	AudioManager.play("sword_attack")

	# Find enemies in range
	var enemies = enemy_manager.get_enemies()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := position.distance_to(enemy.position)
		if dist <= Constants.HERO_ATTACK_RANGE:
			enemy.take_damage(Constants.HERO_ATTACK_DAMAGE)

func _draw() -> void:
	# Attack arc visual
	if _attack_arc_timer > 0:
		var t := _attack_arc_timer / 0.3  # 1.0 at start, 0.0 at end
		var arc_radius := 60.0
		var arc_angle := PI  # 180 degrees
		var center_angle := _attack_arc_facing.angle()

		# Sweep: arc opens from narrow to full over first half, then fades
		var sweep := minf(t * 2.0, 1.0)  # opens quickly
		var alpha := t * 0.6  # fades out

		var half_arc := arc_angle * 0.5 * sweep
		var start_angle := center_angle - half_arc
		var point_count := 16
		var arc_color := Color(1.0, 0.85, 0.3, alpha)
		var edge_color := Color(1.0, 0.95, 0.6, alpha * 1.5)

		# Build wedge polygon: center -> arc points
		var points := PackedVector2Array()
		points.append(Vector2.ZERO)
		for i in range(point_count + 1):
			var angle := start_angle + (half_arc * 2.0) * float(i) / float(point_count)
			points.append(Vector2(cos(angle), sin(angle)) * arc_radius)

		# Draw filled wedge
		if points.size() >= 3:
			var colors := PackedColorArray()
			for i2 in points.size():
				colors.append(arc_color)
			draw_polygon(points, colors)

		# Draw bright edge arc line
		var edge_points := PackedVector2Array()
		for i in range(point_count + 1):
			var angle := start_angle + (half_arc * 2.0) * float(i) / float(point_count)
			edge_points.append(Vector2(cos(angle), sin(angle)) * arc_radius)
		if edge_points.size() >= 2:
			draw_polyline(edge_points, edge_color, 2.0)

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
