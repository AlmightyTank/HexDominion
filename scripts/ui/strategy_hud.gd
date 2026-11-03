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
signal match_action_requested(action: String)
var match_panel: PanelContainer
var match_label: Label
var pause_overlay: Control
var resume_button: Button
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


func _ready() -> void:
	_apply_strategy_theme()
	_create_build_menu()
	_create_match_menu()
	$Header/Margin/Content/Subtitle.text = "STRATEGIC COMMAND  /  PLAYER FACTION"
	$Help/Margin/Content/HelpTitle.text = "FIELD ORDERS"
	$Help/Margin/Content/DesktopHelp.text = "LEFT DRAG  Select • RIGHT CLICK  Move / rally"
	$Help/Margin/Content/TouchHelp.text = "MIDDLE / RIGHT DRAG  Pan • WHEEL  Zoom • G  Garrison"
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
	var stacked: bool = viewport_size.x < 1100.0
	if match_panel != null:
		match_panel.position = Vector2(12.0 if stacked else (viewport_size.x - 360.0) / 2.0, 220.0 if narrow else (150.0 if stacked else 18.0))
		match_panel.size.x = minf(360.0, viewport_size.x - 24.0)
	if build_panel != null:
		build_panel.position = Vector2(maxf(12.0, viewport_size.x - 292.0), 350.0 if narrow else (280.0 if stacked else 102.0))
		build_panel.size.x = minf(274.0, viewport_size.x - 24.0)
	for panel in [header_panel, controls_panel, help_panel]:
		panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	if narrow:
		header_panel.position = Vector2(12.0, 12.0)
		header_panel.size = Vector2(minf(312.0, viewport_size.x - 24.0), 120.0)
		controls_panel.position = Vector2(12.0, 143.0)
		controls_panel.size = Vector2(minf(288.0, viewport_size.x - 24.0), 66.0)
		help_panel.position = Vector2(12.0, viewport_size.y - 178.0)
		help_panel.size = Vector2(minf(437.0, viewport_size.x - 24.0), 160.0)
	else:
		header_panel.position = Vector2(18.0, 18.0)
		header_panel.size = Vector2(312.0, 120.0)
		controls_panel.position = Vector2(viewport_size.x - 306.0, 18.0)
		controls_panel.size = Vector2(288.0, 66.0)
		help_panel.position = Vector2(18.0, viewport_size.y - 178.0)
		help_panel.size = Vector2(minf(540.0, viewport_size.x - 36.0), 160.0)


func _create_match_menu() -> void:
	match_panel = PanelContainer.new()
	match_panel.name = "MatchControls"
	add_child(match_panel)
	var column: VBoxContainer = VBoxContainer.new()
	match_panel.add_child(column)
	match_label = Label.new()
	match_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(match_label)
	var hint: Label = Label.new()
	hint.text = "ESC  •  Match menu"
	column.add_child(hint)
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
	var title: String = "CAPTURE THE RIVAL HQ"
	if match_state.result != "playing":
		title = match_state.result.to_upper() + " • Match ended"
	match_label.text = "%s\nYour HQ (%d,%d) • Rival HQ (%d,%d)" % [title, match_state.player_hq.x, match_state.player_hq.y, match_state.rival_hq.x, match_state.rival_hq.y]
	match_label.add_theme_color_override("font_color", Color("f08075") if match_state.result == "defeat" else Color("65ebd0"))
	if match_state.result != "playing":
		build_panel.hide()


