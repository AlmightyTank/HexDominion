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
signal build_requested(kind: String)
signal train_requested(kind: String)
signal cancel_construction_requested(hex: Vector2i, site: Dictionary)
signal building_action_requested(action: String, hex: Vector2i, site: Dictionary)
var repair_button: Button
var sell_button: Button
var cancel_construction_button: Button
var _cancel_hex: Vector2i
var _cancel_site: Dictionary = {}
signal match_action_requested(action: String)
signal difficulty_selected(difficulty: String)
var match_panel: PanelContainer
var match_label: Label
var pause_overlay: Control
var resume_button: Button
var difficulty_selector: OptionButton
signal save_slot_requested(title: String, path: String)
signal load_slot_requested(path: String)
var save_browser: Control
var save_list: ItemList
var save_name: LineEdit
var save_message: Label
var save_accept: Button
var save_title: Label
var overwrite_dialog: ConfirmationDialog
var _save_mode: String = "save"
var _save_slots: Array[Dictionary] = []
var _pending_save_name: String = ""
var _pending_save_path: String = ""
var build_panel: PanelContainer
var build_status: Label
var build_buttons: Dictionary = {}
var context_title: Label
var train_buttons: Dictionary = {}
var training_progress: ProgressBar
signal facility_selected(hex: Vector2i)
signal rally_requested
signal defensive_order_requested(action: String)
var facility_buttons: Dictionary = {}
var facility_list: VBoxContainer
var economy_summary: Label
var resource_strip: PanelContainer
var power_rail: PanelContainer
var power_gauge: PowerGauge
var primary_button: Button
var field_command_panel: PanelContainer
var continent_overview: Label
var _continent_revision: int = -1
var _continent_manager: ContinentControl
var supply_info: Label
var rally_button: Button
var sidebar_scroll: ScrollContainer
var command_tabs: TabContainer
var radar: Control
var allied_chrome: Control
var sidebar_options: Button
var defense_grid: GridContainer
var allied_actions: HBoxContainer
var allied_repair: Button
var allied_sell: Button
var command_alert: Button
var structure_grid: GridContainer
var infantry_grid: GridContainer
var vehicle_grid: GridContainer
var selection_info: Label
signal stack_requested(kind: String)
var stack_rows: Dictionary = {}
var stack_panel: ScrollContainer
var stack_title: Label
var stack_passengers: Label
var stack_all: Button
var stack_expand: Button
var attack_button: Button
var add_selection_button: Button
var production_tabs: TabContainer
var selection_panel: ScrollContainer
var order_grid: GridContainer
var order_buttons: Dictionary = {}
var army_empty: Label
var production_queue: Label
var production_toggle: Button
var context_toggle: Button
var radar_toggle: Button
var mobile_layout: bool = false
var production_open: bool = true
var context_expanded: bool = false
var radar_open: bool = true
var _last_mobile: bool = false
var context_body: VBoxContainer
var context_scroll: ScrollContainer
var top_actions: HBoxContainer
var power_summary: Label
var continent_summary: Label
var _army_selected: bool = false
var tactical_header: Control
var tactical_deck: Control
var deck_details: Button
var production_heading: Label
var _order_parent: Control
var production_meter: ProgressBar


func _ready() -> void:
	_apply_strategy_theme()
	_create_build_menu()
	_create_match_menu()
	_organize_sidebar()
	_create_resource_strip()
	_create_command_layout()
	var housing: StyleBoxFlat = CommandTheme.box(CommandTheme.PANEL, CommandTheme.BORDER)
	housing.content_margin_left = 0
	housing.content_margin_right = 0
	housing.content_margin_top = 0
	housing.content_margin_bottom = 0
	build_panel.add_theme_stylebox_override("panel", housing)
	command_tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var palette: StyleBoxFlat = CommandTheme.box(CommandTheme.PANEL, CommandTheme.PANEL)
	palette.content_margin_left = 4
	palette.content_margin_right = 4
	production_tabs.add_theme_stylebox_override("panel", palette)
	$Header/Margin/Content/Subtitle.text = "STRATEGIC COMMAND  /  PLAYER FACTION"
	$Help/Margin/Content/HelpTitle.text = "FIELD ORDERS"
	$Help/Margin/Content/DesktopHelp.text = "LEFT DRAG  Select • SHIFT CLICK  Add • RIGHT CLICK  Move / attack"
	$Help/Margin/Content/TouchHelp.text = "TOUCH  Tap select/move • Add selection / Attack buttons • Drag pan • Pinch zoom"
	$Help/Margin/Content/TouchHelp.show()
	$Help/Margin/Content/DesktopHelp.show()
	$Help/Margin/Content/DesktopHelp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	$Help/Margin/Content/TouchHelp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile_info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	world_stats_label.add_theme_font_size_override("font_size", 16)
	zoom_in_button.pressed.connect(_on_zoom_in)
	zoom_out_button.pressed.connect(_on_zoom_out)
	home_button.pressed.connect(_on_reset)
	get_viewport().size_changed.connect(_layout_for_viewport)
	_layout_for_viewport()


func bind_camera(strategy_camera: StrategyCamera) -> void:
	_camera = strategy_camera
	radar.configure(_camera.get_parent().get_node("WorldMap"), _camera)
	_camera.view_changed.connect(_on_view_changed)
	_on_view_changed(_camera.position, _camera.zoom.x)
	_layout_for_viewport()


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


var _terrain_info: String = ""

func show_tile_info(tile: Dictionary) -> void:
	_terrain_info = TerrainRules.description(tile) if not tile.is_empty() else ""
	if tile.is_empty():
		tile_info_label.text = "Select a hex to inspect terrain and coordinates"
		return
	var site: String = String(tile.get("site_name", ""))
	var terrain: String = String(tile["terrain"]).to_upper()
	var location: String = String(tile["continent"])
	var title: String = site if not site.is_empty() else terrain
	var axial: Vector2i = tile["axial"]
	tile_info_label.text = "%s  •  %s  •  (%d,%d)\n%s" % [title, location, axial.x, axial.y, _terrain_info]


func show_command_info(message: String) -> void:
	tile_info_label.text = message + ("\n" + _terrain_info if not _terrain_info.is_empty() else "")


func _layout_for_viewport() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	mobile_layout = viewport_size.x < 800 or viewport_size.y < 480 or DisplayServer.is_touchscreen_available()
	if mobile_layout != _last_mobile:
		production_open = not mobile_layout
		context_expanded = false
		_last_mobile = mobile_layout
	var strip_height: float = 52 if viewport_size.x >= 600 else 88
	var width: float = 360
	var context_height: float = minf(196, viewport_size.y * 0.29) if context_expanded else 58
	if mobile_layout and context_expanded:
		context_height = minf(270, viewport_size.y * 0.46)
	var map_width: float = viewport_size.x - (width + 8 if production_open and not mobile_layout else 0)
	var map_height: float = viewport_size.y - strip_height - context_height - 12
	header_panel.hide()
	controls_panel.hide()
	if build_panel != null:
		build_panel.visible = production_open
		build_panel.position = Vector2(viewport_size.x - width, strip_height + 6)
		build_panel.size = Vector2(width - 6, viewport_size.y - strip_height - 12)
		if mobile_layout:
			var sheet_height: float = minf(420, viewport_size.y * 0.60)
			build_panel.position = Vector2(6, viewport_size.y - sheet_height - 6)
			build_panel.size = Vector2(viewport_size.x - 12, sheet_height)
			build_panel.z_index = 10
	if resource_strip != null:
		resource_strip.position = Vector2.ZERO
		resource_strip.size = Vector2(viewport_size.x, strip_height)
		power_rail.hide()
		top_actions.position = Vector2(maxf(6, viewport_size.x - 258), 4)
		top_actions.size = Vector2(252, 44)
		economy_summary.position = Vector2(10, 52 if viewport_size.x < 600 else 8)
		economy_summary.size = Vector2(230 if viewport_size.x < 600 else 260, 36)
		power_summary.position = Vector2(245 if viewport_size.x < 600 else 280, 52 if viewport_size.x < 600 else 8)
		continent_summary.visible = viewport_size.x >= 1000
		continent_summary.position = Vector2(470, 8)
		continent_summary.size = Vector2(180, 36)
	if radar != null:
		radar.visible = radar_open and not (mobile_layout and production_open)
		radar.position = Vector2(8, strip_height + map_height - 120)
		radar.size = Vector2(184 if not mobile_layout else 136, 112)
		radar.custom_minimum_size = Vector2.ZERO
	help_panel.hide()
	if field_command_panel != null:
		field_command_panel.show()
		field_command_panel.position = Vector2(6, viewport_size.y - context_height - 6)
		field_command_panel.size = Vector2(map_width - 12, context_height)
		context_scroll.visible = context_expanded
		context_toggle.text = "Selection / territory  " + ("Collapse" if context_expanded else "Expand")
		production_toggle.text = "Close" if production_open else "Build"
		radar_toggle.text = "Radar" if radar_open else "Map"
		order_grid.columns = 3 if map_width > 650 else 2
		selection_panel.custom_minimum_size.y = 0
	$Help/Margin/Content/HelpTitle.hide()
	$Help/Margin/Content/DesktopHelp.hide()
	$Help/Margin/Content/TouchHelp.hide()
	if _camera != null:
		_camera.configure_map_rect(Rect2(Vector2(0, strip_height), Vector2(map_width, maxf(80, map_height))))
	if allied_chrome != null:
		allied_chrome.hide()
	tactical_header.visible = not mobile_layout
	tactical_deck.visible = not mobile_layout
	deck_details.visible = not mobile_layout
	if not mobile_layout:
		_layout_allied_desktop(viewport_size)
	else:
		if order_grid.get_parent() != _order_parent:
			order_grid.reparent(_order_parent)
		top_actions.reparent(resource_strip.get_child(0))
		var pause_button: Button = top_actions.get_child(2)
		pause_button.custom_minimum_size = Vector2(72, 44)
		pause_button.add_theme_font_size_override("font_size", 14)
		economy_summary.show()
		power_summary.show()
		radar_toggle.show()
		resource_strip.show()
		sidebar_options.hide()
		production_toggle.show()
		command_tabs.tabs_visible = false
		allied_actions.show()
		add_selection_button.show()
		for grid in [structure_grid, defense_grid, infantry_grid, vehicle_grid]:
			for item in grid.get_children():
				item.custom_minimum_size.y = 66
	for grid in [structure_grid, defense_grid, infantry_grid, vehicle_grid]:
		grid.columns = 1
	if match_panel != null and match_panel.visible and match_panel.get_parent() == self:
		_layout_match_result()


