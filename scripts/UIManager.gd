extends CanvasLayer

const GameManagerClass = preload("res://scripts/GameManager.gd")

@onready var game_manager: Node = get_node("../GameManager")
@onready var build_manager: Node = get_node("../BuildManager")
@onready var hero: Node2D = get_node("../Hero")

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
@onready var mana_label: Label = %ManaLabel
@onready var spell_label: Label = %SpellLabel
@onready var version_label: Label = %VersionLabel

# Build buttons
@onready var wall_btn: Button = %WallButton
@onready var rock_btn: Button = %RockButton
@onready var tower_btn: Button = %TowerButton
@onready var archer_btn: Button = %ArcherButton
@onready var remove_btn: Button = %RemoveButton
@onready var upgrade_btn: Button = %UpgradeButton

var _message_timer: float = 0.0
var _build_panel_visible: bool = false

# Controller build cycling
var _build_items: Array = []
var _build_index: int = 0

func _ready() -> void:
	# Build item order for D-pad cycling
	_build_items = [
		Constants.BuildItem.WALL,
		Constants.BuildItem.ROCK,
		Constants.BuildItem.ARCHER_TOWER,
		Constants.BuildItem.GROUND_ARCHER,
		Constants.BuildItem.REMOVE,
		Constants.BuildItem.UPGRADE,
	]

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
	build_manager.item_upgraded.connect(func(_p, lvl): _show_message("Upgraded to Lv.%d!" % lvl))
	build_manager.item_selected.connect(_on_item_selected)

	# Build buttons
	wall_btn.pressed.connect(func(): build_manager.select_item(Constants.BuildItem.WALL))
	rock_btn.pressed.connect(func(): build_manager.select_item(Constants.BuildItem.ROCK))
	tower_btn.pressed.connect(func(): build_manager.select_item(Constants.BuildItem.ARCHER_TOWER))
	archer_btn.pressed.connect(func(): build_manager.select_item(Constants.BuildItem.GROUND_ARCHER))
	remove_btn.pressed.connect(func(): build_manager.select_item(Constants.BuildItem.REMOVE))
	upgrade_btn.pressed.connect(func(): build_manager.select_item(Constants.BuildItem.UPGRADE))
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

	# Connect hero signals
	hero.mana_changed.connect(_on_mana_changed)
	hero.spell_changed.connect(_on_spell_changed)

	# Set up button focus neighbors for D-pad navigation
	_setup_focus_neighbors()

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
	version_label.text = "v%s" % Constants.BUILD_VERSION
	_update_build_panel_visibility()

func _setup_focus_neighbors() -> void:
	# Build panel: vertical chain so D-pad up/down navigates naturally
	var build_buttons: Array[Button] = [wall_btn, rock_btn, tower_btn, archer_btn, remove_btn, upgrade_btn, start_wave_btn]
	for i in range(build_buttons.size()):
		var btn := build_buttons[i]
		btn.focus_mode = Control.FOCUS_ALL
		# Wrap top/bottom
		var prev_btn := build_buttons[(i - 1) % build_buttons.size()]
		var next_btn := build_buttons[(i + 1) % build_buttons.size()]
		btn.focus_neighbor_top = prev_btn.get_path()
		btn.focus_neighbor_bottom = next_btn.get_path()
		# Prevent focus from escaping left/right
		btn.focus_neighbor_left = btn.get_path()
		btn.focus_neighbor_right = btn.get_path()

	# Break panel
	var continue_btn: Button = %ContinueButton
	continue_btn.focus_mode = Control.FOCUS_ALL

	# Game over panel
	var restart_btn: Button = %RestartButton
	restart_btn.focus_mode = Control.FOCUS_ALL

	# Pause panel
	var resume_btn: Button = %ResumeButton
	var restart_pause_btn: Button = %RestartFromPauseButton
	resume_btn.focus_mode = Control.FOCUS_ALL
	restart_pause_btn.focus_mode = Control.FOCUS_ALL
	resume_btn.focus_neighbor_bottom = restart_pause_btn.get_path()
	restart_pause_btn.focus_neighbor_top = resume_btn.get_path()

	# Victory panel
	var endless_btn: Button = %EndlessButton
	var victory_restart_btn: Button = %VictoryRestartButton
	endless_btn.focus_mode = Control.FOCUS_ALL
	victory_restart_btn.focus_mode = Control.FOCUS_ALL
	endless_btn.focus_neighbor_bottom = victory_restart_btn.get_path()
	victory_restart_btn.focus_neighbor_top = endless_btn.get_path()

