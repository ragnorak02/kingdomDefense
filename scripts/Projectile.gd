extends Node2D

var target: Node2D = null
var speed: float = 300.0
var damage: int = 10
var _last_target_pos: Vector2
var _spawn_pos: Vector2
var _sprite: Sprite2D

func _ready() -> void:
	_spawn_pos = position
	if target and is_instance_valid(target):
		_last_target_pos = target.position

	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/arrow.png")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(_sprite)

func _process(delta: float) -> void:
	var target_pos: Vector2
	if target and is_instance_valid(target):
		target_pos = target.position
		_last_target_pos = target_pos
	else:
		target_pos = _last_target_pos

	var dir := (target_pos - position)
	var dist := dir.length()

	if dist < 8.0:
		# Hit
		if target and is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(damage)
		queue_free()
		return

	position += dir.normalized() * speed * delta

	# Rotate arrow to face direction of travel
	_sprite.rotation = dir.angle()

	# Self-destruct after going too far from spawn
	if position.distance_to(_spawn_pos) > 1000:
		queue_free()