func _layout_allied_desktop(viewport_size: Vector2) -> void:
	var scale: float = viewport_size.x / 900.0
	var sidebar_width: float = 180 * scale
	var left: float = viewport_size.x - sidebar_width
	var top: float = maxf(52, 42 * scale)
	var deck_height: float = 88 * scale
	resource_strip.show()
	resource_strip.position = Vector2.ZERO
	resource_strip.size = Vector2(viewport_size.x, top)
	economy_summary.hide()
	power_summary.hide()
	continent_summary.hide()
	tactical_header.position = Vector2.ZERO
	tactical_header.size = Vector2(viewport_size.x, top)
	move_child(tactical_header, resource_strip.get_index() + 1)
	top_actions.reparent(tactical_header)
	top_actions.position = Vector2(803, 4) * scale
	top_actions.size = Vector2(85 * scale, maxf(44, 34 * scale))
	var pause_button: Button = top_actions.get_child(2)
	pause_button.custom_minimum_size = Vector2(82 * scale, maxf(44, 34 * scale))
	pause_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pause_button.add_theme_font_size_override("font_size", roundi(14 * scale))
	radar_toggle.hide()
	radar.visible = radar_open
	radar.custom_minimum_size = Vector2.ZERO
	radar.position = Vector2(12 * scale, viewport_size.y - deck_height + 12 * scale)
	radar.size = Vector2(145, 64) * scale
	build_panel.visible = true
	allied_actions.show()
	build_panel.position = Vector2(left, top)
	build_panel.size = Vector2(sidebar_width, viewport_size.y - top)
	production_heading.add_theme_font_size_override("font_size", clampi(roundi(14 * scale), 14, 20))
	build_panel.z_index = 0
	sidebar_options.hide()
	command_tabs.tabs_visible = false
	production_toggle.hide()
	tactical_deck.position = Vector2(0, viewport_size.y - deck_height)
	tactical_deck.size = Vector2(left, deck_height)
	move_child(tactical_deck, 0)
	field_command_panel.visible = context_expanded
	field_command_panel.position = Vector2(165 * scale, viewport_size.y - deck_height - 210)
	field_command_panel.size = Vector2(minf(520, left - 180 * scale), 204)
	field_command_panel.z_index = 5
	context_scroll.visible = context_expanded
	deck_details.position = Vector2(302 * scale, viewport_size.y - deck_height + 8 * scale)
	deck_details.size = Vector2(84 * scale, 30 * scale)
	deck_details.text = "Close" if context_expanded else "Details"
	deck_details.tooltip_text = "Close selection details" if context_expanded else "Open selection details"
	if order_grid.get_parent() != self:
		order_grid.reparent(self)
	order_grid.position = Vector2(397 * scale, viewport_size.y - deck_height + 10 * scale)
	order_grid.size = Vector2(246 * scale, 68 * scale)
	order_grid.columns = 3
	for button in order_grid.get_children():
		button.custom_minimum_size = Vector2(76 * scale, maxf(44, 28 * scale))
	add_selection_button.hide()
	power_rail.show()
	power_rail.position = Vector2(left - 18, top)
	power_rail.size = Vector2(18, viewport_size.y - top)
	power_gauge.position = Vector2.ZERO
	power_gauge.size = power_rail.size
	for grid in [structure_grid, defense_grid, infantry_grid, vehicle_grid]:
		for item in grid.get_children():
			item.custom_minimum_size.y = maxf(48, 43 * scale)
	if _camera != null:
		_camera.configure_map_rect(Rect2(0, top, left - 18, viewport_size.y - top - deck_height))


func _create_command_layout() -> void:
	allied_chrome = preload("res://scripts/ui/allied_chrome.gd").new()
	add_child(allied_chrome)
	move_child(allied_chrome, 0)
	allied_actions = HBoxContainer.new()
	add_child(allied_actions)
	for action in ["Repair", "Sell"]:
		var button: Button = Button.new()
		button.text = action
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size.y = 44
		allied_actions.add_child(button)
		if action == "Repair":
			allied_repair = button
			button.pressed.connect(func() -> void: repair_button.pressed.emit())
		else:
			allied_sell = button
			button.pressed.connect(func() -> void: sell_button.pressed.emit())
	allied_actions.reparent(production_heading.get_parent())
	production_heading.get_parent().move_child(allied_actions, production_heading.get_index() + 1)
	radar.reparent(self)
	# Keep the battlefield transparent; only bounded panels consume input.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in field_command_panel.get_children():
		child.queue_free()
	var column: VBoxContainer = VBoxContainer.new()
	field_command_panel.add_child(column)
	context_toggle = Button.new()
	context_toggle.custom_minimum_size.y = 44
	context_toggle.pressed.connect(func() -> void:
		context_expanded = not context_expanded
		_layout_for_viewport()
	)
	var context_header: HBoxContainer = HBoxContainer.new()
	column.add_child(context_header)
	context_toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context_header.add_child(context_toggle)
	context_scroll = ScrollContainer.new()
	context_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	context_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	context_scroll.follow_focus = true
	column.add_child(context_scroll)
	context_body = VBoxContainer.new()
	context_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context_scroll.add_child(context_body)
	selection_panel.reparent(context_body)
	stack_panel.reparent(context_body)
	var inspector: Control = build_status.get_parent()
	for control in [tile_info_label, supply_info, build_status, training_progress, primary_button, rally_button, cancel_construction_button, repair_button, sell_button]:
		control.reparent(context_body)
	inspector.custom_minimum_size.x = 0
	for kind in stack_rows:
		stack_rows[kind].icon = UnitArt.texture(kind, 1, "icon")
		stack_rows[kind].expand_icon = true
		stack_rows[kind].add_theme_constant_override("icon_max_width", 28)
	_order_parent = order_grid.get_parent()
	tactical_header = preload("res://scripts/ui/tactical_surface.gd").new()
	add_child(tactical_header)
	tactical_deck = preload("res://scripts/ui/tactical_surface.gd").new()
	tactical_deck.deck = true
	add_child(tactical_deck)
	deck_details = Button.new()
	add_child(deck_details)
	deck_details.pressed.connect(func() -> void:
		context_expanded = not context_expanded
		_layout_for_viewport()
	)
	_set_command_cursors(self)


