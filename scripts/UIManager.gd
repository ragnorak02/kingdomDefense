extends CanvasLayer

@onready var game_manager: Node = get_node("../GameManager")
@onready var build_manager: Node = get_node("../BuildManager")

# HUD elements
@onready var gold_label: Label = %GoldLabel
@onready var wave_label: Label = %WaveLabel
@onready var timer_label: Label = %TimerLabel
@onready var enemies_label: Label = %EnemiesLabel
@onready var base_hp_label: Label = %BaseHPLabel
@onready var phase_label: Label = %PhaseLabel
@onready var message_label: Label = %MessageLabel

# Panels
@onready var build_panel: PanelContainer = %BuildPanel
@onready var break_panel: PanelContainer = %BreakPanel
@onready var game_over_panel: PanelContainer = %GameOverPanel
@onready var pause_panel: PanelContainer = %PausePanel
@onready var victory_panel: PanelContainer = %VictoryPanel
@onready var start_wave_btn: Button = %StartWaveButton
@onready var wave_reached_label: Label = %WaveReachedLabel
@onready var break_wave_label: Label = %BreakWaveLabel
@onready var break_gold_label: Label = %BreakGoldLabel
@onready var break_hp_label: Label = %BreakHPLabel

# Build buttons
@onready var wall_btn: Button = %WallButton
@onready var rock_btn: Button = %RockButton
@onready var tower_btn: Button = %TowerButton
@onready var archer_btn: Button = %ArcherButton
@onready var remove_btn: Button = %RemoveButton

var _message_timer: float = 0.0
var _build_panel_visible: bool = false

func _ready() -> void:
	# Connect signals
	game_manager.gold_changed.connect(_on_gold_changed)
	game_manager.base_hp_changed.connect(_on_base_hp_changed)
	game_manager.wave_changed.connect(_on_wave_changed)
	game_manager.enemies_remaining_changed.connect(_on_enemies_changed)
	game_manager.plan_timer_updated.connect(_on_timer_updated)
	game_manager.phase_changed.connect(_on_phase_changed)
	build_manager.placement_failed.connect(_show_message)
	build_manager.item_placed.connect(func(_i, _p): _show_message("Placed!"))
	build_manager.item_removed.connect(func(_p): _show_message("Removed (gold refunded)"))
	build_manager.item_selected.connect(_on_item_selected)

	# Build buttons
	wall_btn.pressed.connect(func(): build_manager.select_item(Constants.BuildItem.WALL))
	rock_btn.pressed.connect(func(): build_manager.select_item(Constants.BuildItem.ROCK))
	tower_btn.pressed.connect(func(): build_manager.select_item(Constants.BuildItem.ARCHER_TOWER))
	archer_btn.pressed.connect(func(): build_manager.select_item(Constants.BuildItem.GROUND_ARCHER))
	remove_btn.pressed.connect(func(): build_manager.select_item(Constants.BuildItem.REMOVE))
	start_wave_btn.pressed.connect(func(): game_manager.start_wave_early())

	# Break panel buttons
	%ContinueButton.pressed.connect(func(): game_manager.continue_from_break())
	%RestartButton.pressed.connect(func(): game_manager.restart_game())

	# Pause panel buttons
	%ResumeButton.pressed.connect(_toggle_pause)
	%RestartFromPauseButton.pressed.connect(_unpause_and_restart)

	# Victory panel buttons
	%EndlessButton.pressed.connect(func(): game_manager.continue_endless())
	%VictoryRestartButton.pressed.connect(func(): game_manager.restart_game())

	# Init display
	_on_gold_changed(game_manager.gold)
	_on_base_hp_changed(game_manager.base_hp)
	_on_wave_changed(0)
	_on_enemies_changed(0)
	break_panel.visible = false
	game_over_panel.visible = false
	pause_panel.visible = false
	victory_panel.visible = false
	message_label.text = ""
	_update_build_panel_visibility()

func _process(delta: float) -> void:
	if _message_timer > 0:
		_message_timer -= delta
		if _message_timer <= 0:
			message_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		_toggle_pause()
	if event.is_action_pressed("toggle_build") and not get_tree().paused:
		_build_panel_visible = not _build_panel_visible
		_update_build_panel_visibility()

func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Gold: %d" % amount
	_update_button_affordability()

func _on_base_hp_changed(hp: int) -> void:
	base_hp_label.text = "Base: %d/%d" % [hp, Constants.BASE_MAX_HP]

