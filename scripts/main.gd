extends Node2D
## Selection, construction and unit orders, independent of camera dragging.

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
const NO_FACILITY: Vector2i = Vector2i(-99999, -99999)
var _facility_hex: Vector2i = NO_FACILITY
var _facility_site: Dictionary = {}
var _rally_mode: bool = false
var _attack_mode: bool = false
var _move_mode: bool = false
var _transport_mode: String = ""
const TAP_THRESHOLD: float = 14.0


func _ready() -> void:
	RenderingServer.set_default_clear_color(WorldMap.COLOR_OUTER)
	hud.bind_camera(camera)
	camera.configure_world_bounds(world_map.world_bounds())
	hud.show_world_stats(world_map.map_data)
	units = UnitLayer.new()
	units.name = "Units"
	add_child(units)
	units.configure(world_map)
	hud.build_requested.connect(_begin_build)
	hud.train_requested.connect(_train_selected)
	hud.facility_selected.connect(_select_facility)
	hud.rally_requested.connect(_begin_rally)
	hud.defensive_order_requested.connect(_defensive_order)
	hud.stack_requested.connect(_stack_action)
	hud.cancel_construction_requested.connect(_cancel_construction)
	hud.building_action_requested.connect(_building_action)
	hud.match_action_requested.connect(_match_action)
	hud.save_slot_requested.connect(_save_slot)
	hud.load_slot_requested.connect(_load_slot)
	hud.show_command_info("Click/tap selects a hex army. Use its panel to select a type or expand individuals. Shift-click adds stacks. Right-click enemies attacks. J holds, G garrisons; L loads and U unloads APCs.")
	_selection_box = ReferenceRect.new()
	_selection_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_selection_box.editor_only = false
	_selection_box.border_color = Color("65ebd0")
	_selection_box.border_width = 2.0
	_selection_box.hide()
	hud.add_child(_selection_box)


func _defensive_order(action: String) -> void:
	if _menu_open or units.match_state.result != "playing":
		return
	if action == "add_select":
		return
	_move_mode = action == "move" and not units.selected_units.is_empty()
	if _move_mode:
		_attack_mode = false
		_rally_mode = false
		units.build_kind = ""
		hud.show_command_info("Choose a movement destination. Esc cancels.")
		return
	_transport_mode = ""
	if action in ["load", "unload"]:
		_transport_mode = action
		_attack_mode = false
		_rally_mode = false
		units.build_kind = ""
		hud.show_command_info("Load: select coastal infantry/vehicles, then click a friendly landing craft; APCs load same-hex infantry." if action == "load" else "Unload: choose clear adjacent coastal land; APCs also unload on their own hex. Esc cancels.")
		return
	if action == "attack":
		_attack_mode = not _attack_mode and not units.selected_units.is_empty()
		_rally_mode = false
		units.build_kind = ""
		hud.show_command_info("Tap/click an enemy unit or building. Esc cancels." if _attack_mode else "Attack selection cancelled")
		return
	_attack_mode = false
	var accepted: int = 0
	for unit in units.selected_units:
		if action == "hold":
			unit.order_hold()
			accepted += 1
		elif action == "garrison":
			if unit.garrisoned:
				unit.garrisoned = false
				accepted += 1
			elif FortificationRules.assign(unit, units.economy, units.territory, units.units):
				accepted += 1
	hud.show_command_info("%s: %d accepted. Garrison needs completed friendly bunker, stationary infantry, two slots. Move cancels hold." % [action.capitalize(), accepted])
	units.queue_redraw()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if _move_mode:
			_move_mode = false
			hud.show_command_info("Movement selection cancelled")
		elif not _transport_mode.is_empty():
			_transport_mode = ""
			hud.show_command_info("Transport order cancelled")
		elif _attack_mode:
			_attack_mode = false
			hud.show_command_info("Attack selection cancelled")
		elif _rally_mode:
			_rally_mode = false
			hud.show_command_info("Rally selection cancelled")
		elif not _menu_open and not units.build_kind.is_empty():
			_begin_build("")
		elif _menu_open and hud.save_browser.visible:
			hud.close_save_browser()
		elif not _menu_open and hud.mobile_layout and hud.production_open:
			hud.production_open = false
			hud._layout_for_viewport()
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
		if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
			units.build_rotation = (units.build_rotation + 1) % 6
			units.queue_redraw()
			get_viewport().set_input_as_handled()
			return
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
	if event is InputEventKey and event.pressed and not event.echo:
		var build_keys: Dictionary = {KEY_H: "headquarters", KEY_B: "barracks", KEY_F: "factory", KEY_E: "extractor", KEY_P: "power_plant"}
		var train_keys: Dictionary = {KEY_I: "rifle", KEY_T: "tank"}
		if build_keys.has(event.keycode):
			_begin_build(build_keys[event.keycode])
		elif train_keys.has(event.keycode):
			_train_selected(train_keys[event.keycode])
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
		_defensive_order("hold")
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_G:
		_defensive_order("garrison")
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_X:
		_defensive_order("attack")
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_L, KEY_U]:
		_defensive_order("load" if event.keycode == KEY_L else "unload")
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
				if not units.build_kind.is_empty():
					_place_build(world_point)
				elif _attack_mode or units.pick_faction(world_point, camera.zoom.x, 2) != null:
					_move_to(world_point)
				elif units.pick(world_point, camera.zoom.x) != null or units.selected == null:
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
		if units.territory.owner_at(hex) == units.economy.faction:
			_facility_hex = hex
			_facility_site = building
		hud.show_command_info("%s • Queue %d/5 • Manage pinned facility in sidebar • I rifle / T tank" % [String(building["kind"]).capitalize(), building["queue"].size()])