func _organize_sidebar() -> void:
	var column: VBoxContainer = radar.get_parent()
	context_title.hide()
	column.get_child(context_title.get_index() + 1).hide()
	production_tabs = command_tabs
	production_tabs.name = "Categories"
	for index in range(4):
		production_tabs.set_tab_title(index, ["BUILD", "DEF", "ARMY", "VEH"][index])
		production_tabs.set_tab_icon(index, null)
		production_tabs.set_tab_tooltip(index, ["Structures", "Defenses", "Infantry", "Vehicles / Aircraft"][index])
	var sites: Control = production_tabs.get_child(4)
	sites.reparent(self)
	command_tabs = TabContainer.new()
	command_tabs.name = "Management"
	command_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(command_tabs)
	production_heading = Label.new()
	production_heading.text = "CONSTRUCTION"
	production_heading.add_theme_font_size_override("font_size", 20)
	column.add_child(production_heading)
	column.move_child(production_heading, command_tabs.get_index())
	var army: VBoxContainer = VBoxContainer.new()
	army.name = "Army"
	add_child(army)
	army.hide()
	army_empty = Label.new()
	army_empty.text = "Select a hex army to manage its units."
	army_empty.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	army.add_child(army_empty)
	stack_panel.reparent(army)
	stack_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var production: VBoxContainer = VBoxContainer.new()
	production.name = "Production"
	command_tabs.add_child(production)
	var queue_scroll: ScrollContainer = ScrollContainer.new()
	queue_scroll.custom_minimum_size.y = 54
	queue_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	production.add_child(queue_scroll)
	production_queue = Label.new()
	production_queue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	production_queue.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	queue_scroll.add_child(production_queue)
	production_tabs.reparent(production)
	production.move_child(queue_scroll, production.get_child_count() - 1)
	var queue_heading: Label = Label.new()
	queue_heading.text = "PRODUCTION QUEUE"
	production.add_child(queue_heading)
	production.move_child(queue_heading, queue_scroll.get_index())
	production_meter = ProgressBar.new()
	production_meter.show_percentage = false
	production_meter.custom_minimum_size.y = 6
	production.add_child(production_meter)
	production.move_child(production_meter, queue_scroll.get_index())
	sites.hide()
	var inspector: VBoxContainer = sites.get_child(0)
	tile_info_label.reparent(inspector)
	supply_info.reparent(inspector)
	continent_overview.get_parent().reparent(inspector)
	selection_panel = ScrollContainer.new()
	selection_panel.name = "Selection"
	selection_panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	selection_panel.follow_focus = true
	column.add_child(selection_panel)
	column.move_child(selection_panel, command_tabs.get_index())
	var selection: VBoxContainer = VBoxContainer.new()
	selection.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selection_panel.add_child(selection)
	selection_info.reparent(selection)
	selection_info.show()
	order_grid = GridContainer.new()
	order_grid.columns = 2
	selection.add_child(order_grid)
	for action in ["move", "attack", "hold", "garrison", "load", "unload", "add_select"]:
		var button: Button = attack_button if action == "attack" else (add_selection_button if action == "add_select" else order_buttons[action])
		button.reparent(order_grid)
	command_tabs.current_tab = 0
	command_tabs.tabs_visible = false
	for index in range(4):
		production_tabs.set_tab_icon(index, null)
		production_tabs.set_tab_icon_max_width(index, 24)
	production_tabs.get_tab_bar().tab_alignment = TabBar.ALIGNMENT_CENTER
	_set_command_cursors(self)


func _create_resource_strip() -> void:
	resource_strip = PanelContainer.new()
	resource_strip.name = "ResourceStrip"
	add_child(resource_strip)
	var strip_style: StyleBoxFlat = _ui_box(CommandTheme.BACKGROUND, CommandTheme.BORDER, 0)
	strip_style.content_margin_top = 2
	strip_style.content_margin_bottom = 2
	resource_strip.add_theme_stylebox_override("panel", strip_style)
	var strip_content: Control = Control.new()
	strip_content.mouse_filter = Control.MOUSE_FILTER_PASS
	resource_strip.add_child(strip_content)
	economy_summary.reparent(strip_content)
	economy_summary.autowrap_mode = TextServer.AUTOWRAP_OFF
	economy_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	economy_summary.add_theme_font_size_override("font_size", 14)
	economy_summary.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	economy_summary.text = "Loading command network..."
	power_summary = Label.new()
	power_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	power_summary.size = Vector2(190, 36)
	strip_content.add_child(power_summary)
	continent_summary = Label.new()
	continent_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	strip_content.add_child(continent_summary)
	top_actions = HBoxContainer.new()
	strip_content.add_child(top_actions)
	production_toggle = Button.new()
	production_toggle.custom_minimum_size = Vector2(72, 44)
	production_toggle.pressed.connect(func() -> void:
		if mobile_layout:
			production_open = not production_open
		else:
			command_tabs.current_tab = 0
		_layout_for_viewport()
	)
	top_actions.add_child(production_toggle)
	radar_toggle = Button.new()
	radar_toggle.custom_minimum_size = Vector2(66, 44)
	radar_toggle.pressed.connect(func() -> void:
		radar_open = not radar_open
		_layout_for_viewport()
	)
	top_actions.add_child(radar_toggle)
	var pause: Button = Button.new()
	pause.text = "Pause"
	pause.custom_minimum_size = Vector2(72, 44)
	pause.pressed.connect(func() -> void: match_action_requested.emit("pause"))
	top_actions.add_child(pause)
	power_rail = PanelContainer.new()
	power_rail.name = "PowerRail"
	add_child(power_rail)
	var rail_style: StyleBoxFlat = _ui_box(Color("191e1b"), Color("777762"), 0)
	rail_style.content_margin_left = 0
	rail_style.content_margin_right = 0
	rail_style.content_margin_top = 0
	rail_style.content_margin_bottom = 0
	power_rail.add_theme_stylebox_override("panel", rail_style)
	var rail_content: Control = Control.new()
	power_rail.add_child(rail_content)
	power_gauge = PowerGauge.new()
	power_gauge.name = "PowerGauge"
	power_gauge.mouse_filter = Control.MOUSE_FILTER_PASS
	rail_content.add_child(power_gauge)

func _create_match_menu() -> void:
	match_panel = PanelContainer.new()
	match_panel.name = "MatchControls"
	var sidebar: VBoxContainer = radar.get_parent()
	sidebar.add_child(match_panel)
	sidebar.move_child(match_panel, radar.get_index())
	var column: VBoxContainer = VBoxContainer.new()
	match_panel.add_child(column)
	match_label = Label.new()
	match_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(match_label)
	pause_overlay = Control.new()
	pause_overlay.name = "PauseMenu"
	add_child(pause_overlay)
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pause_overlay.z_index = 100
	var shade: ColorRect = ColorRect.new()
	shade.color = Color(0, 0, 0, 0.65)
	pause_overlay.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	pause_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = 280
	center.add_child(panel)
	var buttons: VBoxContainer = VBoxContainer.new()
	panel.add_child(buttons)
	var title: Label = Label.new()
	title.text = "MATCH PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	buttons.add_child(title)
	var difficulty_row: HBoxContainer = HBoxContainer.new()
	buttons.add_child(difficulty_row)
	var difficulty_label: Label = Label.new()
	difficulty_label.text = "Opponent"
	difficulty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	difficulty_row.add_child(difficulty_label)
	difficulty_selector = OptionButton.new()
	difficulty_selector.custom_minimum_size = Vector2(132, 44)
	difficulty_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	difficulty_selector.focus_mode = Control.FOCUS_ALL
	difficulty_selector.tooltip_text = "Easy: smaller forces and slower decisions\nMedium: ground combined arms and light defense\nHard: full combined arms and the original pacing"
	for id in AIDifficulty.ORDER:
		var index: int = difficulty_selector.item_count
		difficulty_selector.add_item(AIDifficulty.profile(id)["title"])
		difficulty_selector.set_item_metadata(index, id)
	difficulty_selector.item_selected.connect(func(index: int) -> void:
		difficulty_selected.emit(String(difficulty_selector.get_item_metadata(index)))
	)
	difficulty_row.add_child(difficulty_selector)
	for action in ["resume", "save", "load", "restart"]:
		var button: Button = Button.new()
		button.text = {"resume": "Resume • Esc", "save": "Save • F5", "load": "Load • F9", "restart": "Restart • F10"}[action]
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: match_action_requested.emit(action))
		buttons.add_child(button)
		if action == "resume":
			resume_button = button
	pause_overlay.hide()
	_create_save_browser()


func select_difficulty(value: String) -> void:
	for index in range(difficulty_selector.item_count):
		if difficulty_selector.get_item_metadata(index) == value:
			difficulty_selector.select(index)
			return


func show_pause_menu(open: bool) -> void:
	pause_overlay.visible = open
	if not open:
		save_browser.hide()
		overwrite_dialog.hide()
	if open:
		resume_button.grab_focus()
	else:
		var focused: Control = get_viewport().gui_get_focus_owner()
		if focused != null and pause_overlay.is_ancestor_of(focused):
			focused.release_focus()


