extends Node

enum Phase { PLANNING, WAVE, BREAK, GAME_OVER, VICTORY }

var current_phase: Phase = Phase.PLANNING
var current_wave: int = 0
var gold: int = Constants.STARTING_GOLD
var base_hp: int = Constants.BASE_MAX_HP
var plan_timer: float = Constants.PLAN_PHASE_DURATION
var enemies_remaining: int = 0
var _gold_accumulator: float = 0.0

signal phase_changed(new_phase: Phase)
signal gold_changed(amount: int)
signal base_hp_changed(hp: int)
signal wave_changed(wave: int)
signal enemies_remaining_changed(count: int)
signal plan_timer_updated(time_left: float)

@onready var grid_manager: Node2D = get_node("../GridManager")
@onready var enemy_manager: Node = get_node("../EnemyManager")
@onready var build_manager: Node = get_node("../BuildManager")

func _ready() -> void:
	start_planning_phase()

func _process(delta: float) -> void:
	if current_phase == Phase.PLANNING:
		# Gold income (accumulate fractional gold)
		_gold_accumulator += Constants.GOLD_PER_SECOND * delta
		if _gold_accumulator >= 1.0:
			var earned := int(_gold_accumulator)
			gold += earned
			_gold_accumulator -= earned
			gold_changed.emit(gold)
		# Timer
		plan_timer -= delta
		plan_timer_updated.emit(plan_timer)
		if plan_timer <= 0:
			start_wave()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("start_wave") and current_phase == Phase.PLANNING:
		start_wave_early()

func start_planning_phase() -> void:
	current_phase = Phase.PLANNING
	plan_timer = Constants.PLAN_PHASE_DURATION
	_gold_accumulator = 0.0
	if Constants.DEBUG_PHASES:
		print("[Phase] PLANNING started — wave %d complete" % current_wave)
	phase_changed.emit(current_phase)

func start_wave_early() -> void:
	var bonus := int(plan_timer * Constants.EARLY_START_BONUS_PER_SECOND)
	if bonus > 0:
		gold += bonus
		gold_changed.emit(gold)
	start_wave()

func start_wave() -> void:
	current_phase = Phase.WAVE
	current_wave += 1
	if Constants.DEBUG_PHASES:
		print("[Phase] WAVE %d started — gold: %d, base HP: %d" % [current_wave, gold, base_hp])
	wave_changed.emit(current_wave)
	phase_changed.emit(current_phase)
	AudioManager.play("wave_start")

	var config: Dictionary = Constants.get_wave_config(current_wave)
	enemies_remaining = config["count"]
	enemies_remaining_changed.emit(enemies_remaining)
	enemy_manager.start_wave(current_wave, config["count"])

func on_enemy_killed(gold_mult: float = 1.0) -> void:
	enemies_remaining -= 1
	enemies_remaining_changed.emit(enemies_remaining)
	# Gold reward per kill (scaled by enemy type)
	gold += int((5 + current_wave * 2) * gold_mult)
	gold_changed.emit(gold)
	AudioManager.play("gold_earned")
	if enemies_remaining <= 0 and enemy_manager.all_spawned:
		_wave_complete()

func on_enemy_reached_goal(damage: int = 1) -> void:
	base_hp -= damage
	base_hp_changed.emit(base_hp)
	enemies_remaining -= 1
	enemies_remaining_changed.emit(enemies_remaining)
	if base_hp <= 0:
		_game_over()
	elif enemies_remaining <= 0 and enemy_manager.all_spawned:
		_wave_complete()

func _wave_complete() -> void:
	# Wave completion gold bonus
	gold += 50 + current_wave * 20
	gold_changed.emit(gold)
	if Constants.DEBUG_PHASES:
		print("[Phase] Wave %d complete — gold: %d, base HP: %d" % [current_wave, gold, base_hp])

	if current_wave >= Constants.FINAL_WAVE:
		current_phase = Phase.VICTORY
		AudioManager.play("victory")
	else:
		current_phase = Phase.BREAK
		AudioManager.play("wave_complete")
	phase_changed.emit(current_phase)

func _game_over() -> void:
	current_phase = Phase.GAME_OVER
	if Constants.DEBUG_PHASES:
		print("[Phase] GAME_OVER — wave %d, base HP: %d" % [current_wave, base_hp])
	AudioManager.play("game_over")
	phase_changed.emit(current_phase)

func continue_from_break() -> void:
	start_planning_phase()

func continue_endless() -> void:
	# Continue playing beyond the final wave
	start_planning_phase()

func restart_game() -> void:
	gold = Constants.STARTING_GOLD
	base_hp = Constants.BASE_MAX_HP
	current_wave = 0
	enemies_remaining = 0
	gold_changed.emit(gold)
	base_hp_changed.emit(base_hp)
	wave_changed.emit(current_wave)
	enemies_remaining_changed.emit(enemies_remaining)
	# Clear enemies first (before structures, to avoid unnecessary repath signals)
	enemy_manager.clear_all()
	build_manager.clear_all()
	start_planning_phase()

func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false

func refund_gold(amount: int) -> void:
	gold += amount
	gold_changed.emit(gold)