func _select_at(point: Vector2) -> void:
	if _move_mode:
		_move_to(point)
		return
	if not _transport_mode.is_empty():
		_transport_at(point)
		return
	if _attack_mode:
		_attack_at(point)
		return
	if _rally_mode:
		_set_facility_rally(point)
		return
	var picked: UnitState = units.pick_faction(point, camera.zoom.x, 1, true)
	if hud.add_selection_button.button_pressed or Input.is_key_pressed(KEY_SHIFT):
		if picked != null:
			var members: Array[UnitState] = _hex_members(picked.hex).filter(func(member: UnitState) -> bool: return member.domain == picked.domain and (picked.domain == "ground" or member.kind == picked.kind))
			var remove: bool = true
			for member in members:
				remove = remove and units.selected_units.has(member)
			for member in members:
				if remove == units.selected_units.has(member):
					units.toggle_selection(member)
	else:
		units.select_one(picked)
		if picked != null and picked.hex != units.expanded_hex:
			units.selected_units = _hex_members(picked.hex).filter(func(member: UnitState) -> bool: return member.domain == picked.domain and (picked.domain == "ground" or member.kind == picked.kind))
	units.queue_redraw()
	_inspect_world_at(world_map.hex_to_world(picked.hex) if picked != null else point)
	if units.selected != null:
		hud.show_command_info("%s • %s • Right-click move • J hold • G garrison" % [units.selected.title, "Garrisoned" if units.selected.garrisoned else ("Holding" if units.selected.holding else "Mobile")])


func _move_to(point: Vector2) -> void:
	if not _transport_mode.is_empty():
		_transport_at(point)
		return
	if _rally_mode:
		_set_facility_rally(point)
		return
	var enemy: UnitState = units.pick_faction(point, camera.zoom.x, 2)
	if _attack_mode or (units.selected != null and (enemy != null or units.match_state.rival_economy.buildings.has(world_map.world_to_hex(point)))):
		_attack_at(point, enemy)
		return
	if units.selected == null:
		if units.economy.buildings.has(_economy_hex()):
			var accepted: bool = units.economy.set_rally(_economy_hex(), world_map.world_to_hex(point), world_map.map_data["tiles"], units.territory)
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
		_move_mode = false
		hud.show_command_info("Move accepted: %d/%d units. Unreachable units keep orders." % [ordered, group.size()])
	else:
		hud.show_command_info("No land route. Previous order unchanged.")

func _attack_at(point: Vector2, target: UnitState = null) -> void:
	if target == null:
		target = units.pick_faction(point, camera.zoom.x, 2)
	var goal: Vector2i = target.hex if target != null else world_map.world_to_hex(point)
	if target == null and not units.match_state.rival_economy.buildings.has(goal):
		hud.show_command_info("Choose an enemy unit or building. Esc cancels.")
		return
	var accepted: int = 0
	for unit in units.selected_units:
		if UnitOrders.attack(unit, world_map.map_data["tiles"], goal, target):
			accepted += 1
	if accepted > 0:
		_attack_mode = false
	units.queue_redraw()
	hud.show_command_info("Attack: %d orders accepted. Move or Hold cancels pursuit." % accepted)

func _transport_at(point: Vector2) -> void:
	var accepted: int = 0
	if _transport_mode == "load":
		var apc: UnitState = units.pick_faction(point, camera.zoom.x, 1)
		if apc != null and TransportRules.capacity(apc) == 0:
			var hex: Vector2i = apc.hex
			apc = null
			for candidate in _hex_members(hex):
				if TransportRules.capacity(candidate) > 0 and candidate.path.is_empty() and TransportRules.used(candidate, units.units) < TransportRules.capacity(candidate):
					apc = candidate
					break
		if apc != null and TransportRules.capacity(apc) > 0:
			for unit in units.selected_units.duplicate():
				if TransportRules.load(unit, apc, units.units, world_map.map_data["tiles"]):
					accepted += 1
			if accepted > 0:
				units.select_one(apc)
	else:
		for unit in units.selected_units:
			if TransportRules.unload(unit, world_map.world_to_hex(point), world_map.map_data["tiles"], units.units):
				accepted += 1
	if accepted > 0:
		_transport_mode = ""
	units.queue_redraw()
	hud.show_command_info("Transport: %d accepted." % accepted if accepted > 0 else "Need a stationary friendly carrier and free capacity. APC: same hex; landing craft: adjacent clear coastal land. Esc cancels.")

