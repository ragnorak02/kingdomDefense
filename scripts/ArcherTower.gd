extends Node2D

var _fire_timer: float = 0.0
var _target: Node2D = null
var _stats: Dictionary
var _sprite: Sprite2D
var level: int = 1

@onready var enemy_manager: Node = get_node("../../EnemyManager")
@onready var projectile_container: Node2D = get_node("../../Projectiles")

func _ready() -> void:
	_stats = Constants.ARCHER_TOWER_STATS.duplicate()

	_sprite = Sprite2D.new()
	_sprite.texture = load("res://assets/archer_tower.png")
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.offset = Vector2(0, -24)
	add_child(_sprite)

func upgrade() -> void:
	if level >= Constants.MAX_UPGRADE_LEVEL:
		return
	level += 1
	_apply_level_stats()
	AudioManager.play("build_place")

func _apply_level_stats() -> void:
	var base := Constants.ARCHER_TOWER_STATS
	var li := level - 1
	_stats = {
		"range": base["range"] * Constants.UPGRADE_RANGE_MULT[li],
		"fire_rate": base["fire_rate"] * Constants.UPGRADE_RATE_MULT[li],
		"damage": int(base["damage"] * Constants.UPGRADE_DAMAGE_MULT[li]),
		"projectile_speed": base["projectile_speed"],
	}
	# Visual feedback
	match level:
		2: _sprite.modulate = Color(0.8, 1.0, 1.3)
		3: _sprite.modulate = Color(1.3, 1.1, 0.7)
	queue_redraw()

func _process(delta: float) -> void:
	_fire_timer -= delta

	_target = _find_closest_enemy()
	if _target and _fire_timer <= 0:
		_fire()
		_fire_timer = 1.0 / _stats["fire_rate"]

	if level > 1:
		queue_redraw()

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

func _draw() -> void:
	# Draw upgrade stars
	if level >= 2:
		var star_y := -46.0
		for i in range(level - 1):
			var sx := -3.0 + i * 7.0
			draw_circle(Vector2(sx, star_y), 2.5, Color(1, 0.9, 0.3))
