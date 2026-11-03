extends Node2D
class_name UnitLayer
var managed_hex: Vector2i = Vector2i(-99999, -99999)
## Lightweight live overlay; never invalidates the cached terrain.

var world_map: WorldMap
var units: Array[UnitState] = []
var selected: UnitState
var selected_units: Array[UnitState] = []
var animation_time: float = 0.0
var _last_pick_members: Array = []
var _pick_index: int = 0


func select_one(unit: UnitState) -> void:
	selected_units.clear()
	selected = unit
	if unit != null:
		selected_units.append(unit)
	queue_redraw()

func toggle_selection(unit: UnitState) -> void:
	if unit == null or unit.faction != 1 or not unit.is_alive():
		return
	if selected_units.has(unit):
		selected_units.erase(unit)
	else:
		selected_units.append(unit)
	selected = selected_units[0] if not selected_units.is_empty() else null
	queue_redraw()


func select_box(screen_rect: Rect2, canvas_transform: Transform2D) -> void:
	selected_units.clear()
	var zoom_factor: float = canvas_transform.get_scale().x
	var batches: Array[Dictionary] = UnitVisuals.groups(units)
	for unit in units:
		var point: Vector2 = unit_position(unit)
		if UnitVisuals.tier(zoom_factor) != "close":
			for batch in batches:
				if batch["members"].has(unit):
					point = group_position(batch, batches, zoom_factor)
					break
		var screen_point: Vector2 = canvas_transform * to_global(point)
		if unit.faction == 1 and unit.is_alive() and screen_rect.abs().has_point(screen_point):
			selected_units.append(unit)
	selected = selected_units[0] if not selected_units.is_empty() else null
	queue_redraw()
var territory: TerritoryState = TerritoryState.new()
var combat_targets: Dictionary = {}
var economy: EconomyState = EconomyState.new()
var match_state: MatchState = MatchState.new()
var build_kind: String = ""
var build_rotation: int = 0
var build_hex: Vector2i = Vector2i.ZERO


func faction_color(faction: int) -> Color:
	return Color("65ebd0") if faction == 1 else Color("f08075")

func can_place(hex: Vector2i, kind: String) -> bool:
	if kind == "road":
		return RoadRules.can_build(hex, world_map.map_data["tiles"], territory, economy)
	return economy.can_build(hex, kind, world_map.map_data["tiles"], territory, match_state.rival_economy.buildings)


func configure(map: WorldMap) -> void:
	world_map = map
	# Start at named cities, spread across the world and guaranteed to be on land.
	for tile in map.map_data["tiles"].values():
		if tile["terrain"] == "city" and units.size() < 3:
			units.append(UnitState.new(tile["axial"], "Squad %d" % (units.size() + 1)))
	for unit in units:
		territory.owners[unit.hex] = unit.faction
	units[1].configure_kind("tank")
	units[1].title = "Main battle tank"
	economy.add_building(units[0].hex, "headquarters")
	match_state.player_hq = units[0].hex
	var rival_home: Vector2i = units[0].hex
	for neighbor in map.map_data["tiles"]:
		if HexMath.distance(rival_home, neighbor) == 8 and HexPathfinding.is_walkable(map.map_data["tiles"], neighbor) and territory.owner_at(neighbor) == 0 and not HexPathfinding.find_path(map.map_data["tiles"], rival_home, neighbor).is_empty():
			var defender: UnitState = UnitState.new(neighbor, "Rival squad")
			defender.faction = 2
			units.append(defender)
			territory.owners[neighbor] = 2
			match_state.rival_hq = neighbor
			match_state.rival_economy.add_building(neighbor, "headquarters")
			var route: Array[Vector2i] = HexPathfinding.find_path(map.map_data["tiles"], neighbor, rival_home)
			territory.owners[route[1]] = 2
			match_state.rival_economy.add_building(route[1], "barracks")
			break
	var starts: Array[Vector2i] = []
	for unit in units:
		starts.append(unit.hex)
	territory.continents.configure(map.map_data["tiles"], starts, territory.owners)
	queue_redraw()


func _base_position(unit: UnitState) -> Vector2:
	var point: Vector2 = world_map.hex_to_world(unit.hex)
	if not unit.path.is_empty():
		point = point.lerp(world_map.hex_to_world(unit.path[0]), unit.progress)
	# Dock idle units beside a building rather than hiding its identifying symbol.
	if unit.path.is_empty() and economy.buildings.has(unit.hex):
		point += Vector2(14, 14)
	return to_local(point)