func _hex_members(hex: Vector2i) -> Array[UnitState]:
	var members: Array[UnitState] = []
	for unit in units.units:
		if unit.is_deployed() and unit.faction == 1 and unit.hex == hex:
			members.append(unit)
	return members

func _stack_action(kind: String) -> void:
	if _menu_open or units.selected == null:
		return
	var hex: Vector2i = units.selected.hex
	if kind == "expand":
		units.expanded_hex = Vector2i(-99999, -99999) if units.expanded_hex == hex else hex
	else:
		var members: Array[UnitState] = _hex_members(hex)
		units.selected_units.clear()
		for member in members:
			if kind == "all" or member.kind == kind:
				units.selected_units.append(member)
		units.selected = units.selected_units[0] if not units.selected_units.is_empty() else null
	units.queue_redraw()


func _process(_delta: float) -> void:
	if units != null:
		hud.show_selection(units.selected_units, _attack_mode, units.units)
		if units.selected != null and TransportRules.capacity(units.selected) > 0:
			hud.selection_info.text += "\nPassengers: %d/%d (%d slots used). L loads; U chooses landing land." % [TransportRules.passengers(units.selected, units.units).size(), TransportRules.capacity(units.selected), TransportRules.used(units.selected, units.units)]
		if units.selected != null and UnitCatalog.is_air(units.selected.kind):
			var aircraft: UnitState = units.selected
			hud.selection_info.text += "\nAIR | %s | Base %s | Rearm %.1fs" % [aircraft.air_mission if aircraft.kind == "fighter" else "Hover / flight", str(aircraft.airfield) if aircraft.airfield != AircraftRules.NO_BASE else "None", aircraft.mission_remaining]
		var stack_members: Array[UnitState] = []
		if units.selected != null:
			stack_members = _hex_members(units.selected.hex)
		hud.show_stack(stack_members, units.units, units.expanded_hex, units.selected_units)
		hud.show_tile_actions(_economy_hex(), units.economy, units.territory, world_map.map_data["tiles"])
		var inspected: Vector2i = world_map.selected_hex
		var income_economy: EconomyState = units.match_state.rival_economy if units.territory.owner_at(inspected) == 2 else units.economy
		hud.show_supply(inspected, income_economy, units.territory, world_map.map_data["tiles"])
		if units.managed_hex != _facility_hex:
			units.managed_hex = _facility_hex
			units.queue_redraw()
		hud.show_match_status(units.match_state)
		units.build_hex = world_map.world_to_hex(get_global_mouse_position())
		if not units.build_kind.is_empty():
			hud.build_status.text = "%s • %d°\n%s\nLeft-click place • Q rotate\nRight-click / Esc cancel" % [units.build_kind.capitalize(), units.build_rotation * 60, "VALID — controlled empty hex" if units.can_place(units.build_hex, units.build_kind) else "BLOCKED — ownership / terrain / structure / credits"]
			if units.build_kind == "road":
				hud.build_status.text = "ROAD | 100 CR / hex\n%s\nClick consecutive hexes. Esc cancels." % ("VALID: controlled road terrain" if units.can_place(units.build_hex, "road") else "BLOCKED: terrain / owner / road / credits")
			units.queue_redraw()
		hud.world_stats_label.text = "%d CR   |   +%.0f / SEC" % [int(units.economy.credits), units.economy.income_rate(world_map.map_data["tiles"], units.territory)]
		var power: Dictionary = units.economy.power_balance(units.territory)
		hud.world_stats_label.text += "\nPOWER %d / %d used%s" % [power["demand"], power["supply"], " • LOW" if units.economy.low_power(units.territory) else " • OK"]


func _begin_build(kind: String) -> void:
	if _menu_open or units.match_state.result != "playing":
		return
	_rally_mode = false
	_move_mode = false
	_transport_mode = ""
	_attack_mode = false
	units.build_kind = kind if EconomyState.BUILD_COSTS.has(kind) or kind == "road" else ""
	units.build_rotation = 0
	_box_active = false
	_selection_box.hide()
	units.queue_redraw()
	if hud.mobile_layout and not kind.is_empty():
		hud.production_open = false
		hud._layout_for_viewport()
	hud.show_command_info("Construction cancelled" if kind.is_empty() else "Choose controlled empty land • Left-click place • Q rotate • Esc cancel")
	if kind == "road":
		hud.show_command_info("Road tool: click owned plains, forest, desert or city. 100 CR per hex. Esc cancels.")


