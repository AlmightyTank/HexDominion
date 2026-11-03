extends Node2D
## Slice C: selection and land movement orders, independent of camera dragging.

@onready var camera: StrategyCamera = $Camera2D
@onready var hud: StrategyHUD = $HUD/Overlay
@onready var world_map: WorldMap = $WorldMap

var _mouse_press: Vector2 = Vector2.ZERO
var _touch_start: Dictionary = {}
var _mouse_max_travel: float = 0.0
var _right_press: Vector2 = Vector2.ZERO
var _right_max_travel: float = 0.0
var _touch_gesture: bool = false
var units: UnitLayer
const TAP_THRESHOLD: float = 14.0


func _ready() -> void:
	hud.bind_camera(camera)
	camera.configure_world_bounds(world_map.world_bounds())
	hud.show_world_stats(world_map.map_data)
	units = UnitLayer.new()
	units.name = "Units"
	add_child(units)
	units.configure(world_map)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		if units.selected != null:
			if units.selected.path.is_empty() and units.territory.owner_at(units.selected.hex) == units.selected.faction:
				units.selected.garrisoned = not units.selected.garrisoned
				hud.show_command_info("Garrison %s • G toggles • Garrisoned squads cannot move" % ("assigned" if units.selected.garrisoned else "released"))
			else:
				hud.show_command_info("Garrison requires a stationary squad on owned territory")
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_press = event.position
			_mouse_max_travel = 0.0
		elif maxf(_mouse_max_travel, event.position.distance_to(_mouse_press)) < TAP_THRESHOLD:
			_select_at(get_global_mouse_position())
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_right_press = event.position
			_right_max_travel = 0.0
		elif maxf(_right_max_travel, event.position.distance_to(_right_press)) < TAP_THRESHOLD:
			_move_to(get_global_mouse_position())
	elif event is InputEventMouseMotion:
		_mouse_max_travel = maxf(_mouse_max_travel, event.position.distance_to(_mouse_press))
		_right_max_travel = maxf(_right_max_travel, event.position.distance_to(_right_press))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		units.selected = null
		units.queue_redraw()
		hud.show_command_info("Selection cleared")
	elif event is InputEventScreenDrag:
		if event.position.distance_to(_touch_start.get(event.index, event.position)) >= TAP_THRESHOLD:
			_touch_gesture = true
	elif event is InputEventScreenTouch:
		if event.pressed:
			if _touch_start.is_empty():
				_touch_gesture = false
			_touch_start[event.index] = event.position
			if _touch_start.size() > 1:
				_touch_gesture = true
		else:
			var start: Vector2 = _touch_start.get(event.index, Vector2(-10000.0, -10000.0))
			_touch_start.erase(event.index)
			if not _touch_gesture and _touch_start.is_empty() and event.position.distance_to(start) < TAP_THRESHOLD:
				var world_point: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
				if units.pick(world_point, camera.zoom.x) != null or units.selected == null:
					_select_at(world_point)
				else:
					_move_to(world_point)


func _inspect_world_at(world_point: Vector2) -> void:
	hud.show_tile_info(world_map.inspect_at_world(world_point))
	var owner: int = units.territory.owner_at(world_map.world_to_hex(world_point))
	hud.show_command_info("Owner: %s • Stationary squads capture in 3s • G garrison" % ("Neutral" if owner == 0 else ("Player" if owner == 1 else "Rival")))


func _select_at(point: Vector2) -> void:
	units.selected = units.pick(point, camera.zoom.x)
	units.queue_redraw()
	_inspect_world_at(point)
	if units.selected != null:
		hud.show_command_info("%s • %s • Right-click move • G garrison" % [units.selected.title, "Garrisoned" if units.selected.garrisoned else "Mobile"])


func _move_to(point: Vector2) -> void:
	if units.selected == null:
		hud.show_command_info("Select a squad first (teal markers)")
		return
	var accepted: bool = units.selected.order_move(world_map.map_data["tiles"], world_map.world_to_hex(point))
	units.queue_redraw()
	if accepted:
		hud.show_command_info("%s • Order accepted • %d hex steps" % [units.selected.title, units.selected.path.size()])
	else:
		hud.show_command_info("Garrisoned or no land route • Release with G • Previous order unchanged")