func unit_position(unit: UnitState) -> Vector2:
	return _base_position(unit) + UnitVisuals.offset(unit, units)

func group_position(batch: Dictionary, batches: Array[Dictionary], zoom_factor: float) -> Vector2:
	var point: Vector2 = Vector2.ZERO
	for member in batch["members"]:
		point += _base_position(member)
	var spacing: float = 1.8 if UnitVisuals.tier(zoom_factor) == "medium" else 1.0
	return point / batch["members"].size() + UnitVisuals.group_offset(batch, batches) * spacing / maxf(zoom_factor, 0.15)


func pick(global_point: Vector2, zoom_factor: float) -> UnitState:
	return pick_faction(global_point, zoom_factor, 1)

func pick_faction(global_point: Vector2, zoom_factor: float, faction: int, cycle: bool = false) -> UnitState:
	if UnitVisuals.tier(zoom_factor) != "close":
		var batches: Array[Dictionary] = UnitVisuals.groups(units)
		var members: Array = []
		var best_group: float = 17.0 / maxf(zoom_factor, 0.15)
		for batch in batches:
			var distance: float = group_position(batch, batches, zoom_factor).distance_to(to_local(global_point))
			if batch["faction"] == faction and distance < best_group:
				best_group = distance
				members = batch["members"]
		if members.is_empty():
			return null
		if cycle:
			_pick_index = (_pick_index + 1) % members.size() if members == _last_pick_members else 0
			_last_pick_members = members.duplicate()
		else:
			return members[0]
		return members[_pick_index]
	var nearest: UnitState = null
	var best: float = maxf(10.0, 9.0 / zoom_factor)
	for unit in units:
		var distance: float = unit_position(unit).distance_to(to_local(global_point))
		if unit.faction != faction or not unit.is_alive():
			continue
		if distance < best:
			best = distance
			nearest = unit
	return nearest


func _physics_process(delta: float) -> void:
	if world_map == null or match_state.result != "playing":
		return
	animation_time += delta
	for unit in units:
		unit.attack_flash = maxf(0, unit.attack_flash - delta)
		unit.damage_flash = maxf(0, unit.damage_flash - delta)
	var economies: Array[EconomyState] = [economy, match_state.rival_economy]
	UnitOrders.update(units, world_map.map_data["tiles"], economies)
	match_state.advance_ai(delta, world_map.map_data["tiles"], territory, units, economy.buildings)
	combat_targets = CombatState.advance(delta, units, world_map.map_data["tiles"], FortificationRules.protection(units, [economy, match_state.rival_economy], territory))
	CombatState.attack_extractors(delta, units, economies, combat_targets, world_map.map_data["tiles"])
	for index in range(units.size() - 1, -1, -1):
		if not units[index].is_alive():
			selected_units.erase(units[index])
			if selected == units[index]:
				selected = selected_units[0] if not selected_units.is_empty() else null
			units.remove_at(index)
	for unit in units:
		if unit.attack_target != null and not units.has(unit.attack_target.get_ref()):
			unit.order_hold()
	# No capture credit on the tick a squad arrives.
	territory.advance(delta, world_map.map_data["tiles"], units)
	match_state.evaluate(territory)
	if match_state.result != "playing":
		combat_targets.clear()
		queue_redraw()
		return
	for unit in units:
		if not unit.path.is_empty():
			unit.advance(delta, world_map.map_data["tiles"])
	units.append_array(economy.advance(delta, world_map.map_data["tiles"], territory))
	units.append_array(match_state.rival_economy.advance(delta, world_map.map_data["tiles"], territory))
	queue_redraw()