func _create_build_menu() -> void:
	build_panel = PanelContainer.new()
	build_panel.name = "BuildMenu"
	add_child(build_panel)
	var margin: MarginContainer = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 10)
	build_panel.add_child(margin)
	var column: VBoxContainer = VBoxContainer.new()
	margin.add_child(column)
	var title: Label = Label.new()
	context_title = title
	title.text = "CONSTRUCTION"
	column.add_child(title)
	title.add_theme_color_override("font_color", Color("65ebd0"))
	title.add_theme_font_size_override("font_size", 19)
	var divider: HSeparator = HSeparator.new()
	column.add_child(divider)
	for kind in ["headquarters", "barracks", "factory"]:
		var button: Button = Button.new()
		button.text = "%s  |  %d CR" % [String(kind).capitalize(), EconomyState.BUILD_COSTS[kind]]
		button.custom_minimum_size.y = 44
		button.tooltip_text = {"headquarters": "Command center • +5 credits/sec • Limit: one", "barracks": "Train rifle squads • 50 credits • 4 seconds", "factory": "Produce main battle tanks • 150 credits • 8 seconds"}[kind]
		button.pressed.connect(func() -> void: build_requested.emit(kind))
		column.add_child(button)
		build_buttons[kind] = button
	build_status = Label.new()
	build_status.text = "Choose a building"
	build_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(build_status)
	build_status.add_theme_color_override("font_color", Color("a8bbc9"))
	training_progress = ProgressBar.new()
	training_progress.custom_minimum_size.y = 12
	training_progress.show_percentage = false
	column.add_child(training_progress)
	for kind in ["rifle", "tank"]:
		var button: Button = Button.new()
		button.text = "%s • %d • %ds" % ["Rifle squad" if kind == "rifle" else "Tank", EconomyState.TRAIN_COSTS[kind], EconomyState.TRAIN_SECONDS[kind]]
		button.custom_minimum_size.y = 34
		button.pressed.connect(func() -> void: train_requested.emit(kind))
		column.add_child(button)
		train_buttons[kind] = button
	build_panel.hide()


func show_tile_actions(hex: Vector2i, economy: EconomyState, territory: TerritoryState, tiles: Dictionary) -> void:
	build_panel.visible = territory.owner_at(hex) == 1 and HexPathfinding.is_walkable(tiles, hex)
	if not build_panel.visible:
		return
	var has_building: bool = economy.buildings.has(hex)
	training_progress.visible = has_building and not economy.buildings[hex]["queue"].is_empty()
	if training_progress.visible:
		var production: Dictionary = economy.buildings[hex]
		training_progress.value = 100.0 * production["elapsed"] / EconomyState.TRAIN_SECONDS[production["queue"][0]]
	context_title.text = "TRAINING" if has_building else "CONSTRUCTION"
	for kind in build_buttons:
		build_buttons[kind].visible = not has_building
		build_buttons[kind].disabled = not economy.can_build(hex, kind, tiles, territory)
	for kind in train_buttons:
		var compatible: bool = has_building and economy.buildings[hex]["kind"] == ("barracks" if kind == "rifle" else "factory")
		train_buttons[kind].visible = compatible
		train_buttons[kind].disabled = not compatible or not economy.account.can_afford(EconomyState.TRAIN_COSTS[kind]) or economy.buildings[hex]["queue"].size() >= 5
	if has_building:
		var building: Dictionary = economy.buildings[hex]
		var queue: Array = building["queue"]
		build_status.text = "%s • (%d, %d)\nQueue: %d/5" % [String(building["kind"]).capitalize(), hex.x, hex.y, queue.size()]
		if not queue.is_empty():
			build_status.text += "\n%s: %.1f / %.0fs" % [queue[0], building["elapsed"], EconomyState.TRAIN_SECONDS[queue[0]]]
		elif building["kind"] == "headquarters":
			build_status.text += "\nIncome: +5 credits/s\nBuild barracks to train rifles."
	else:
		build_status.text = "Owned land • (%d, %d)\nChoose a building for this tile." % [hex.x, hex.y]


func _apply_strategy_theme() -> void:
	var skin: Theme = Theme.new()
	skin.default_font_size = 13
	skin.set_color("font_color", "Label", Color("e5edf4"))
	var panel: StyleBoxFlat = _ui_box(Color("101e2d"), Color("30495d"), 10)
	panel.shadow_color = Color(0, 0, 0, 0.35)
	panel.shadow_size = 8
	skin.set_stylebox("panel", "PanelContainer", panel)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		var fill: Color = Color("1c3245")
		var border: Color = Color("38556b")
		if state == "hover" or state == "focus":
			fill = Color("274c5b")
			border = Color("65ebd0")
		elif state == "pressed":
			fill = Color("176251")
		elif state == "disabled":
			fill = Color("152332")
			border = Color("243646")
		skin.set_stylebox(state, "Button", _ui_box(fill, border, 6))
	skin.set_color("font_color", "Button", Color("e5edf4"))
	skin.set_color("font_disabled_color", "Button", Color("697e90"))
	skin.set_constant("separation", "VBoxContainer", 9)
	skin.set_stylebox("background", "ProgressBar", _ui_box(Color("091420"), Color("30495d"), 4))
	skin.set_stylebox("fill", "ProgressBar", _ui_box(Color("49c9aa"), Color("65ebd0"), 4))
	theme = skin
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
