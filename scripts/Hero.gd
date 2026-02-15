extends Node2D

var _attack_cooldown: float = 0.0
var _facing := Vector2(1, 0)
var _attack_anim_timer: float = 0.0
var _is_attacking: bool = false
var _bounds_min: Vector2
var _bounds_max: Vector2
var _sprite: Sprite2D

@onready var enemy_manager: Node = get_node("../EnemyManager")

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
	if _attack_anim_timer <= 0:
		_is_attacking = false

	# Attack
	if Input.is_action_pressed("hero_attack") and _attack_cooldown <= 0:
		_perform_attack()

	# Attack visual feedback
	_sprite.modulate = Color(1.5, 1.5, 0.8) if _is_attacking else Color.WHITE

	# Z-index
	var gp := Constants.world_to_grid(position)
	z_index = gp.x + gp.y + 2

func _perform_attack() -> void:
	_attack_cooldown = Constants.HERO_ATTACK_COOLDOWN
	_is_attacking = true
	_attack_anim_timer = 0.2
	AudioManager.play("sword_attack")

	# Find enemies in range
	var enemies := enemy_manager.get_enemies()
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var dist := position.distance_to(enemy.position)
		if dist <= Constants.HERO_ATTACK_RANGE:
			enemy.take_damage(Constants.HERO_ATTACK_DAMAGE)