func _create_save_browser() -> void:
	save_browser = Control.new()
	save_browser.name = "SaveBrowser"
	pause_overlay.add_child(save_browser)
	save_browser.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade: ColorRect = ColorRect.new()
	shade.color = Color("09121f")
	save_browser.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center: CenterContainer = CenterContainer.new()
	save_browser.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel: PanelContainer = PanelContainer.new()
	panel.custom_minimum_size.x = 360
	center.add_child(panel)
	var column: VBoxContainer = VBoxContainer.new()
	panel.add_child(column)
	save_title = Label.new()
	save_title.add_theme_font_size_override("font_size", 22)
	column.add_child(save_title)
	save_list = ItemList.new()
	save_list.custom_minimum_size = Vector2(320, 180)
	save_list.item_selected.connect(_on_save_selected)
	column.add_child(save_list)
	save_name = LineEdit.new()
	save_name.max_length = 80
	save_name.placeholder_text = "Save name"
	save_name.text_changed.connect(func(_text: String) -> void: _update_save_accept())
	column.add_child(save_name)
	save_message = Label.new()
	save_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(save_message)
	var actions: HBoxContainer = HBoxContainer.new()
	column.add_child(actions)
	save_accept = Button.new()
	save_accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_accept.pressed.connect(_accept_save_browser)
	actions.add_child(save_accept)
	var back: Button = Button.new()
	back.text = "Back"
	back.pressed.connect(close_save_browser)
	actions.add_child(back)
	overwrite_dialog = ConfirmationDialog.new()
	overwrite_dialog.title = "Overwrite save?"
	overwrite_dialog.confirmed.connect(func() -> void: save_slot_requested.emit(_pending_save_name, _pending_save_path))
	add_child(overwrite_dialog)
	save_browser.hide()


func show_save_browser(mode: String, slots: Array[Dictionary]) -> void:
	_save_mode = mode
	_save_slots = slots
	save_list.clear()
	save_title.text = "SAVE MATCH" if mode == "save" else "LOAD MATCH"
	if mode == "save":
		save_list.add_item("＋ Create a new save")
	for slot in slots:
		var date: String = Time.get_datetime_string_from_unix_time(slot["saved_at"]).replace("T", " ") + " UTC"
		var label: String = "%s\n%s • %s" % [slot["name"], date, slot["result"] if slot["valid"] else "Invalid / incompatible"]
		save_list.add_item(label)
		if mode == "load" and not slot["valid"]:
			save_list.set_item_disabled(save_list.item_count - 1, true)
	save_name.visible = mode == "save"
	save_name.text = "Match " + Time.get_datetime_string_from_system().replace("T", " ")
	save_message.text = "Select a save to load." if not slots.is_empty() else "No saved matches yet."
	if mode == "save":
		save_list.select(0)
		save_message.text = "Create a new save or select one to overwrite."
	save_browser.show()
	_update_save_accept()
	if mode == "save":
		save_name.grab_focus()
	else:
		save_list.grab_focus()


func close_save_browser() -> void:
	save_browser.hide()
	overwrite_dialog.hide()
	resume_button.grab_focus()


func _selected_save_path() -> String:
	var selected_items: PackedInt32Array = save_list.get_selected_items()
	if selected_items.is_empty():
		return ""
	var index: int = selected_items[0] - (1 if _save_mode == "save" else 0)
	return _save_slots[index]["path"] if index >= 0 and index < _save_slots.size() else ""


func _on_save_selected(index: int) -> void:
	if _save_mode == "save" and index > 0:
		save_name.text = _save_slots[index - 1]["name"]
	_update_save_accept()


func _update_save_accept() -> void:
	if _save_mode == "save":
		save_accept.text = "Create save" if _selected_save_path().is_empty() else "Overwrite save"
		save_accept.disabled = save_name.text.strip_edges().is_empty()
	else:
		save_accept.text = "Load selected save"
		save_accept.disabled = _selected_save_path().is_empty()


func _accept_save_browser() -> void:
	var path: String = _selected_save_path()
	if _save_mode == "load":
		if not path.is_empty():
			load_slot_requested.emit(path)
	elif not save_name.text.strip_edges().is_empty():
		if path.is_empty():
			save_slot_requested.emit(save_name.text.strip_edges(), "")
		else:
			_pending_save_name = save_name.text.strip_edges()
			_pending_save_path = path
			overwrite_dialog.dialog_text = "Replace this saved match?\nThe previous version will be kept as a backup."
			overwrite_dialog.popup_centered()


func show_match_status(match_state: MatchState) -> void:
	allied_repair.disabled = false
	allied_sell.disabled = false
	allied_repair.tooltip_text = "Repair the selected friendly building (requires damage and credits)"
	allied_sell.tooltip_text = "Sell the selected completed friendly building"
	match_panel.visible = match_state.result != "playing"
	var title: String = "CAPTURE THE RIVAL HQ"
	if match_state.result != "playing":
		title = match_state.result.to_upper() + " • Match ended"
	match_label.text = "%s\nYour HQ (%d,%d) • Rival HQ (%d,%d)" % [title, match_state.player_hq.x, match_state.player_hq.y, match_state.rival_hq.x, match_state.rival_hq.y]
	match_label.add_theme_color_override("font_color", Color("f08075") if match_state.result == "defeat" else Color("65ebd0"))
	if match_state.result != "playing":
		if match_panel.get_parent() != self:
			match_panel.reparent(self)
		_layout_match_result()
		build_panel.hide()


func _layout_match_result() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var panel_size: Vector2 = Vector2(minf(480.0, viewport_size.x - 24.0), 80.0)
	match_panel.position = (viewport_size - panel_size) * 0.5
	match_panel.size = panel_size
	match_panel.z_index = 20
	match_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	match_label.size_flags_vertical = Control.SIZE_EXPAND_FILL