func _draw() -> void:
	if world_map == null:
		return
	_draw_territory()
	_draw_roads()
	_draw_isolated_locations()
	for hex in match_state.rival_economy.buildings:
		var rival_building: Dictionary = match_state.rival_economy.buildings[hex]
		var rival_color: Color = faction_color(2)
		if rival_building["kind"] == "bunker":
			rival_color = faction_color(territory.owner_at(hex)) if territory.owner_at(hex) > 0 else Color("889099")
		_draw_building_badge(to_local(world_map.hex_to_world(hex)), rival_building["kind"], rival_color, world_map.selected_hex == hex, rival_building.get("rotation", 0))
		_draw_construction(to_local(world_map.hex_to_world(hex)), rival_building, rival_color)
		_draw_bunker_status(hex, match_state.rival_economy)
	if not build_kind.is_empty():
		var valid: bool = can_place(build_hex, build_kind)
		var preview_color: Color = Color("65ebd0") if valid else Color("f08075")
		var ghost_center: Vector2 = to_local(world_map.hex_to_world(build_hex))
		var corners: PackedVector2Array = []
		for index in range(6):
			corners.append(ghost_center + Vector2.from_angle(deg_to_rad(index * 60.0 - 30.0)) * WorldMap.HEX_RADIUS)
		draw_colored_polygon(corners, Color(preview_color, 0.35))
		if build_kind == "road":
			draw_line(ghost_center - Vector2(12, 0), ghost_center + Vector2(12, 0), preview_color, 5.0, true)
		else:
			_draw_building_badge(ghost_center, build_kind, preview_color, true, build_rotation)
	for hex in economy.buildings:
		var building: Dictionary = economy.buildings[hex]
		var center: Vector2 = to_local(world_map.hex_to_world(hex))
		var color: Color = Color("ffd87c") if territory.owner_at(hex) == 1 else Color("889099")
		if building["kind"] == "bunker" and territory.owner_at(hex) > 0:
			color = faction_color(territory.owner_at(hex))
		_draw_building_badge(center, building["kind"], color, managed_hex == hex, building.get("rotation", 0))
		_draw_construction(center, building, color)
		_draw_bunker_status(hex, economy)
		if not building["queue"].is_empty():
			var fraction: float = building["elapsed"] / EconomyState.TRAIN_SECONDS[building["queue"][0]]
			draw_arc(center, 16.0, -PI / 2.0, -PI / 2.0 + TAU * fraction, 48, color, 2.5, true)
			draw_circle(center + Vector2(-12, 12), 5.0, Color("071522"))
			draw_string(ThemeDB.fallback_font, center + Vector2(-15, 15), str(building["queue"].size()), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, color)
		if managed_hex == hex and building["rally"] != hex:
			draw_line(center, to_local(world_map.hex_to_world(building["rally"])), color, 1.0, true)
	for attacker in combat_targets:
		var target: UnitState = combat_targets[attacker]
		if attacker.is_alive() and target.is_alive():
			draw_line(unit_position(attacker), unit_position(target), Color("ffc875"), 1.5, true)
	if selected != null and not selected.path.is_empty():
		var points: PackedVector2Array = PackedVector2Array([unit_position(selected)])
		for hex in selected.path:
			points.append(to_local(world_map.hex_to_world(hex)))
		draw_polyline(points, Color("fff0ad"), 2.0, true)
		draw_arc(points[-1], 8.0, 0.0, TAU, 24, Color("fff0ad"), 2.0, true)
	_draw_units()

