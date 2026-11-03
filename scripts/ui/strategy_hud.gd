extends Control
class_name StrategyHUD
## World map camera HUD, tile inspection, and movement order feedback.

@onready var header_panel: PanelContainer = $Header
@onready var controls_panel: PanelContainer = $Controls
@onready var help_panel: PanelContainer = $Help
@onready var coordinates_label: Label = $Header/Margin/Content/Coordinates
@onready var zoom_label: Label = $Controls/Margin/Buttons/ZoomLabel
@onready var world_stats_label: Label = $Header/Margin/Content/WorldStats
@onready var tile_info_label: Label = $Help/Margin/Content/PreviewWarning
@onready var zoom_in_button: Button = $Controls/Margin/Buttons/ZoomIn
@onready var zoom_out_button: Button = $Controls/Margin/Buttons/ZoomOut
@onready var home_button: Button = $Controls/Margin/Buttons/Reset

var _camera: StrategyCamera


func _ready() -> void:
	zoom_in_button.pressed.connect(_on_zoom_in)
	zoom_out_button.pressed.connect(_on_zoom_out)
	home_button.pressed.connect(_on_reset)
	get_viewport().size_changed.connect(_layout_for_viewport)
	_layout_for_viewport()


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


func show_world_stats(world: Dictionary) -> void:
	var counts: Dictionary = world.get("terrain_counts", {})
	var land: int = 0
	for terrain in counts.keys():
		if terrain != "ocean":
			land += int(counts[terrain])
	world_stats_label.text = "%d × %d HEXES  •  %d LAND" % [int(world.get("columns", 0)), int(world.get("rows", 0)), land]


func show_tile_info(tile: Dictionary) -> void:
	if tile.is_empty():
		tile_info_label.text = "Select a hex to inspect terrain and coordinates"
		return
	var site: String = String(tile.get("site_name", ""))
	var terrain: String = String(tile["terrain"]).to_upper()
	var location: String = String(tile["continent"])
	var title: String = site if not site.is_empty() else terrain
	var axial: Vector2i = tile["axial"]
	tile_info_label.text = "%s  •  %s  •  (%d,%d)" % [title, location, axial.x, axial.y]


func show_command_info(message: String) -> void:
	tile_info_label.text = message


func _layout_for_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var narrow: bool = viewport_size.x < 760.0
	for panel in [header_panel, controls_panel, help_panel]:
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	if narrow:
		header_panel.position = Vector2(12.0, 12.0)
		header_panel.size = Vector2(minf(312.0, viewport_size.x - 24.0), 120.0)
		controls_panel.position = Vector2(12.0, 143.0)
		controls_panel.size = Vector2(minf(288.0, viewport_size.x - 24.0), 66.0)
		help_panel.position = Vector2(12.0, viewport_size.y - 124.0)
		help_panel.size = Vector2(minf(437.0, viewport_size.x - 24.0), 106.0)
	else:
		header_panel.position = Vector2(18.0, 18.0)
		header_panel.size = Vector2(312.0, 120.0)
		controls_panel.position = Vector2(viewport_size.x - 306.0, 18.0)
		controls_panel.size = Vector2(288.0, 66.0)
		help_panel.position = Vector2(18.0, viewport_size.y - 124.0)
		help_panel.size = Vector2(437.0, 106.0)