func _building_action(action: String, hex: Vector2i, site: Dictionary) -> void:
	if _menu_open or units.match_state.result != "playing":
		return
	var accepted: bool = false
	if action == "sell":
		accepted = units.economy.sell_building(hex, units.territory, site)
	elif action == "repair":
		accepted = units.economy.set_repair(hex, units.territory, site, not site.get("repairing", false))
	hud.show_command_info("Building order accepted" if accepted else "Building order rejected: site changed, unfinished or no longer controlled")
	hud.show_tile_actions(_economy_hex(), units.economy, units.territory, world_map.map_data["tiles"])
	units.queue_redraw()


func _cancel_construction(hex: Vector2i, site: Dictionary) -> void:
	if _menu_open or units.match_state.result != "playing":
		return
	var accepted: bool = units.economy.cancel_construction(hex, units.territory, site)
	hud.show_command_info("Construction cancelled: 50% refunded" if accepted else "Cancellation unavailable: site changed, completed or no longer controlled")
	hud.show_tile_actions(_economy_hex(), units.economy, units.territory, world_map.map_data["tiles"])
	units.queue_redraw()


func _train_selected(kind: String) -> void:
	if _menu_open or units.match_state.result != "playing":
		return
	var producer: Variant = StrategyHUD.production_target(kind, _economy_hex(), units.economy, units.territory)
	var accepted: bool = producer != null and units.economy.train(producer, kind, units.territory)
	hud.show_command_info("Training queued" if accepted else "Training unavailable: check building, credits and queue")


func _economy_hex() -> Vector2i:
	if not units.economy.buildings.has(_facility_hex) or not is_same(units.economy.buildings.get(_facility_hex, {}), _facility_site) or units.territory.owner_at(_facility_hex) != units.economy.faction:
		_facility_hex = NO_FACILITY
		_facility_site = {}
		_rally_mode = false
	return _facility_hex


func _select_facility(hex: Vector2i) -> void:
	if _menu_open or units.match_state.result != "playing" or not units.economy.buildings.has(hex) or units.territory.owner_at(hex) != units.economy.faction:
		return
	_rally_mode = false
	_facility_hex = hex
	_facility_site = units.economy.buildings[hex]
	units.select_one(null)
	world_map.inspect_at_world(world_map.hex_to_world(hex))
	hud.show_tile_actions(hex, units.economy, units.territory, world_map.map_data["tiles"])
	units.queue_redraw()


func _begin_rally() -> void:
	_transport_mode = ""
	if _menu_open or units.match_state.result != "playing":
		return
	var hex: Vector2i = _economy_hex()
	if not units.economy.buildings.has(hex) or not EconomyState.is_complete(units.economy.buildings[hex]) or not units.economy.buildings[hex]["kind"] in ["factory", "barracks", "airfield", "shipyard"]:
		return
	_begin_build("")
	_rally_mode = true
	hud.show_command_info("Choose rally destination on map. Esc cancels; factory stays selected.")


func _set_facility_rally(point: Vector2) -> void:
	var accepted: bool = units.economy.set_rally(_economy_hex(), world_map.world_to_hex(point), world_map.map_data["tiles"], units.territory)
	_rally_mode = not accepted and _facility_hex != NO_FACILITY
	hud.show_command_info("Rally point set" if accepted else "Rally rejected: choose reachable land, or Esc to cancel")
	units.queue_redraw()


func _set_menu_open(open: bool) -> void:
	_move_mode = false
	_transport_mode = ""
	_attack_mode = false
	_menu_open = open
	_rally_mode = false
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
	if action == "pause":
		_set_menu_open(true)
		return
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
	if _menu_open or units.match_state.result != "playing" or units.build_kind.is_empty():
		return
	if units.build_kind == "road":
		var accepted: bool = RoadRules.build(hex, world_map.map_data["tiles"], units.territory, units.economy)
		hud.show_command_info("Road completed (100 CR). Choose next hex; Esc cancels." if accepted else "Road blocked: need 100 CR and controlled uncontested plains, forest, desert or city without a road")
		units.queue_redraw()
		return
	if units.economy.build(hex, units.build_kind, world_map.map_data["tiles"], units.territory, units.build_rotation, units.match_state.rival_economy.buildings):
		world_map.inspect_at_world(point)
		_begin_build("")
		hud.show_command_info("Foundation placed • Production unlocks when construction finishes")
	else:
		hud.build_status.text = "Blocked: need owned empty land,\ncredits, and no duplicate HQ"