func _draw_units() -> void:
	var zoom_factor: float = get_canvas_transform().get_scale().x
	var detail: String = UnitVisuals.tier(zoom_factor)
	if detail == "close":
		for unit in units:
			UnitAppearance.draw_unit(self, unit, unit_position(unit), faction_color(unit.faction), selected_units.has(unit), animation_time)
		return
	var batches: Array[Dictionary] = UnitVisuals.groups(units)
	for batch in batches:
		var members: Array = batch["members"]
		var point: Vector2 = group_position(batch, batches, zoom_factor)
		var highlighted: bool = false
		var injured: bool = false
		var health_fraction: float = 1.0
		for member in members:
			highlighted = highlighted or selected_units.has(member)
			injured = injured or member.health < member.max_health
			health_fraction = minf(health_fraction, member.health / member.max_health)
		var icon_scale: float = 1.0 / maxf(zoom_factor, 0.15)
		if UnitCatalog.is_infantry(batch["kind"]):
			UnitAppearance.draw_marker(self, batch["kind"], point, faction_color(batch["faction"]), members.size(), highlighted, icon_scale)
			var leader: UnitState = members[0]
			var heading: Vector2 = Vector2.from_angle(leader.facing)
			draw_line(point + heading * 13 * icon_scale, point + heading * 18 * icon_scale, faction_color(batch["faction"]), 2 * icon_scale, true)
			for member in members:
				if member.damage_flash > 0:
					draw_arc(point, 11 * icon_scale, 0, TAU, 24, Color("fff5db"), icon_scale, true)
				if member.attack_flash > 0:
					draw_circle(point + heading * 20 * icon_scale, 2 * icon_scale, Color("ffe0a0"))
		else:
			for index in range(mini(3, members.size())):
				var offset: Vector2 = Vector2(index * 7.0 - (mini(3, members.size()) - 1) * 3.5, index * 3.0) * icon_scale
				UnitAppearance.draw_unit(self, members[index], point + offset, faction_color(batch["faction"]), highlighted, animation_time + index, 0.85 * icon_scale)
			draw_string(ThemeDB.fallback_font, point + Vector2(-12, 21) * icon_scale, "%s %d" % [UnitCatalog.TYPES[batch["kind"]]["marker"], members.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, roundi(10 * icon_scale), faction_color(batch["faction"]))
		if injured or highlighted:
			draw_rect(Rect2(point + Vector2(-9, -15) * icon_scale, Vector2(18, 2) * icon_scale), UnitAppearance.INK)
			draw_rect(Rect2(point + Vector2(-9, -15) * icon_scale, Vector2(18 * health_fraction, 2) * icon_scale), faction_color(batch["faction"]))


func _draw_bunker_status(hex: Vector2i, owner_economy: EconomyState) -> void:
	if owner_economy.buildings[hex]["kind"] != "bunker":
		return
	var center: Vector2 = to_local(world_map.hex_to_world(hex))
	var count: int = FortificationRules.occupants(hex, owner_economy.faction, units).size() if FortificationRules.operational(hex, owner_economy, territory) else 0
	draw_string(ThemeDB.fallback_font, center + Vector2(-9, 25), "%d/2" % count, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, faction_color(territory.owner_at(hex)))
	owner_economy.supply.refresh(world_map.map_data["tiles"], territory, owner_economy)
	if not owner_economy.supply.supplied.has(hex):
		draw_string(ThemeDB.fallback_font, center + Vector2(-3, -21), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color("f08075"))

func _draw_isolated_locations() -> void:
	var tiles: Dictionary = world_map.map_data["tiles"]
	for faction_economy in [economy, match_state.rival_economy]:
		faction_economy.supply.refresh(tiles, territory, faction_economy)
		for hex in territory.owners:
			if territory.owner_at(hex) != faction_economy.faction:
				continue
			var economic: bool = tiles.get(hex, {}).get("terrain", "") == "city" or (faction_economy.buildings.has(hex) and faction_economy.buildings[hex]["kind"] == "extractor")
			if economic and not faction_economy.supply.supplied.has(hex):
				var center: Vector2 = to_local(world_map.hex_to_world(hex))
				draw_arc(center, 19.0, 0, TAU, 24, Color("f08075"), 2.0, true)
				draw_line(center + Vector2(12, -18), center + Vector2(18, -12), Color("f08075"), 2.0, true)
				draw_line(center + Vector2(18, -18), center + Vector2(12, -12), Color("f08075"), 2.0, true)


func _draw_roads() -> void:
	var tiles: Dictionary = world_map.map_data["tiles"]
	for hex in tiles:
		if not tiles[hex].get("road", false):
			continue
		var center: Vector2 = to_local(world_map.hex_to_world(hex))
		draw_circle(center, 3.0, Color("c8b78f"))
		for neighbor in RoadRules.neighbors(tiles, hex):
			if neighbor.x > hex.x or (neighbor.x == hex.x and neighbor.y > hex.y):
				var end: Vector2 = to_local(world_map.hex_to_world(neighbor))
				draw_line(center, end, Color("38372f"), 7.0, true)
				draw_line(center, end, Color("c8b78f"), 3.5, true)


func _draw_construction(center: Vector2, building: Dictionary, color: Color) -> void:
	var maximum: float = EconomyState.BUILD_HEALTH[building["kind"]]
	draw_rect(Rect2(center + Vector2(-12, -23), Vector2(24, 3)), Color("071522"))
	draw_rect(Rect2(center + Vector2(-12, -23), Vector2(24 * building.get("health", maximum) / maximum, 3)), color)
	if EconomyState.is_complete(building):
		return
	var fraction: float = building["construction"] / EconomyState.BUILD_SECONDS[building["kind"]]
	# Cover the completed symbol until the foundation rises into its silhouette.
	draw_rect(Rect2(center - Vector2(13, 13), Vector2(26, 26 * (1.0 - fraction))), Color("071522"))
	draw_rect(Rect2(center + Vector2(-12, 9), Vector2(24, 4)), color, false, 1.5)
	draw_rect(Rect2(center + Vector2(-14, 19), Vector2(28, 4)), Color("071522"))
	draw_rect(Rect2(center + Vector2(-14, 19), Vector2(28 * fraction, 4)), color)


func _draw_building_badge(center: Vector2, kind: String, color: Color, highlighted: bool, orientation: int = 0) -> void:
	draw_set_transform(center, deg_to_rad(orientation * 60.0))
	_draw_building_icon(Vector2.ZERO, kind, color, highlighted)
	draw_set_transform(Vector2.ZERO)

func _draw_building_icon(center: Vector2, kind: String, color: Color, highlighted: bool) -> void:
	var ink: Color = Color("071522")
	draw_circle(center + Vector2(0, 2), 15.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(center, 14.0, ink)
	draw_circle(center, 11.5, Color(color, 0.14))
	draw_arc(center, 14.0, 0.0, TAU, 48, color, 1.5, true)
	if highlighted:
		draw_arc(center, 18.0, 0.0, TAU, 48, Color("fff0ad"), 1.5, true)
	if kind == "headquarters":
		# Central command block, wings, and a raised flag.
		draw_rect(Rect2(center + Vector2(-9, 0), Vector2(18, 7)), color)
		draw_rect(Rect2(center + Vector2(-4, -5), Vector2(8, 12)), color)
		draw_line(center + Vector2(0, -5), center + Vector2(0, -11), color, 1.5, true)
		_building_polygon(center, [Vector2(0, -11), Vector2(6, -9), Vector2(0, -7)], color)
		draw_rect(Rect2(center + Vector2(-2, 2), Vector2(4, 5)), ink)
	elif kind == "barracks":
		# Pitched roof, long accommodation block, door and windows.
		_building_polygon(center, [Vector2(-10, -1), Vector2(0, -8), Vector2(10, -1)], color)
		draw_rect(Rect2(center + Vector2(-8, 0), Vector2(16, 7)), color)
		draw_rect(Rect2(center + Vector2(-2, 2), Vector2(4, 5)), ink)
		for x in [-6, 4]:
			draw_rect(Rect2(center + Vector2(x, 2), Vector2(2, 2)), ink)
	elif kind == "extractor":
		_building_polygon(center, [Vector2(-8, 8), Vector2(0, -10), Vector2(8, 8)], color)
		draw_line(center + Vector2(-7, 0), center + Vector2(7, 0), Color("071522"), 3.0)
		draw_line(center + Vector2(0, -4), center + Vector2(0, 11), Color("071522"), 2.0)
		draw_rect(Rect2(center + Vector2(-10, 8), Vector2(20, 3)), color)
	elif kind == "power_plant":
		_building_polygon(center, [Vector2(-10, 8), Vector2(-7, -9), Vector2(-2, -9), Vector2(0, 8)], color)
		_building_polygon(center, [Vector2(1, 8), Vector2(3, -6), Vector2(7, -6), Vector2(10, 8)], color)
		draw_line(center + Vector2(-11, 9), center + Vector2(11, 9), color, 2.0)
	elif kind == "bunker":
		draw_rect(Rect2(center + Vector2(-10, -5), Vector2(20, 12)), color)
		draw_rect(Rect2(center + Vector2(-7, -2), Vector2(14, 3)), ink)
	elif kind == "factory":
		# Sawtooth roof, smokestack, and a wide vehicle bay.
		_building_polygon(center, [Vector2(-9, 7), Vector2(-9, -2), Vector2(-3, -6), Vector2(-3, -2), Vector2(3, -6), Vector2(3, -2), Vector2(9, -2), Vector2(9, 7)], color)
		draw_rect(Rect2(center + Vector2(5, -10), Vector2(3, 10)), color)
		draw_rect(Rect2(center + Vector2(-5, 2), Vector2(9, 5)), ink)


func _building_polygon(center: Vector2, vertices: Array[Vector2], color: Color) -> void:
	var points: PackedVector2Array = []
	for vertex in vertices:
		points.append(center + vertex)
	draw_colored_polygon(points, color)


func _draw_territory() -> void:
	var directions: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)]
	for hex in territory.owners:
		var center: Vector2 = to_local(world_map.hex_to_world(hex))
		var corners: PackedVector2Array = []
		for index in range(6):
			corners.append(center + Vector2.from_angle(deg_to_rad(index * 60.0 - 30.0)) * WorldMap.HEX_RADIUS)
		var color: Color = faction_color(territory.owner_at(hex))
		draw_colored_polygon(corners, Color(color, 0.18))
		for side in range(6):
			if territory.owner_at(hex + directions[side]) != territory.owner_at(hex):
				draw_line(corners[side], corners[(side + 1) % 6], color, 2.0, true)
	for hex in territory.captures:
		var capture: Dictionary = territory.captures[hex]
		var center: Vector2 = to_local(world_map.hex_to_world(hex))
		draw_arc(center, 15.0, -PI / 2.0, -PI / 2.0 + TAU * capture["elapsed"] / TerritoryState.CAPTURE_SECONDS, 32, faction_color(capture["faction"]), 3.0, true)
