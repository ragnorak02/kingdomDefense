extends Camera2D

const ZOOM_MIN := 0.4
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1
const ZOOM_PRESETS := [1.2, 0.7, 0.4]  # close, medium, far

var _dragging := false
var _zoom_preset_index := 1  # start at medium (0.7)

func _ready() -> void:
	# Center on the castle (middle of its 2×2 footprint)
	var layout = Constants.get_default_map_layout()
	var cp: Vector2i = layout["castle_pos"]
	var p0 = Constants.grid_to_world(cp.x, cp.y)
	var p1 = Constants.grid_to_world(cp.x + 1, cp.y + 1)
	position = (p0 + p1) * 0.5
	zoom = Vector2(0.7, 0.7)
	make_current()

func _unhandled_input(event: InputEvent) -> void:
	# RT zoom cycle
	if event.is_action_pressed("zoom_cycle"):
		_cycle_zoom()
		return

	# Mouse wheel zoom
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at_point(ZOOM_STEP, get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at_point(-ZOOM_STEP, get_global_mouse_position())
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging = event.pressed

	# Middle mouse drag to pan
	if event is InputEventMouseMotion and _dragging:
		position -= event.relative / zoom

	# Home key to reset camera
	if event is InputEventKey and event.pressed and event.keycode == KEY_HOME:
		var layout = Constants.get_default_map_layout()
		var cp: Vector2i = layout["castle_pos"]
		var p0 = Constants.grid_to_world(cp.x, cp.y)
		var p1 = Constants.grid_to_world(cp.x + 1, cp.y + 1)
		position = (p0 + p1) * 0.5
		zoom = Vector2(0.7, 0.7)

func _cycle_zoom() -> void:
	_zoom_preset_index = (_zoom_preset_index + 1) % ZOOM_PRESETS.size()
	var z: float = ZOOM_PRESETS[_zoom_preset_index]
	zoom = Vector2(z, z)
	AudioManager.play("select")

func _zoom_at_point(step: float, mouse_world: Vector2) -> void:
	var old_zoom := zoom.x
	var new_zoom := clampf(zoom.x + step, ZOOM_MIN, ZOOM_MAX)
	if new_zoom == old_zoom:
		return

	# Zoom toward mouse position
	var mouse_offset := mouse_world - position
	position += mouse_offset * (1.0 - old_zoom / new_zoom)
	zoom = Vector2(new_zoom, new_zoom)