func _create_build_menu() -> void:
	build_panel = PanelContainer.new()
	build_panel.name = "BuildMenu"
	add_child(build_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 6)
	build_panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	margin.add_child(column)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var options: Button = Button.new()
	sidebar_options = options
	options.text = "OPTIONS  /  ESC"
	options.custom_minimum_size.y = 44
	options.pressed.connect(func() -> void: match_action_requested.emit("pause"))
	column.add_child(options)
	radar = preload("res://scripts/ui/strategy_minimap.gd").new()
	column.add_child(radar)
	var title: Label = Label.new()
	context_title = title
	title.text = "CONSTRUCTION"
	column.add_child(title)
	title.add_theme_color_override("font_color", Color("65ebd0"))
	title.add_theme_font_size_override("font_size", 19)
	var divider: HSeparator = HSeparator.new()
	column.add_child(divider)
	field_command_panel = PanelContainer.new()
	field_command_panel.name = "FieldCommands"
	add_child(field_command_panel)
	var command_scroll: ScrollContainer = ScrollContainer.new()
	field_command_panel.add_child(command_scroll)
	var command_row: HBoxContainer = HBoxContainer.new()
	command_row.add_theme_constant_override("separation", 12)
	command_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	command_scroll.add_child(command_row)
	var economy_column: VBoxContainer = VBoxContainer.new()
	economy_column.custom_minimum_size.x = 160
	economy_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_row.add_child(economy_column)
	economy_summary = Label.new()
	economy_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	economy_column.add_child(economy_summary)
	supply_info = Label.new()
	supply_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	economy_column.add_child(supply_info)
	var continent_panel: ScrollContainer = ScrollContainer.new()
	continent_panel.custom_minimum_size = Vector2(160, 44)
	continent_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continent_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	continent_panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	economy_column.add_child(continent_panel)
	continent_overview = Label.new()
	continent_overview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	continent_overview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	continent_panel.add_child(continent_overview)
	var orders_column: VBoxContainer = VBoxContainer.new()
	orders_column.custom_minimum_size.x = 200
	command_row.add_child(orders_column)
	var defensive_orders: HBoxContainer = HBoxContainer.new()
	orders_column.add_child(defensive_orders)
	for action in ["move", "hold", "garrison"]:
		var order_button: Button = Button.new()
		order_button.text = {"move": "Move", "hold": "Hold (J)", "garrison": "Garrison (G)"}[action]
		order_button.custom_minimum_size.y = 44
		order_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		order_button.pressed.connect(func() -> void: defensive_order_requested.emit(action))
		defensive_orders.add_child(order_button)
		order_buttons[action] = order_button
	var command_orders: HBoxContainer = HBoxContainer.new()
	orders_column.add_child(command_orders)
	attack_button = Button.new()
	attack_button.text = "Attack (X)"
	attack_button.custom_minimum_size.y = 44
	attack_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	attack_button.pressed.connect(func() -> void: defensive_order_requested.emit("attack"))
	command_orders.add_child(attack_button)
	var transport_orders: HBoxContainer = HBoxContainer.new()
	orders_column.add_child(transport_orders)
	for action in ["load", "unload"]:
		var button: Button = Button.new()
		button.text = "Load transport (L)" if action == "load" else "Unload transport (U)"
		button.custom_minimum_size.y = 44
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: defensive_order_requested.emit(action))
		transport_orders.add_child(button)
		order_buttons[action] = button
	add_selection_button = Button.new()
	add_selection_button.text = "Add selection"
	add_selection_button.toggle_mode = true
	add_selection_button.custom_minimum_size.y = 44
	add_selection_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_selection_button.pressed.connect(func() -> void: defensive_order_requested.emit("add_select"))
	command_orders.add_child(add_selection_button)
	command_tabs = TabContainer.new()
	stack_panel = ScrollContainer.new()
	stack_panel.name = "HexArmy"
	stack_panel.custom_minimum_size.x = 200
	stack_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack_panel.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	stack_panel.follow_focus = true
	command_scroll.follow_focus = true
	command_row.add_child(stack_panel)
	command_row.move_child(stack_panel, 0)
	command_row.move_child(orders_column, 1)
	var context_column: VBoxContainer = VBoxContainer.new()
	context_column.name = "TerrainContext"
	context_column.custom_minimum_size.x = 220
	context_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_row.add_child(context_column)
	var context_heading: Label = Label.new()
	context_heading.text = "TERRAIN / ORDERS"
	context_column.add_child(context_heading)
	tile_info_label.reparent(context_column)
	tile_info_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var stack_column: VBoxContainer = VBoxContainer.new()
	stack_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack_panel.add_child(stack_column)
	stack_title = Label.new()
	stack_column.add_child(stack_title)
	selection_info = Label.new()
	selection_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack_column.add_child(selection_info)
	selection_info.hide()
	for kind in UnitCatalog.TYPES:
		var row: Button = Button.new()
		row.custom_minimum_size.y = 44
		row.toggle_mode = true
		row.pressed.connect(func() -> void: stack_requested.emit(kind))
		stack_column.add_child(row)
		stack_rows[kind] = row
	stack_passengers = Label.new()
	stack_passengers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	stack_column.add_child(stack_passengers)
	stack_all = Button.new()
	stack_all.text = "Select all in hex"
	stack_all.custom_minimum_size.y = 44
	stack_all.pressed.connect(func() -> void: stack_requested.emit("all"))
	stack_column.add_child(stack_all)
	stack_expand = Button.new()
	stack_expand.custom_minimum_size.y = 44
	stack_expand.pressed.connect(func() -> void: stack_requested.emit("expand"))
	stack_column.add_child(stack_expand)
	var stack_actions: HBoxContainer = HBoxContainer.new()
	stack_column.add_child(stack_actions)
	stack_column.move_child(stack_passengers, 2)
	stack_column.move_child(stack_actions, 3)
	stack_all.reparent(stack_actions)
	stack_all.text = "Select all"
	stack_all.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack_expand.reparent(stack_actions)
	stack_expand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack_panel.hide()
	command_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(command_tabs)
	var pages: Array[VBoxContainer] = []
	for page_name in ["Build", "Def", "Inf", "Veh", "Sites"]:
		var page_scroll: ScrollContainer = ScrollContainer.new()
		page_scroll.name = page_name
		page_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		command_tabs.add_child(page_scroll)
		var page: VBoxContainer = VBoxContainer.new()
		page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		page_scroll.add_child(page)
		pages.append(page)
	structure_grid = GridContainer.new()
	structure_grid.columns = 1
	pages[0].add_child(structure_grid)
	defense_grid = GridContainer.new()
	pages[1].add_child(defense_grid)
	infantry_grid = GridContainer.new()
	infantry_grid.columns = 1
	pages[2].add_child(infantry_grid)
	vehicle_grid = GridContainer.new()
	vehicle_grid.columns = 1
	pages[3].add_child(vehicle_grid)
	for index in [2, 3]:
		var hint: Label = Label.new()
		hint.text = "Selected barracks, otherwise primary or newest." if index == 2 else "Selected factory, otherwise primary or newest."
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		pages[index].add_child(hint)
	column = pages[4]
	primary_button = Button.new()
	primary_button.text = "Set primary production"
	primary_button.custom_minimum_size.y = 44
	column.add_child(primary_button)
	facility_list = VBoxContainer.new()
	var roster_scroll: ScrollContainer = ScrollContainer.new()
	roster_scroll.custom_minimum_size.y = 96
	roster_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(roster_scroll)
	roster_scroll.add_child(facility_list)
	facility_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var road_button: ProductionItem = ProductionItem.new()
	road_button.configure("Road", 100, 0, null)
	road_button.tooltip_text = "30% faster ground travel. Place on owned land."
	road_button.custom_minimum_size.y = 128
	road_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	road_button.pressed.connect(func() -> void: build_requested.emit("road"))
	structure_grid.add_child(road_button)
	for kind in ["supply_center", "barracks", "factory", "extractor", "power_plant", "bunker", "airfield", "shipyard"]:
		var button: ProductionItem = ProductionItem.new()
		button.configure(String(kind).capitalize(), EconomyState.BUILD_COSTS[kind], EconomyState.BUILD_SECONDS[kind], UnitArt.building_texture(kind, 1))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 128)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = {"supply_center": "Unload Supply Trucks for approved credits. 300 CR, 8 seconds, 300 HP, 10 power.", "barracks": "Train rifle squads • 50 credits • 4 seconds", "factory": "20 power • Half speed under low power", "extractor": "Legacy strategic structure • No passive income • Resource deposit only", "power_plant": "40 power • 8 seconds to construct • 250 HP", "bunker": "Two infantry • G assigns garrison • J holds • 40% less incoming damage; passable", "airfield": "Aircraft production and fighter rearming. Plains, desert or city. 20 power; offline under low power.", "shipyard": "Naval production. Owned coastal land adjoining navigable ocean. 220 CR; 10 seconds."}[kind]
		button.pressed.connect(func() -> void: build_requested.emit(kind))
		(defense_grid if kind == "bunker" else structure_grid).add_child(button)
		build_buttons[kind] = button
	build_status = Label.new()
	build_status.text = "Choose a building"
	build_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(build_status)
	build_status.add_theme_color_override("font_color", Color("a8bbc9"))
	rally_button = Button.new()
	rally_button.text = "Set rally point on map"
	rally_button.custom_minimum_size.y = 44
	rally_button.pressed.connect(func() -> void: rally_requested.emit())
	column.add_child(rally_button)
	training_progress = ProgressBar.new()
	training_progress.custom_minimum_size.y = 12
	training_progress.show_percentage = false
	column.add_child(training_progress)
	cancel_construction_button = Button.new()
	cancel_construction_button.custom_minimum_size.y = 44
	cancel_construction_button.pressed.connect(func() -> void: cancel_construction_requested.emit(_cancel_hex, _cancel_site))
	column.add_child(cancel_construction_button)
	cancel_construction_button.hide()
	repair_button = Button.new()
	repair_button.custom_minimum_size.y = 44
	repair_button.pressed.connect(func() -> void: building_action_requested.emit("repair", _cancel_hex, _cancel_site))
	column.add_child(repair_button)
	repair_button.hide()
	sell_button = Button.new()
	sell_button.custom_minimum_size.y = 44
	sell_button.pressed.connect(func() -> void: building_action_requested.emit("sell", _cancel_hex, _cancel_site))
	column.add_child(sell_button)
	sell_button.hide()
	for kind in UnitCatalog.TYPES:
		if not EconomyState.TRAIN_COSTS.has(kind) or not EconomyState.TRAIN_SECONDS.has(kind):
			continue
		var button: ProductionItem = ProductionItem.new()
		button.configure(UnitCatalog.TYPES[kind]["name"], EconomyState.TRAIN_COSTS[kind], EconomyState.TRAIN_SECONDS[kind], UnitArt.texture(kind, 1, "icon"))
		button.text = "%s\n%d CR / %ds" % [UnitCatalog.TYPES[kind]["name"], EconomyState.TRAIN_COSTS[kind], EconomyState.TRAIN_SECONDS[kind]]
		button.tooltip_text = "%s: %.0f HP; %.2fs/hex; %.0f damage / %.2fs; range %d\nDamage vs infantry x%.2f, armor x%.2f" % [UnitCatalog.TYPES[kind]["name"], UnitCatalog.TYPES[kind]["health"], UnitCatalog.TYPES[kind]["speed"], UnitCatalog.TYPES[kind]["damage"], UnitCatalog.TYPES[kind]["cooldown"], UnitCatalog.TYPES[kind]["range"], UnitCatalog.TYPES[kind]["infantry"], UnitCatalog.TYPES[kind]["armor"]]
		button.custom_minimum_size.y = 44
		button.pressed.connect(func() -> void: train_requested.emit(kind))
		(infantry_grid if UnitCatalog.is_infantry(kind) else vehicle_grid).add_child(button)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size.y = 128
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		train_buttons[kind] = button
	build_panel.show()
	_set_command_cursors(build_panel)


