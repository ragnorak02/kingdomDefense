extends Camera2D

const ZOOM_MIN := 0.5
const ZOOM_MAX := 2.0
const ZOOM_STEP := 0.1

var _dragging := false

func _ready() -> void:
	# Center on grid
	var grid_center := Constants.grid_to_world(Constants.GRID_WIDTH / 2, Constants.GRID_HEIGHT / 2)
	position = grid_center
	zoom = Vector2(1, 1)
	make_current()

func _unhandled_input(event: InputEvent) -> void:
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
		var grid_center := Constants.grid_to_world(Constants.GRID_WIDTH / 2, Constants.GRID_HEIGHT / 2)
		position = grid_center
		zoom = Vector2(1, 1)

func _zoom_at_point(step: float, mouse_world: Vector2) -> void:
	var old_zoom := zoom.x
	var new_zoom := clampf(zoom.x + step, ZOOM_MIN, ZOOM_MAX)
	if new_zoom == old_zoom:
		return

	# Zoom toward mouse position
	var mouse_offset := mouse_world - position
	position += mouse_offset * (1.0 - old_zoom / new_zoom)
	zoom = Vector2(new_zoom, new_zoom)
