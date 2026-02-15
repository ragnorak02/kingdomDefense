extends Node2D

var _fire_timer: float = 0.0
var _target: Node2D = null
var _stats: Dictionary
var _sprite: Sprite2D

@onready var enemy_manager: Node = get_node("../../EnemyManager")
@onready var projectile_container: Node2D = get_node("../../Projectiles")

func _ready() -> void:
	_stats = Constants.ARCHER_TOWER_STATS

	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/archer_tower.png")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0, -24)
	add_child(_sprite)

func _process(delta: float) -> void:
	_fire_timer -= delta

	# Find target
	_target = _find_closest_enemy()
	if _target and _fire_timer <= 0:
		_fire()
		_fire_timer = 1.0 / _stats["fire_rate"]

func _find_closest_enemy() -> Node2D:
	var enemies := enemy_manager.get_enemies()
	var closest: Node2D = null
	var closest_dist := _stats["range"]
	for e in enemies:
		if not is_instance_valid(e):
			continue
		var d := position.distance_to(e.position)
		if d < closest_dist:
			closest_dist = d
			closest = e
	return closest

func _fire() -> void:
	if not _target or not is_instance_valid(_target):
		return
	var proj: Node2D = preload("res://scenes/Projectile.tscn").instantiate()
	proj.position = position + Vector2(0, -18)
	proj.target = _target
	proj.speed = _stats["projectile_speed"]
	proj.damage = _stats["damage"]
	projectile_container.add_child(proj)
	AudioManager.play("arrow_fire")