func show_stack(members: Array[UnitState], roster: Array[UnitState], expanded: Vector2i, selected_roster: Array[UnitState]) -> void:
	stack_panel.visible = not members.is_empty()
	army_empty.visible = members.is_empty()
	if members.is_empty():
		return
	var counts: Dictionary = {}
	var selected_counts: Dictionary = {}
	var aboard: int = 0
	for member in members:
		counts[member.kind] = counts.get(member.kind, 0) + 1
		if selected_roster.has(member):
			selected_counts[member.kind] = selected_counts.get(member.kind, 0) + 1
		if TransportRules.capacity(member) > 0:
			aboard += TransportRules.passengers(member, roster).size()
	stack_title.text = "HEX ARMY | %d deployed" % members.size()
	stack_title.tooltip_text = "Hex (%d, %d)\n%s" % [members[0].hex.x, members[0].hex.y, selection_info.text]
	for kind in stack_rows:
		stack_rows[kind].visible = counts.has(kind)
		stack_rows[kind].text = "%s  x%d" % [UnitCatalog.TYPES[kind]["name"], counts.get(kind, 0)]
		stack_rows[kind].set_pressed_no_signal(selected_counts.has(kind))
		stack_rows[kind].tooltip_text = "%d of %d selected. Click to select only this type." % [selected_counts.get(kind, 0), counts.get(kind, 0)]
	stack_passengers.visible = aboard > 0
	stack_passengers.text = "%d aboard transports (not deployed)" % aboard
	for member in selected_roster:
		if UnitCatalog.is_air(member.kind):
			stack_passengers.visible = true
			stack_passengers.text = "%s: %s | base %s | %.1fs rearm" % [member.title, member.air_mission if member.kind == "fighter" else "Hover / flight", str(member.airfield) if member.airfield != AircraftRules.NO_BASE else "None", member.mission_remaining]
			break
	stack_expand.text = "Collapse" if expanded == members[0].hex else "Expand"

func show_selection(roster: Array[UnitState], attack_mode: bool, all_units: Array[UnitState] = []) -> void:
	_army_selected = not roster.is_empty()
	var composition: Dictionary = {}
	var health: float = 0
	var maximum: float = 0
	for unit in roster:
		composition[unit.kind] = composition.get(unit.kind, 0) + 1
		health += unit.health
		maximum += unit.max_health
	var parts: PackedStringArray = []
	for kind in composition:
		parts.append("%d %s" % [composition[kind], UnitCatalog.display_name(kind, composition[kind])])
	tactical_deck.update_values({"count": roster.size(), "composition": " · ".join(parts) if not parts.is_empty() else "Select an army or inspect a territory.", "health": health / maximum if maximum > 0 else 0.0})
	if context_toggle != null:
		context_toggle.text = ("%d units selected" % roster.size() if _army_selected else "Field command") + (" | Hide details" if context_expanded else " | Show details")
	tile_info_label.visible = not _army_selected
	attack_button.text = "Cancel attack" if attack_mode else "Attack (X)"
	attack_button.disabled = roster.is_empty()
	order_grid.visible = not roster.is_empty()
	selection_panel.custom_minimum_size.y = 42 if roster.is_empty() else 138
	var infantry: bool = false
	var can_load: bool = false
	var can_unload: bool = false
	for unit in roster:
		if TransportRules.capacity(unit) > 0 and unit.path.is_empty() and not TransportRules.passengers(unit, all_units).is_empty():
			can_unload = true
		infantry = infantry or UnitCatalog.is_infantry(unit.kind)
		for carrier in all_units:
			if TransportRules.permits(carrier.kind, unit.kind) and carrier.is_deployed() and carrier.faction == unit.faction and (carrier.hex == unit.hex if carrier.kind == "apc" else HexMath.distance(carrier.hex, unit.hex) == 1) and carrier.path.is_empty() and unit.path.is_empty() and TransportRules.used(carrier, all_units) + TransportRules.cargo_cost(unit) <= TransportRules.capacity(carrier):
				can_load = true
	order_buttons["garrison"].visible = infantry
	order_buttons["load"].visible = can_load
	order_buttons["unload"].visible = can_unload
	if can_load or can_unload:
		selection_panel.custom_minimum_size.y = 182
	if roster.is_empty():
		selection_info.text = "No units selected\nClick an army or drag to select."
		return
	var counts: Dictionary = {}
	for unit in roster:
		counts[unit.kind] = counts.get(unit.kind, 0) + 1
	var labels: PackedStringArray = []
	for kind in counts:
		labels.append("%s: %d" % [UnitCatalog.TYPES[kind]["name"], counts[kind]])
	var primary: UnitState = roster[0]
	var summary: String = labels[0] if counts.size() == 1 else "%d selected | %d unit types" % [roster.size(), counts.size()]
	selection_info.text = "%s\nLead: %.0f / %.0f HP | %s" % [summary, primary.health, primary.max_health, "Garrisoned" if primary.garrisoned else ("Holding" if primary.holding else ("Attacking" if primary.attack_order else "Mobile"))]
	if primary.kind == "supply_truck":
		selection_info.text += "\nCargo: %.0f / %.0f | %s | %.1fs" % [primary.supply_cargo, SupplyLogistics.CARGO_CAPACITY, primary.supply_task.replace("_", " ").capitalize(), primary.supply_timer]
		selection_info.text += "\nRight-click or tap a friendly deposit or Supply Center to assign."
	selection_info.tooltip_text = "%s\nLead unit: %.0f damage / %.2fs | Range %d\n%.2fs/hex" % [", ".join(labels), primary.damage, primary.cooldown, primary.attack_range, primary.seconds_per_hex]

func _set_command_cursors(node: Node) -> void:
	if node is BaseButton:
		node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for child in node.get_children():
		_set_command_cursors(child)


