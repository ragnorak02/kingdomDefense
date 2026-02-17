extends Node2D

var direction := Vector2(1, 0)
var damage: int = 40
var aoe_radius: float = 50.0
var _speed: float = 250.0
var _max_range: float = 300.0
var _spawn_pos: Vector2
var _enemy_manager: Node
var _exploding: bool = false
var _explode_timer: float = 0.0
var _explode_radius: float = 0.0

func set_enemy_manager(em: Node) -> void:
	_enemy_manager = em

func _ready() -> void:
	_spawn_pos = position
	_speed = Constants.SPELL_DATA[Constants.Spell.FIREBALL]["speed"]
	_max_range = Constants.SPELL_DATA[Constants.Spell.FIREBALL]["max_range"]

func _process(delta: float) -> void:
	if _exploding:
		_explode_timer -= delta
		_explode_radius = aoe_radius * (1.0 - _explode_timer / 0.3)
		queue_redraw()
		if _explode_timer <= 0:
			queue_free()
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

	queue_redraw()

func _explode() -> void:
	_exploding = true
	_explode_timer = 0.3
	AudioManager.play("fireball_explode")

	# AoE damage
	if _enemy_manager:
		var enemies = _enemy_manager.get_enemies()
		for enemy in enemies:
			if not is_instance_valid(enemy):
				continue
			if position.distance_to(enemy.position) <= aoe_radius:
				enemy.take_damage(damage)

func _draw() -> void:
	if _exploding:
		# Expanding explosion ring
		var t := _explode_timer / 0.3
		var alpha := t * 0.7
		draw_circle(Vector2.ZERO, _explode_radius, Color(1.0, 0.4, 0.1, alpha * 0.4))
		draw_arc(Vector2.ZERO, _explode_radius, 0, TAU, 24, Color(1.0, 0.6, 0.2, alpha), 2.0)
		# Inner bright core
		draw_circle(Vector2.ZERO, _explode_radius * 0.3, Color(1.0, 0.9, 0.3, alpha * 0.6))
	else:
		# Flying fireball
		draw_circle(Vector2.ZERO, 6.0, Color(1.0, 0.5, 0.1, 0.8))
		draw_circle(Vector2.ZERO, 3.0, Color(1.0, 0.9, 0.3, 0.9))
		# Trailing glow
		var trail_dir := -direction.normalized() * 8.0
		draw_circle(trail_dir, 4.0, Color(1.0, 0.3, 0.0, 0.4))
