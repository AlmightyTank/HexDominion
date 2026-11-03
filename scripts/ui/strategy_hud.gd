extends Control
class_name StrategyHUD
## Camera test HUD. No army or economy features are implied for Slice A.

@onready var coordinates_label: Label = $Header/Margin/Content/Coordinates
@onready var zoom_label: Label = $Controls/Margin/Buttons/ZoomLabel
@onready var zoom_in_button: Button = $Controls/Margin/Buttons/ZoomIn
@onready var zoom_out_button: Button = $Controls/Margin/Buttons/ZoomOut
@onready var home_button: Button = $Controls/Margin/Buttons/Reset

var _camera: StrategyCamera


func _ready() -> void:
	zoom_in_button.pressed.connect(_on_zoom_in)
	zoom_out_button.pressed.connect(_on_zoom_out)
	home_button.pressed.connect(_on_reset)


func bind_camera(strategy_camera: StrategyCamera) -> void:
	_camera = strategy_camera
	_camera.view_changed.connect(_on_view_changed)
	_on_view_changed(_camera.position, _camera.zoom.x)


func _on_view_changed(world_position: Vector2, zoom_factor: float) -> void:
	coordinates_label.text = "CAM  %d , %d" % [roundi(world_position.x), roundi(world_position.y)]
	zoom_label.text = "%d%%" % roundi(zoom_factor * 100.0)


func _on_zoom_in() -> void:
	if _camera != null:
		_camera.zoom_centered(_camera.zoom_step)


func _on_zoom_out() -> void:
	if _camera != null:
		_camera.zoom_centered(1.0 / _camera.zoom_step)


func _on_reset() -> void:
	if _camera != null:
		_camera.reset_view()