func show_tile_actions(hex: Vector2i, economy: EconomyState, territory: TerritoryState, tiles: Dictionary, roster: Array[UnitState] = []) -> void:
	if command_alert == null and _camera != null:
		command_alert = preload("res://scripts/ui/command_alert.gd").new()
		add_child(command_alert)
		command_alert.configure(_camera, _camera.get_parent().get_node("WorldMap"))
	if command_alert != null:
		command_alert.bind_economy(economy)
	if radar.territory != territory:
		radar.territory = territory
	for connection in primary_button.pressed.get_connections():
		primary_button.pressed.disconnect(connection["callable"])
	primary_button.pressed.connect(func() -> void:
		economy.set_primary(hex, territory)
		show_tile_actions(hex, economy, territory, tiles, roster)
	)
	primary_button.visible = economy.buildings.has(hex) and territory.owner_at(hex) == economy.faction and EconomyState.is_complete(economy.buildings[hex]) and economy.buildings[hex]["kind"] in ["barracks", "factory", "airfield", "shipyard"]
	primary_button.disabled = primary_button.visible and economy.buildings[hex].get("primary", false)
	primary_button.text = "Primary production" if primary_button.disabled else "Set primary production"
	_refresh_facilities(hex, economy, territory)
	var income: float = economy.income_last_seconds(60.0)
	var active_trucks: int = 0
	for unit in roster:
		if unit.faction == economy.faction and unit.kind == "supply_truck" and unit.is_alive() and unit.is_deployed():
			active_trucks += 1
	var source_status: String = "SOURCE ACTIVE" if economy.has_working_income_source() else "NO WORKING SOURCE"
	economy_summary.text = "%.2f CR | 60s +%.0f | TRK %d | OIL %d | %s" % [economy.credits, income, active_trucks, economy.oil_derrick_count, source_status]
	economy_summary.tooltip_text = "Available credits, approved income received in the last 60 seconds, active Supply Trucks and operational oil derricks. Oil contributes 3 CR/s plus continent bonus without trucks or roads. Truck cargo credits only after a completed Supply Center unload."
	economy_summary.add_theme_color_override("font_color", CommandTheme.POSITIVE if income > 0 else CommandTheme.WARNING)
	var power: Dictionary = economy.power_balance(territory)
	power_summary.text = "PWR %d / %d%s" % [power["supply"], power["demand"], " LOW" if economy.low_power(territory) else ""]
	power_summary.tooltip_text = "Power generated / consumed. Low power halves factory speed and pauses aircraft operations."
	power_summary.add_theme_color_override("font_color", CommandTheme.WARNING if economy.low_power(territory) else CommandTheme.TEXT)
	var continents: int = 0
	for region in territory.continents.regions:
		if territory.continents.controller(region) == economy.faction:
			continents += 1
	continent_summary.text = "CONTINENTS %d" % continents
	tactical_header.update_values({"credits": "%.2f" % economy.credits, "income": "60s +%.0f" % income, "power": "%d / %d" % [power["demand"], power["supply"]], "continents": "%d / %d" % [continents, territory.continents.regions.size()], "low_power": economy.low_power(territory)})
	rally_button.hide()
	cancel_construction_button.hide()
	repair_button.hide()
	sell_button.hide()
	_cancel_site = {}
	var has_building: bool = economy.buildings.has(hex) and territory.owner_at(hex) == economy.faction
	build_status.visible = has_building and not _army_selected
	training_progress.visible = has_building and not economy.buildings[hex]["queue"].is_empty()
	if training_progress.visible:
		var production: Dictionary = economy.buildings[hex]
		training_progress.value = 100.0 * production["elapsed"] / EconomyState.TRAIN_SECONDS[production["queue"][0]]
	context_title.text = "COMMAND"
	for kind in build_buttons:
		build_buttons[kind].visible = true
		build_buttons[kind].disabled = not economy.account.can_afford(EconomyState.BUILD_COSTS[kind])
		if kind == "headquarters":
			for building in economy.buildings.values():
				if building["kind"] == "headquarters":
					build_buttons[kind].disabled = true
		var requirement: String = "Controlled, uncontested empty land"
		if kind == "extractor":
			requirement = "Controlled resource deposit"
		elif kind == "headquarters":
			requirement += "; limit one HQ"
		elif kind == "airfield":
			requirement += "; plains, desert or city"
		elif kind == "shipyard":
			requirement += "; coast adjoining navigable ocean"
		var power_text: String = "+%d power" % EconomyState.POWER_SUPPLY[kind] if EconomyState.POWER_SUPPLY.has(kind) else "%d power used" % EconomyState.POWER_DEMAND.get(kind, 0)
		var unavailable: String = ""
		if build_buttons[kind].disabled:
			unavailable = "\nNeed %d CR" % EconomyState.BUILD_COSTS[kind] if not economy.account.can_afford(EconomyState.BUILD_COSTS[kind]) else "\nHQ limit reached"
		build_buttons[kind].update_status(requirement, "Low credits" if build_buttons[kind].disabled else "", build_buttons[kind].disabled)
		build_buttons[kind].tooltip_text = "%s\n%s%s" % [power_text, requirement, unavailable]
	for kind in train_buttons:
		var producer: Variant = production_target(kind, hex, economy, territory)
		var compatible: bool = producer != null
		train_buttons[kind].visible = true
		var blocked: bool = not compatible or not economy.account.can_afford(EconomyState.TRAIN_COSTS[kind]) or economy.buildings[producer]["queue"].size() >= 5
		if UnitCatalog.is_air(kind) and compatible:
			blocked = blocked or economy.low_power(territory) or territory.is_contested(producer)
		var requirement: String = "Requires completed %s" % UnitCatalog.producer(kind)
		var status: String = "Locked"
		var progress: float = -1
		if compatible:
			var site: Dictionary = economy.buildings[producer]
			requirement = "Production at (%d, %d), queue %d/5. Select a compatible factory to use its queue.\nQueued jobs cannot currently be cancelled." % [producer.x, producer.y, site["queue"].size()]
			status = "%d / 5 queued" % site["queue"].size()
			if not site["queue"].is_empty() and site["queue"][0] == kind:
				progress = site["elapsed"] / EconomyState.TRAIN_SECONDS[kind]
				status = "Training %d%%" % int(progress * 100)
			if not economy.account.can_afford(EconomyState.TRAIN_COSTS[kind]):
				status = "Insufficient credits"
			if UnitCatalog.is_air(kind) and (economy.low_power(territory) or territory.is_contested(producer)):
				status = "Airfield offline: power / contested"
		train_buttons[kind].update_status(requirement, status, blocked, progress)
	if has_building:
		var building: Dictionary = economy.buildings[hex]
		var queue: Array = building["queue"]
		if not EconomyState.is_complete(building):
			_cancel_hex = hex
			_cancel_site = building
			cancel_construction_button.text = "Cancel construction (+%d CR)" % int(EconomyState.BUILD_COSTS[building["kind"]] * EconomyState.CANCEL_REFUND_FRACTION)
			cancel_construction_button.show()
			training_progress.show()
			training_progress.value = 100.0 * building["construction"] / EconomyState.BUILD_SECONDS[building["kind"]]
			build_status.text = "Constructing %s: %.1f / %.0fs\nHP: %.0f / %.0f\n%s" % [building["kind"], building["construction"], EconomyState.BUILD_SECONDS[building["kind"]], building["health"], EconomyState.BUILD_HEALTH[building["kind"]], "Paused: contested" if territory.is_contested(hex) else "Not operational until complete"]
			return
		_cancel_hex = hex
		_cancel_site = building
		sell_button.text = "Sell building (+%d CR)" % int(EconomyState.BUILD_COSTS[building["kind"]] * EconomyState.SALVAGE_FRACTION)
		sell_button.show()
		repair_button.text = "Stop repairs" if building.get("repairing", false) else "Repair (1 CR / HP)"
		repair_button.visible = building.get("health", EconomyState.BUILD_HEALTH[building["kind"]]) < EconomyState.BUILD_HEALTH[building["kind"]] or building.get("repairing", false)
		build_status.text = "%s • (%d, %d)\nQueue: %d/5" % [String(building["kind"]).capitalize(), hex.x, hex.y, queue.size()]
		build_status.text += "\nHP: %.0f / %.0f" % [building.get("health", EconomyState.BUILD_HEALTH[building["kind"]]), EconomyState.BUILD_HEALTH[building["kind"]]]
		build_status.text += "\nPower: +%d supply / %d used" % [EconomyState.POWER_SUPPLY.get(building["kind"], 0), EconomyState.POWER_DEMAND.get(building["kind"], 0)]
		if building["kind"] in ["factory", "barracks", "airfield", "shipyard"]:
			rally_button.show()
			var rally: Vector2i = building["rally"]
			build_status.text += "\nRally: (%d, %d)\nJobs: %s" % [rally.x, rally.y, ", ".join(queue) if not queue.is_empty() else "Idle"]
		if building.get("repairing", false):
			build_status.text += "\nRepairing: 20 HP/s (pauses if unfunded or contested)"
		if not queue.is_empty():
			build_status.text += "\n%s: %.1f / %.0fs" % [queue[0], building["elapsed"], EconomyState.TRAIN_SECONDS[queue[0]]]
		elif building["kind"] == "headquarters":
			build_status.text += "\nCommand infrastructure only; no passive income.\nBuild barracks to train rifles."
		elif building["kind"] == "supply_center":
			build_status.text += "\n%s. Trucks unload cargo here in 2 seconds." % ("Operational" if economy.operational_supply_center(hex, territory) else "OFFLINE: restore power, control, health and uncontested status")
		elif building["kind"] == "extractor":
			build_status.text += "\nStrategic legacy structure; no passive income."
		elif building["kind"] == "power_plant":
			build_status.text += "\nSupply: 40 power\nHP: %.0f / 250" % building["health"]
		if building["kind"] == "factory" and economy.low_power(territory):
			build_status.text += "\nLOW POWER: production at 50%"
		if building["kind"] == "airfield":
			build_status.text += "\nAircraft available in Vehicles / Air. Fighters return here to rearm."
			if economy.low_power(territory):
				build_status.text += "\nLOW POWER: aircraft production and rearming paused"
	else:
		build_status.text = "Choose construction, then place on controlled empty land. Q rotates; Esc cancels."
		build_status.visible = false
	if has_building:
		build_status.visible = not _army_selected
	if _army_selected:
		for control in [primary_button, rally_button, cancel_construction_button, repair_button, sell_button, training_progress]:
			control.hide()


static func production_target(kind: String, selected_hex: Vector2i, economy: EconomyState, territory: TerritoryState) -> Variant:
	if economy.buildings.has(selected_hex) and territory.owner_at(selected_hex) == economy.faction:
		var site: Dictionary = economy.buildings[selected_hex]
		if site["kind"] == UnitCatalog.producer(kind) and EconomyState.is_complete(site):
			return selected_hex
	return economy.production_site(kind, territory)