func _process(delta: float) -> void:
	if _message_timer > 0:
		_message_timer -= delta
		if _message_timer <= 0:
			message_label.text = ""

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		_toggle_pause()
		get_viewport().set_input_as_handled()
		return

	if get_tree().paused:
		return

	if event.is_action_pressed("toggle_build"):
		_build_panel_visible = not _build_panel_visible
		_update_build_panel_visibility()
		if _build_panel_visible and build_panel.visible:
			_grab_build_focus()
		get_viewport().set_input_as_handled()
		return

	# D-pad build cycling (only during PLANNING with build panel open)
	if _build_panel_visible and build_panel.visible:
		if event.is_action_pressed("build_next"):
			_build_index = (_build_index + 1) % _build_items.size()
			build_manager.select_item(_build_items[_build_index])
			_focus_build_button(_build_index)
			get_viewport().set_input_as_handled()
			return
		if event.is_action_pressed("build_prev"):
			_build_index = (_build_index - 1 + _build_items.size()) % _build_items.size()
			build_manager.select_item(_build_items[_build_index])
			_focus_build_button(_build_index)
			get_viewport().set_input_as_handled()
			return

func _grab_build_focus() -> void:
	# Focus the currently selected build button (or first one)
	_focus_build_button(_build_index)

func _focus_build_button(index: int) -> void:
	var buttons: Array[Button] = [wall_btn, rock_btn, tower_btn, archer_btn, remove_btn, upgrade_btn]
	if index >= 0 and index < buttons.size():
		buttons[index].grab_focus()

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
		GameManagerClass.Phase.PLANNING:
			phase_label.text = "PLANNING PHASE"
			phase_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
			build_panel.visible = true
			_build_panel_visible = true
			break_panel.visible = false
			game_over_panel.visible = false
			victory_panel.visible = false
			start_wave_btn.visible = true
			timer_label.visible = true
			# Auto-focus build panel for controller
			call_deferred("_grab_build_focus")
		GameManagerClass.Phase.WAVE:
			phase_label.text = "WAVE IN PROGRESS"
			phase_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
			build_panel.visible = false
			_build_panel_visible = false
			start_wave_btn.visible = false
			timer_label.visible = false
			# Release focus so controller inputs go to gameplay
			_release_ui_focus()
		GameManagerClass.Phase.BREAK:
			phase_label.text = "WAVE COMPLETE!"
			phase_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.2))
			build_panel.visible = false
			_build_panel_visible = false
			break_panel.visible = true
			break_wave_label.text = "Wave %d Cleared!" % game_manager.current_wave
			break_gold_label.text = "Gold: %d" % game_manager.gold
			break_hp_label.text = "Base HP: %d/%d" % [game_manager.base_hp, Constants.BASE_MAX_HP]
			# Focus continue button for controller
			call_deferred("_focus_break_panel")
		GameManagerClass.Phase.GAME_OVER:
			phase_label.text = "DEFEAT"
			phase_label.add_theme_color_override("font_color", Color(0.7, 0.1, 0.1))
			build_panel.visible = false
			break_panel.visible = false
			game_over_panel.visible = true
			victory_panel.visible = false
			wave_reached_label.text = "Survived to Wave %d" % game_manager.current_wave
			# Focus restart button for controller
			call_deferred("_focus_game_over_panel")
		GameManagerClass.Phase.VICTORY:
			phase_label.text = "VICTORY!"
			phase_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
			build_panel.visible = false
			break_panel.visible = false
			game_over_panel.visible = false
			victory_panel.visible = true
			%VictoryWaveLabel.text = "All %d Waves Cleared!" % Constants.FINAL_WAVE
			%VictoryGoldLabel.text = "Final Gold: %d" % game_manager.gold
			%VictoryHPLabel.text = "Base HP: %d/%d" % [game_manager.base_hp, Constants.BASE_MAX_HP]
			# Focus endless button for controller
			call_deferred("_focus_victory_panel")