func _on_wave_changed(wave: int) -> void:
	wave_label.text = "Wave: %d/%d" % [wave, Constants.FINAL_WAVE] if wave > 0 else "Wave: --"

func _on_enemies_changed(count: int) -> void:
	enemies_label.text = "Enemies: %d" % count

func _on_timer_updated(time_left: float) -> void:
	timer_label.text = "Plan: %ds" % ceili(time_left)

func _on_phase_changed(phase: int) -> void:
	match phase:
		GameManager.Phase.PLANNING:
			phase_label.text = "PLANNING PHASE"
			phase_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
			build_panel.visible = true
			_build_panel_visible = true
			break_panel.visible = false
			game_over_panel.visible = false
			victory_panel.visible = false
			start_wave_btn.visible = true
			timer_label.visible = true
		GameManager.Phase.WAVE:
			phase_label.text = "WAVE IN PROGRESS"
			phase_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			build_panel.visible = false
			_build_panel_visible = false
			start_wave_btn.visible = false
			timer_label.visible = false
		GameManager.Phase.BREAK:
			phase_label.text = "WAVE COMPLETE!"
			phase_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
			build_panel.visible = false
			_build_panel_visible = false
			break_panel.visible = true
			break_wave_label.text = "Wave %d Cleared!" % game_manager.current_wave
			break_gold_label.text = "Gold: %d" % game_manager.gold
			break_hp_label.text = "Base HP: %d/%d" % [game_manager.base_hp, Constants.BASE_MAX_HP]
		GameManager.Phase.GAME_OVER:
			phase_label.text = "DEFEAT"
			phase_label.add_theme_color_override("font_color", Color(0.7, 0.1, 0.1))
			build_panel.visible = false
			break_panel.visible = false
			game_over_panel.visible = true
			victory_panel.visible = false
			wave_reached_label.text = "Survived to Wave %d" % game_manager.current_wave
		GameManager.Phase.VICTORY:
			phase_label.text = "VICTORY!"
			phase_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			build_panel.visible = false
			break_panel.visible = false
			game_over_panel.visible = false
			victory_panel.visible = true
			%VictoryWaveLabel.text = "All %d Waves Cleared!" % Constants.FINAL_WAVE
			%VictoryGoldLabel.text = "Final Gold: %d" % game_manager.gold
			%VictoryHPLabel.text = "Base HP: %d/%d" % [game_manager.base_hp, Constants.BASE_MAX_HP]

func _on_item_selected(item: int) -> void:
	# Highlight selected button
	wall_btn.modulate = Color.WHITE
	rock_btn.modulate = Color.WHITE
	tower_btn.modulate = Color.WHITE
	archer_btn.modulate = Color.WHITE
	remove_btn.modulate = Color.WHITE
	match item:
		Constants.BuildItem.WALL: wall_btn.modulate = Color.YELLOW
		Constants.BuildItem.ROCK: rock_btn.modulate = Color.YELLOW
		Constants.BuildItem.ARCHER_TOWER: tower_btn.modulate = Color.YELLOW
		Constants.BuildItem.GROUND_ARCHER: archer_btn.modulate = Color.YELLOW
		Constants.BuildItem.REMOVE: remove_btn.modulate = Color(1, 0.5, 0.5)

func _update_button_affordability() -> void:
	var g := game_manager.gold
	wall_btn.disabled = g < Constants.BUILD_DATA[Constants.BuildItem.WALL]["cost"]
	rock_btn.disabled = g < Constants.BUILD_DATA[Constants.BuildItem.ROCK]["cost"]
	tower_btn.disabled = g < Constants.BUILD_DATA[Constants.BuildItem.ARCHER_TOWER]["cost"]
	archer_btn.disabled = g < Constants.BUILD_DATA[Constants.BuildItem.GROUND_ARCHER]["cost"]

func _update_build_panel_visibility() -> void:
	if game_manager.current_phase == GameManager.Phase.PLANNING:
		build_panel.visible = _build_panel_visible
	else:
		build_panel.visible = false

func _toggle_pause() -> void:
	if game_manager.current_phase == GameManager.Phase.GAME_OVER:
		return
	if game_manager.current_phase == GameManager.Phase.VICTORY:
		return
	var is_paused := not get_tree().paused
	get_tree().paused = is_paused
	pause_panel.visible = is_paused

func _unpause_and_restart() -> void:
	get_tree().paused = false
	pause_panel.visible = false
	game_manager.restart_game()

func _show_message(msg: String) -> void:
	message_label.text = msg
	_message_timer = 2.0