func show_oil_site(hex: Vector2i, oil: OilDerrickNetwork, territory: TerritoryState, viewer_faction: int = 1) -> void:
	if not oil.sites.has(hex):
		return
	var site: Dictionary = oil.sites[hex]
	var owner: int = site.get("owner", 0)
	var operational: bool = oil.operational(hex, territory)
	var status: String = "OPERATIONAL" if operational else "OFFLINE"
	if site.get("health", 0.0) <= 0.0:
		status = "DESTROYED: owner retains site; repair to restore"
	elif site.get("contested", false) or territory.is_contested(hex):
		status = "CONTESTED: capture and income paused"
	elif site.get("capture_faction", 0) != 0:
		status = "CAPTURING %.1f / 5s: income paused" % site.get("capture_elapsed", 0.0)
	elif territory.owner_at(hex) != owner:
		status = "CONTROL DISPUTED: income paused"
	var contribution: float = OilDerrickNetwork.INCOME_PER_SECOND * 60.0 * (1.0 + territory.continents.bonus(owner)) if operational else 0.0
	supply_info.visible = not _army_selected
	supply_info.text = "OIL DERRICK | %s | %s\nHP %.0f / %.0f | +%.0f CR/min | 3 CR/s base, no road bonus" % [{0: "Neutral", 1: "Player", 2: "Rival"}.get(owner, "Unknown"), status, site.get("health", 0.0), OilDerrickNetwork.MAX_HEALTH, contribution]
	supply_info.add_theme_color_override("font_color", CommandTheme.POSITIVE if operational else CommandTheme.WARNING)
	if owner != viewer_faction:
		return
	_cancel_hex = hex
	_cancel_site = site
	repair_button.text = "Stop oil repairs" if site.get("repairing", false) else "Repair oil derrick (1 CR / HP)"
	repair_button.visible = not _army_selected and (site.get("health", 0.0) < OilDerrickNetwork.MAX_HEALTH or site.get("repairing", false))
	build_status.text = "Oil derrick • (%d, %d)\nHP: %.0f / %.0f\n%s\nContribution: +%.0f CR/min" % [hex.x, hex.y, site.get("health", 0.0), OilDerrickNetwork.MAX_HEALTH, status, contribution]
	if site.get("repairing", false):
		build_status.text += "\nRepairing: 20 HP/s; paused if unfunded or contested"
	build_status.visible = not _army_selected


func show_supply(hex: Vector2i, economy: EconomyState, territory: TerritoryState, tiles: Dictionary) -> void:
	show_continents(territory.continents)
	var bunker: bool = economy.buildings.has(hex) and economy.buildings[hex]["kind"] == "bunker"
	supply_info.visible = tiles.has(hex) and not _army_selected
	if not tiles.has(hex):
		return
	var status: Dictionary = economy.income_status(hex, tiles, territory)
	if bunker:
		supply_info.text = "%s | Bunker holds two infantry\nGarrison protection does not require supply" % ("SUPPLIED" if status["supplied"] else "ISOLATED")
		return
	var owner: int = territory.owner_at(hex)
	var tile: Dictionary = tiles[hex]
	var detail: String = ""
	if tile.has("supply_id"):
		detail = "\n%s deposit: %.0f / %.0f remaining%s" % [String(tile.get("supply_size", "medium")).capitalize(), tile.get("supply_remaining", 0.0), tile.get("supply_capacity", 0.0), " | DEPLETED" if tile.get("supply_remaining", 0.0) <= 0.0 else ""]
	if economy.buildings.has(hex) and economy.buildings[hex].get("kind", "") == "supply_center":
		detail += "\nSupply Center: %s" % ("OPERATIONAL" if economy.operational_supply_center(hex, territory) else "OFFLINE")
	supply_info.text = "%s | %s | Physical delivery income\n%s%s%s" % [{0: "Neutral", 1: "Player", 2: "Rival"}.get(owner, "Faction %d" % owner), "SUPPLIED" if status["supplied"] else "NO SUPPLY", "Road present" if RoadRules.has_road(tiles, hex) else "No road", " | Actual all-road delivery earns +10%" if status["road_route"] else "", detail]
	supply_info.add_theme_color_override("font_color", CommandTheme.TEXT if status["supplied"] or owner == 0 else CommandTheme.WARNING)


func _refresh_facilities(selected_hex: Vector2i, economy: EconomyState, territory: TerritoryState) -> void:
	var power: Dictionary = economy.power_balance(territory)
	var count: int = 0
	var queues: PackedStringArray = []
	for hex in facility_buttons.keys():
		if not economy.buildings.has(hex) or territory.owner_at(hex) != economy.faction:
			var removed: Button = facility_buttons[hex]
			facility_list.remove_child(removed)
			removed.queue_free()
			facility_buttons.erase(hex)
	for hex in economy.buildings:
		if territory.owner_at(hex) != economy.faction:
			continue
		count += 1
		if not facility_buttons.has(hex):
			var button: Button = Button.new()
			button.custom_minimum_size.y = 44
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.toggle_mode = true
			button.pressed.connect(func() -> void: facility_selected.emit(hex))
			facility_list.add_child(button)
			facility_buttons[hex] = button
		var site: Dictionary = economy.buildings[hex]
		var kind: String = site["kind"]
		var status: String = "Idle"
		if not EconomyState.is_complete(site):
			status = "Construction %d%%" % int(100.0 * site["construction"] / EconomyState.BUILD_SECONDS[kind])
		elif not site["queue"].is_empty():
			status = "%s %.1f/%ds; %d queued" % [site["queue"][0], site["elapsed"], EconomyState.TRAIN_SECONDS[site["queue"][0]], site["queue"].size()]
			queues.append("%s (%d,%d): %s %.0f%% | %d queued%s" % [kind.capitalize(), hex.x, hex.y, UnitCatalog.TYPES[site["queue"][0]]["name"], 100.0 * site["elapsed"] / EconomyState.TRAIN_SECONDS[site["queue"][0]], site["queue"].size(), " | LOW POWER" if economy.low_power(territory) and kind == "factory" else ""])
		if site.get("repairing", false):
			status += " | Repair %.0f HP%s" % [site["health"], " (no funds)" if economy.credits <= 0 else ""]
		if territory.is_contested(hex):
			status += " | Contested"
		if economy.low_power(territory) and kind == "factory":
			status += " | 50% speed"
		facility_buttons[hex].text = "%s (%d, %d)\n%s" % [kind.capitalize(), hex.x, hex.y, status]
		facility_buttons[hex].set_pressed_no_signal(hex == selected_hex)
	economy_summary.text = "%.2f CR" % economy.credits
	power_gauge.set_balance(power["supply"], power["demand"])
	production_queue.text = "\n".join(queues) if not queues.is_empty() else "No active production"
	production_queue.get_parent().custom_minimum_size.y = 64
	production_meter.value = 0
	for site_hex in economy.buildings:
		var queued_site: Dictionary = economy.buildings[site_hex]
		if territory.owner_at(site_hex) == economy.faction and not queued_site["queue"].is_empty():
			production_meter.value = 100.0 * queued_site["elapsed"] / EconomyState.TRAIN_SECONDS[queued_site["queue"][0]]
			break
	if count == 0:
		economy_summary.tooltip_text = "No controlled structures"


func _apply_strategy_theme() -> void:
	theme = CommandTheme.create()
	for panel_node in [header_panel, controls_panel, help_panel]:
		panel_node.remove_theme_stylebox_override("panel")
	for button in [zoom_in_button, zoom_out_button, home_button]:
		button.remove_theme_stylebox_override("normal")
		button.remove_theme_stylebox_override("hover")


func _ui_box(fill: Color, border: Color, radius: int) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.content_margin_left = 10
	box.content_margin_right = 10
	box.content_margin_top = 6
	box.content_margin_bottom = 6
	return box

func show_continents(manager: ContinentControl) -> void:
	if _continent_manager == manager and _continent_revision == manager.revision:
		return
	_continent_manager = manager
	_continent_revision = manager.revision
	var lines: PackedStringArray = ["CONTINENTS", "Player +%d%% | Rival +%d%% on qualifying delivery and oil payouts" % [roundi(manager.bonus(1) * 100), roundi(manager.bonus(2) * 100)]]
	for name in manager.regions:
		var region: Dictionary = manager.regions[name]
		var total: int = region["total"]
		if total == 0:
			lines.append("%s: excluded (unreachable)" % name)
			continue
		var owner: int = manager.controller(name)
		var label: String = "Player" if owner == 1 else ("Rival" if owner == 2 else "None")
		lines.append("%s: %s%s" % [name, label, " (+10%)" if owner > 0 else ""])
		for faction in [1, 2]:
			var count: int = region["counts"].get(faction, 0)
			lines.append("%s %d/%d (%d remain)" % ["Player" if faction == 1 else "Rival", count, total, total - count])
	continent_overview.text = "\n".join(lines)
