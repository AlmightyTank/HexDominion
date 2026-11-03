extends Node2D
## Slice B: inspect an Earth-inspired, deterministic hex world.
## Tap/select is informational until troop commands are added in Slice C.

@onready var camera: StrategyCamera = $Camera2D
@onready var hud: StrategyHUD = $HUD/Overlay
@onready var world_map: WorldMap = $WorldMap

var _mouse_press: Vector2 = Vector2.ZERO
var _touch_start: Dictionary = {}
const TAP_THRESHOLD: float = 14.0


func _ready() -> void:
	hud.bind_camera(camera)
	camera.configure_world_bounds(world_map.world_bounds())
	hud.show_world_stats(world_map.map_data)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_mouse_press = event.position
		elif event.position.distance_to(_mouse_press) < TAP_THRESHOLD:
			_inspect_world_at(get_global_mouse_position())
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_start[event.index] = event.position
		else:
			var start: Vector2 = _touch_start.get(event.index, Vector2(-10000.0, -10000.0))
			_touch_start.erase(event.index)
			if _touch_start.is_empty() and event.position.distance_to(start) < TAP_THRESHOLD:
				var world_point: Vector2 = get_viewport().get_canvas_transform().affine_inverse() * event.position
				_inspect_world_at(world_point)


func _inspect_world_at(world_point: Vector2) -> void:
	hud.show_tile_info(world_map.inspect_at_world(world_point))