func _focus_break_panel() -> void:
	%ContinueButton.grab_focus()

func _focus_game_over_panel() -> void:
	%RestartButton.grab_focus()

func _focus_victory_panel() -> void:
	%EndlessButton.grab_focus()

func _release_ui_focus() -> void:
	# Remove focus from any UI button so controller goes back to gameplay
	var focused := get_viewport().gui_get_focus_owner()
	if focused:
		focused.release_focus()

func _on_item_selected(item: int) -> void:
	# Highlight selected button
	wall_btn.modulate = Color.WHITE
	rock_btn.modulate = Color.WHITE
	tower_btn.modulate = Color.WHITE
	archer_btn.modulate = Color.WHITE
	remove_btn.modulate = Color.WHITE
	upgrade_btn.modulate = Color.WHITE
	match item:
		Constants.BuildItem.WALL:
			wall_btn.modulate = Color.YELLOW
			_build_index = 0
		Constants.BuildItem.ROCK:
			rock_btn.modulate = Color.YELLOW
			_build_index = 1
		Constants.BuildItem.ARCHER_TOWER:
			tower_btn.modulate = Color.YELLOW
			_build_index = 2
		Constants.BuildItem.GROUND_ARCHER:
			archer_btn.modulate = Color.YELLOW
			_build_index = 3
		Constants.BuildItem.REMOVE:
			remove_btn.modulate = Color(1, 0.5, 0.5)
			_build_index = 4
		Constants.BuildItem.UPGRADE:
			upgrade_btn.modulate = Color(0.5, 1, 0.5)
			_build_index = 5

func _update_button_affordability() -> void:
	var g: int = game_manager.gold
	wall_btn.disabled = g < Constants.BUILD_DATA[Constants.BuildItem.WALL]["cost"]
	rock_btn.disabled = g < Constants.BUILD_DATA[Constants.BuildItem.ROCK]["cost"]
	tower_btn.disabled = g < Constants.BUILD_DATA[Constants.BuildItem.ARCHER_TOWER]["cost"]
	archer_btn.disabled = g < Constants.BUILD_DATA[Constants.BuildItem.GROUND_ARCHER]["cost"]

func _update_build_panel_visibility() -> void:
	if game_manager.current_phase == GameManagerClass.Phase.PLANNING:
		build_panel.visible = _build_panel_visible
	else:
		build_panel.visible = false

func _toggle_pause() -> void:
	if game_manager.current_phase == GameManagerClass.Phase.GAME_OVER:
		return
	if game_manager.current_phase == GameManagerClass.Phase.VICTORY:
		return
	var is_paused := not get_tree().paused
	get_tree().paused = is_paused
	pause_panel.visible = is_paused
	if is_paused:
		call_deferred("_focus_pause_panel")
	else:
		# Return focus to build panel if in planning
		if _build_panel_visible and build_panel.visible:
			call_deferred("_grab_build_focus")
		else:
			_release_ui_focus()

func _focus_pause_panel() -> void:
	%ResumeButton.grab_focus()

func _unpause_and_restart() -> void:
	get_tree().paused = false
	pause_panel.visible = false
	game_manager.restart_game()

func _on_mana_changed(current: int, maximum: int) -> void:
	mana_label.text = "Mana: %d/%d" % [current, maximum]

func _on_spell_changed(spell_name: String) -> void:
	spell_label.text = "Spell: %s [Q/E]" % spell_name

func _show_message(msg: String) -> void:
	message_label.text = msg
	_message_timer = 2.0
