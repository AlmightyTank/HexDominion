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
var _box_active: bool = false
var _selection_box: ReferenceRect
var _menu_open: bool = false
const TAP_THRESHOLD: float = 14.0


func _ready() -> void:
	hud.bind_camera(camera)
	camera.configure_world_bounds(world_map.world_bounds())
	hud.show_world_stats(world_map.map_data)
	units = UnitLayer.new()
	units.name = "Units"
	add_child(units)
	units.configure(world_map)
	hud.build_requested.connect(_begin_build)
	hud.train_requested.connect(_train_selected)
	hud.match_action_requested.connect(_match_action)
	hud.save_slot_requested.connect(_save_slot)
	hud.load_slot_requested.connect(_load_slot)
	_selection_box = ReferenceRect.new()
	_selection_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_box.editor_only = false
	_selection_box.border_color = Color("65ebd0")
	_selection_box.border_width = 2.0
	_selection_box.hide()
	hud.add_child(_selection_box)


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _menu_open and hud.save_browser.visible:
			hud.close_save_browser()
		else:
			_set_menu_open(not _menu_open)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var actions: Dictionary = {KEY_F5: "save", KEY_F9: "load", KEY_F10: "restart"}
		if actions.has(event.keycode):
			_match_action(actions[event.keycode])
			get_viewport().set_input_as_handled()
			return
	if _menu_open:
		return
	if units.match_state.result != "playing":
		_box_active = false
		_selection_box.hide()
		return
	# Finish even when a drag is released over a HUD panel.
	if _box_active and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_box_active = false
		_selection_box.hide()
		if maxf(_mouse_max_travel, event.position.distance_to(_mouse_press)) >= TAP_THRESHOLD:
			units.select_box(Rect2(_mouse_press, event.position - _mouse_press), get_viewport().get_canvas_transform())
			hud.show_command_info("%d units selected • Right-click move • Esc menu" % units.selected_units.size())
		else:
			_select_at(get_global_mouse_position())
		get_viewport().set_input_as_handled()
	elif _box_active and event is InputEventMouseMotion:
		_mouse_max_travel = maxf(_mouse_max_travel, event.position.distance_to(_mouse_press))
		var rect: Rect2 = Rect2(_mouse_press, event.position - _mouse_press).abs()
		_selection_box.position = rect.position
		_selection_box.size = rect.size
		_selection_box.visible = _mouse_max_travel >= TAP_THRESHOLD


func _unhandled_input(event: InputEvent) -> void:
	if _menu_open or units.match_state.result != "playing":
		return
	if not units.build_kind.is_empty():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_begin_build("")
			return
		if event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			if event.pressed:
				if event.button_index == MOUSE_BUTTON_RIGHT:
					_begin_build("")
				else:
					_place_build(get_global_mouse_position())
			get_viewport().set_input_as_handled()
			return
		if event is InputEventScreenTouch:
			if not event.pressed:
				_place_build(get_viewport().get_canvas_transform().affine_inverse() * event.position)
			return
	if event is InputEventKey and event.pressed and not event.echo:
		var hex: Vector2i = world_map.selected_hex
		var build_keys: Dictionary = {KEY_H: "headquarters", KEY_B: "barracks", KEY_F: "factory"}
		var train_keys: Dictionary = {KEY_I: "rifle", KEY_T: "tank"}
		if build_keys.has(event.keycode):
			_begin_build(build_keys[event.keycode])
		elif train_keys.has(event.keycode):
			var accepted: bool = units.economy.train(hex, train_keys[event.keycode], units.territory)
			hud.show_command_info("Training queued" if accepted else "Training rejected: select correct owned building, need credits/queue space")
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
			_box_active = true
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
		units.select_one(null)
		_box_active = false
		_selection_box.hide()
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
	var hex: Vector2i = world_map.world_to_hex(world_point)
	if units.economy.buildings.has(hex):
		var building: Dictionary = units.economy.buildings[hex]
		hud.show_command_info("%s • Queue %d/5 • I rifle / T tank • Deselect units then right-click rally" % [String(building["kind"]).capitalize(), building["queue"].size()])


func _select_at(point: Vector2) -> void:
	units.select_one(units.pick(point, camera.zoom.x))
	units.queue_redraw()
	_inspect_world_at(point)
	if units.selected != null:
		hud.show_command_info("%s • %s • Right-click move • G garrison" % [units.selected.title, "Garrisoned" if units.selected.garrisoned else "Mobile"])


func _move_to(point: Vector2) -> void:
	if units.selected == null:
		if units.economy.buildings.has(world_map.selected_hex):
			var accepted: bool = units.economy.set_rally(world_map.selected_hex, world_map.world_to_hex(point), world_map.map_data["tiles"], units.territory)
			hud.show_command_info("Rally point set" if accepted else "Rally rejected: need owned building and reachable land")
			return
		hud.show_command_info("Select a squad first (teal markers)")
		return
	var ordered: int = 0
	var group: Array[UnitState] = units.selected_units.duplicate()
	if group.is_empty():
		group.append(units.selected)
	for unit in group:
		if unit.order_move(world_map.map_data["tiles"], world_map.world_to_hex(point)):
			ordered += 1
	units.queue_redraw()
	if ordered > 0:
		hud.show_command_info("Move accepted: %d/%d units • Garrisoned/unreachable units keep orders" % [ordered, group.size()])
	else:
		hud.show_command_info("Garrisoned or no land route • Release with G • Previous order unchanged")


