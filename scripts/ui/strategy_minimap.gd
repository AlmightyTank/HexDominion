extends Control
## Shares the baked terrain texture; only the camera footprint is redrawn.

var world: WorldMap
var camera: StrategyCamera
var _dragging: bool = false


func configure(map: WorldMap, view: StrategyCamera) -> void:
	world = map
	camera = view
	camera.view_changed.connect(func(_point: Vector2, _zoom: float) -> void: queue_redraw())
	resized.connect(queue_redraw)
	custom_minimum_size = Vector2(0, 142)
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	tooltip_text = "Radar: click or drag to move camera. Enter centers the map."
	queue_redraw()


func _map_rect() -> Rect2:
	var bounds: Rect2 = world.world_bounds()
	var scale_factor: float = minf(size.x / bounds.size.x, size.y / bounds.size.y)
	var extent: Vector2 = bounds.size * scale_factor
	return Rect2((size - extent) * 0.5, extent)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("080d0c"))
	if world == null or camera == null:
		return
	var rect: Rect2 = _map_rect()
	draw_texture_rect(world.get_node("CachedTerrain").texture, rect, false)
	var bounds: Rect2 = world.world_bounds()
	var transform: Transform2D = get_viewport().get_canvas_transform().affine_inverse()
	var visible_world: Rect2 = Rect2(transform * Vector2.ZERO, get_viewport_rect().size / camera.zoom)
	var footprint: Rect2 = Rect2(rect.position + (visible_world.position - bounds.position) / bounds.size * rect.size, visible_world.size / bounds.size * rect.size)
	draw_rect(footprint.intersection(rect), Color("fff0ad"), false, 2.0)
	if has_focus():
		draw_rect(Rect2(Vector2.ONE, size - Vector2.ONE * 2), Color("fff0ad"), false, 2)


func _navigate(point: Vector2) -> void:
	var rect: Rect2 = _map_rect()
	var uv: Vector2 = ((point - rect.position) / rect.size).clamp(Vector2.ZERO, Vector2.ONE)
	var target: Vector2 = world.world_bounds().position + uv * world.world_bounds().size
	camera.restore_view(target, camera.zoom)


func _gui_input(event: InputEvent) -> void:
	if camera == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
		if event.pressed:
			grab_focus()
			_navigate(event.position)
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		_navigate(event.position)
		accept_event()
	elif event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_SPACE]:
		camera.reset_view()
		accept_event()
