extends Camera2D
class_name StrategyCamera
## RTS-style camera, independent from world tiles and game state.
## Desktop: WASD/arrows, left/middle/right drag, wheel zoom, R to reset.
## Slice B adds fit-to-world and world-bound camera clamping.
## Touch: one-finger drag and two-finger pinch + pan.

signal view_changed(world_position: Vector2, zoom_factor: float)

@export_range(0.05, 2.5, 0.01) var min_zoom: float = 0.08
@export_range(0.05, 2.5, 0.05) var max_zoom: float = 2.3
@export_range(100.0, 2500.0, 50.0) var keyboard_pan_speed: float = 850.0
@export_range(1.05, 1.5, 0.01) var zoom_step: float = 1.14

const START_ZOOM: float = 0.72
var _world_bounds: Rect2 = Rect2()
var _has_world_bounds: bool = false

var _mouse_drag_buttons: Dictionary = {}
var _touch_positions: Dictionary = {}
var _pinch_distance: float = 0.0
var _pinch_midpoint: Vector2 = Vector2.ZERO


func _ready() -> void:
	make_current()
	reset_view()


func _process(delta: float) -> void:
	var movement: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("ui_left") or Input.is_key_pressed(KEY_A):
		movement.x -= 1.0
	if Input.is_action_pressed("ui_right") or Input.is_key_pressed(KEY_D):
		movement.x += 1.0
	if Input.is_action_pressed("ui_up") or Input.is_key_pressed(KEY_W):
		movement.y -= 1.0
	if Input.is_action_pressed("ui_down") or Input.is_key_pressed(KEY_S):
		movement.y += 1.0
	if movement != Vector2.ZERO:
		position += movement.normalized() * keyboard_pan_speed * delta / zoom.x
		_clamp_position()
		_notify_view_changed()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		_handle_mouse_button(event)
	elif event is InputEventMouseMotion:
		if not _mouse_drag_buttons.is_empty():
			pan_screen_pixels(event.relative)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			reset_view()


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_at_screen_point(event.position, zoom_step)
	elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_at_screen_point(event.position, 1.0 / zoom_step)
	elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT]:
		if event.pressed:
			_mouse_drag_buttons[event.button_index] = true
		else:
			_mouse_drag_buttons.erase(event.button_index)


func _handle_screen_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		_touch_positions[event.index] = event.position
	else:
		_touch_positions.erase(event.index)
	_reset_pinch_reference()


func _handle_screen_drag(event: InputEventScreenDrag) -> void:
	_touch_positions[event.index] = event.position
	if _touch_positions.size() == 1:
		pan_screen_pixels(event.relative)
		return
	if _touch_positions.size() != 2:
		return

	var positions: Array = _touch_positions.values()
	var position_a: Vector2 = positions[0]
	var position_b: Vector2 = positions[1]
	var new_distance: float = position_a.distance_to(position_b)
	var new_midpoint: Vector2 = (position_a + position_b) * 0.5

	# The second finger's most recent position is stored, so gesture changes
	# are incremental rather than repeatedly applying the entire pinch ratio.
	if _pinch_distance > 1.0 and new_distance > 1.0:
		zoom_at_screen_point(new_midpoint, new_distance / _pinch_distance)
		pan_screen_pixels(new_midpoint - _pinch_midpoint)
	_pinch_distance = new_distance
	_pinch_midpoint = new_midpoint


func _reset_pinch_reference() -> void:
	_pinch_distance = 0.0
	_pinch_midpoint = Vector2.ZERO
	if _touch_positions.size() == 2:
		var positions: Array = _touch_positions.values()
		var position_a: Vector2 = positions[0]
		var position_b: Vector2 = positions[1]
		_pinch_distance = position_a.distance_to(position_b)
		_pinch_midpoint = (position_a + position_b) * 0.5


func pan_screen_pixels(delta_pixels: Vector2) -> void:
	position -= delta_pixels / zoom.x
	_clamp_position()
	_notify_view_changed()


func zoom_at_screen_point(screen_point: Vector2, multiplier: float) -> void:
	# Keep the world location under the cursor/finger stationary when zooming.
	var next_zoom: float = clampf(zoom.x * multiplier, min_zoom, max_zoom)
	if is_equal_approx(next_zoom, zoom.x):
		return
	var offset_pixels: Vector2 = screen_point - get_viewport_rect().size * 0.5
	var point_before: Vector2 = position + offset_pixels / zoom.x
	zoom = Vector2.ONE * next_zoom
	position = point_before - offset_pixels / next_zoom
	_clamp_position()
	_notify_view_changed()


func zoom_centered(multiplier: float) -> void:
	zoom_at_screen_point(get_viewport_rect().size * 0.5, multiplier)


func configure_world_bounds(bounds: Rect2) -> void:
	_world_bounds = bounds
	_has_world_bounds = bounds.size.x > 0.0 and bounds.size.y > 0.0
	reset_view()


func reset_view() -> void:
	position = _world_bounds.get_center() if _has_world_bounds else Vector2.ZERO
	var fit_zoom: float = START_ZOOM
	if _has_world_bounds:
		var viewport_size: Vector2 = get_viewport_rect().size
		fit_zoom = minf(viewport_size.x / _world_bounds.size.x, viewport_size.y / _world_bounds.size.y) * 0.91
	zoom = Vector2.ONE * clampf(fit_zoom, min_zoom, max_zoom)
	_mouse_drag_buttons.clear()
	_clamp_position()
	_notify_view_changed()


func _clamp_position() -> void:
	if not _has_world_bounds:
		return
	var half_visible: Vector2 = get_viewport_rect().size / (2.0 * zoom.x)
	if half_visible.x * 2.0 >= _world_bounds.size.x:
		position.x = _world_bounds.get_center().x
	else:
		position.x = clampf(position.x, _world_bounds.position.x + half_visible.x, _world_bounds.end.x - half_visible.x)
	if half_visible.y * 2.0 >= _world_bounds.size.y:
		position.y = _world_bounds.get_center().y
	else:
		position.y = clampf(position.y, _world_bounds.position.y + half_visible.y, _world_bounds.end.y - half_visible.y)


func _notify_view_changed() -> void:
	view_changed.emit(position, zoom.x)