func _process(_delta: float) -> void:
	if units != null:
		hud.show_tile_actions(world_map.selected_hex, units.economy, units.territory, world_map.map_data["tiles"])
		hud.show_match_status(units.match_state)
		if units.match_state.rival_economy.buildings.has(world_map.selected_hex):
			hud.build_panel.hide() # Rival structures are not transferred or rebuilt over.
		units.build_hex = world_map.world_to_hex(get_global_mouse_position())
		for kind in hud.build_buttons:
			var blocked: bool = not units.economy.account.can_afford(EconomyState.BUILD_COSTS[kind])
			if kind == "headquarters":
				for building in units.economy.buildings.values():
					blocked = blocked or building["kind"] == "headquarters"
			hud.build_buttons[kind].disabled = blocked
		hud.world_stats_label.text = "%d CR   |   +%.0f / SEC" % [int(units.economy.credits), units.economy.income_rate(world_map.map_data["tiles"], units.territory)]


func _begin_build(kind: String) -> void:
	if _menu_open or units.match_state.result != "playing":
		return
	units.build_kind = ""
	_box_active = false
	_selection_box.hide()
	if kind.is_empty():
		return
	if units.match_state.rival_economy.buildings.has(world_map.selected_hex):
		hud.show_command_info("Rival structure: production disabled when captured")
		return
	var accepted: bool = units.economy.build(world_map.selected_hex, kind, world_map.map_data["tiles"], units.territory)
	hud.show_command_info("Building constructed on selected tile" if accepted else "Cannot build here: select owned empty land and check credits")
	hud.show_tile_actions(world_map.selected_hex, units.economy, units.territory, world_map.map_data["tiles"])


func _train_selected(kind: String) -> void:
	if _menu_open or units.match_state.result != "playing":
		return
	var accepted: bool = units.economy.train(world_map.selected_hex, kind, units.territory)
	hud.show_command_info("Training queued" if accepted else "Training unavailable: check building, credits and queue")


func _set_menu_open(open: bool) -> void:
	_menu_open = open
	_box_active = false
	_selection_box.hide()
	_touch_start.clear()
	_touch_gesture = true
	_mouse_max_travel = TAP_THRESHOLD
	_right_max_travel = TAP_THRESHOLD
	units.build_kind = ""
	units.set_physics_process(not open)
	camera.set_process(not open)
	camera.set_process_unhandled_input(not open)
	# Do not resume a held mouse drag or pinch after closing the modal.
	camera.restore_view(camera.position, camera.zoom)
	hud.show_pause_menu(open)


func _match_action(action: String) -> void:
	if action == "resume":
		_set_menu_open(false)
		return
	_box_active = false
	_selection_box.hide()
	_touch_start.clear()
	_touch_gesture = true
	_mouse_max_travel = TAP_THRESHOLD
	_right_max_travel = TAP_THRESHOLD
	if action == "restart":
		_restart_match.call_deferred()
	elif action in ["save", "load"]:
		_set_menu_open(true)
		hud.show_save_browser(action, MatchSave.list_slots(world_map.map_data["tiles"]))


func _save_slot(title: String, path: String) -> void:
	var snapshot: Dictionary = MatchSave.capture(units, camera.position, camera.zoom, world_map.selected_hex)
	var outcome: Dictionary = MatchSave.write_slot(snapshot, world_map.map_data["tiles"], title, path)
	if outcome["error"] != OK:
		hud.save_message.text = "Save failed: " + error_string(outcome["error"])
		return
	hud.show_save_browser("save", MatchSave.list_slots(world_map.map_data["tiles"]))
	hud.save_message.text = "Saved: " + title


func _load_slot(path: String) -> void:
	var snapshot: Dictionary = MatchSave.read_valid(world_map.map_data["tiles"], path)
	if snapshot.is_empty() or not MatchSave.restore(units, snapshot):
		hud.save_message.text = "Save unavailable or incompatible. Match unchanged."
		return
	_set_menu_open(false)
	camera.restore_view(snapshot["camera_position"], snapshot["camera_zoom"])
	world_map.inspect_at_world(world_map.hex_to_world(snapshot["inspected"]))
	hud.show_command_info("Loaded: " + String(snapshot.get("save_name", "Legacy quicksave")))


func _restart_match() -> void:
	var error: Error = get_tree().reload_current_scene()
	if error != OK:
		hud.show_command_info("Restart failed: " + error_string(error))


func _place_build(point: Vector2) -> void:
	var hex: Vector2i = world_map.world_to_hex(point)
	if units.economy.build(hex, units.build_kind, world_map.map_data["tiles"], units.territory):
		world_map.inspect_at_world(point)
		_begin_build("")
		hud.show_command_info("Building placed • I rifle / T tank at selected building")
	else:
		hud.build_status.text = "Blocked: need owned empty land,\ncredits, and no duplicate HQ"
