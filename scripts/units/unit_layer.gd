extends Node2D
class_name UnitLayer
var managed_hex: Vector2i = Vector2i(-99999, -99999)
## Lightweight live overlay; never invalidates the cached terrain.

var world_map: WorldMap
var units: Array[UnitState] = []
var selected: UnitState
var selected_units: Array[UnitState] = []
var expanded_hex: Vector2i = Vector2i(-99999, -99999)
var animation_time: float = 0.0
var wrecks: Array[Dictionary] = []
var building_wrecks: Array[Dictionary] = []
var shell_effects: Array[Dictionary] = []
@export var far_zoom_threshold: float = UnitVisuals.FAR_ZOOM
@export var close_zoom_threshold: float = UnitVisuals.CLOSE_ZOOM
var army_presentation: ArmyPresentation = ArmyPresentation.new()

func military_batches() -> Array[Dictionary]:
	army_presentation.refresh(units)
	return army_presentation.batches

func individual_view(zoom_factor: float, hex: Vector2i, faction: int) -> bool:
	return zoom_factor >= close_zoom_threshold or (hex == expanded_hex and faction == 1)
var _stack_units: Array[UnitState] = []
var _stack_hexes: Array[Vector2i] = []
var _stack_factions: Array[int] = []
var _stack_kinds: Array[String] = []
var _stack_deployed: Array[bool] = []
var _stack_batches: Array[Dictionary] = []
const WRECK_SECONDS: float = 8.0
const MAX_WRECKS: int = 128


func visual_stacks() -> Array[Dictionary]:
	# State is mutable from simulation, saves and orders. Validate exact dependencies
	# rather than relying on every caller to remember an invalidation signal.
	var changed: bool = units.size() != _stack_units.size()
	if not changed:
		for index in range(units.size()):
			var unit: UnitState = units[index]
			if unit != _stack_units[index] or unit.hex != _stack_hexes[index] or unit.faction != _stack_factions[index] or unit.kind != _stack_kinds[index] or unit.is_deployed() != _stack_deployed[index]:
				changed = true
				break
	if changed:
		_stack_units.assign(units)
		_stack_hexes.resize(units.size())
		_stack_factions.resize(units.size())
		_stack_kinds.resize(units.size())
		_stack_deployed.resize(units.size())
		for index in range(units.size()):
			var unit: UnitState = units[index]
			_stack_hexes[index] = unit.hex
			_stack_factions[index] = unit.faction
			_stack_kinds[index] = unit.kind
			_stack_deployed[index] = unit.is_deployed()
		_stack_batches = UnitVisuals.stacks(units)
	return _stack_batches


func select_one(unit: UnitState) -> void:
	if unit != null and not unit.is_deployed():
		unit = null
	selected_units.clear()
	selected = unit
	if unit != null:
		selected_units.append(unit)
	queue_redraw()

func toggle_selection(unit: UnitState) -> void:
	if unit == null or unit.faction != 1 or not unit.is_deployed():
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
	var batches: Array[Dictionary] = military_batches()
	for unit in units:
		var point: Vector2 = unit_position(unit)
		if not individual_view(zoom_factor, unit.hex, unit.faction):
			for batch in batches:
				if batch["members"].has(unit):
					point = group_position(batch, batches, zoom_factor)
					break
		var screen_point: Vector2 = canvas_transform * to_global(point)
		if unit.faction == 1 and unit.is_deployed() and screen_rect.abs().has_point(screen_point):
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
	_watch_building_damage()
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
	if unit.domain == "air":
		point += Vector2(0, -24)
	return to_local(point)

func unit_position(unit: UnitState) -> Vector2:
	if not army_presentation.offsets.has(unit):
		army_presentation.refresh(units)
	return _base_position(unit) + army_presentation.offsets.get(unit, Vector2.ZERO)

func group_position(batch: Dictionary, batches: Array[Dictionary], zoom_factor: float) -> Vector2:
	if individual_view(zoom_factor, batch["hex"], batch["faction"]):
		return unit_position(batch["members"][0])
	var point: Vector2 = to_local(world_map.hex_to_world(batch["hex"]))
	if economy.buildings.has(batch["hex"]) or match_state.rival_economy.buildings.has(batch["hex"]):
		point += Vector2(14, 14)
	var offset: Vector2 = UnitVisuals.group_offset(batch, batches)
	if zoom_factor < UnitVisuals.FAR_ZOOM:
		# Far markers are screen-sized, so keep their spacing screen-sized too.
		offset /= maxf(zoom_factor, 0.15)
	return point + offset


func pick(global_point: Vector2, zoom_factor: float) -> UnitState:
	return pick_faction(global_point, zoom_factor, 1)

func pick_faction(global_point: Vector2, zoom_factor: float, faction: int, _cycle: bool = false) -> UnitState:
	var nearest: UnitState = null
	var best: float = UnitVisuals.pick_radius(zoom_factor)
	var batches: Array[Dictionary] = military_batches()
	for batch in batches:
		if batch["faction"] != faction:
			continue
		if individual_view(zoom_factor, batch["hex"], faction):
			for unit in batch["members"]:
				var distance: float = unit_position(unit).distance_to(to_local(global_point))
				if distance < best:
					best = distance
					nearest = unit
		else:
			var distance: float = group_position(batch, batches, zoom_factor).distance_to(to_local(global_point))
			if distance < best:
				best = distance
				nearest = batch["members"][0]
	return nearest


func _watch_building_damage() -> void:
	for owner_economy in [economy, match_state.rival_economy]:
		if not owner_economy.building_destroyed.is_connected(_on_building_destroyed):
			owner_economy.building_destroyed.connect(_on_building_destroyed)

func _on_building_destroyed(hex: Vector2i, kind: String, rotation: int, owner: int) -> void:
	building_wrecks.append({"hex": hex, "kind": kind, "rotation": rotation, "faction": owner, "remaining": WRECK_SECONDS})
	if building_wrecks.size() > MAX_WRECKS:
		building_wrecks.pop_front()
	queue_redraw()

func _physics_process(delta: float) -> void:
	_watch_building_damage()
	var had_building_wrecks: bool = not building_wrecks.is_empty()
	for index in range(building_wrecks.size() - 1, -1, -1):
		building_wrecks[index]["remaining"] -= delta
		if building_wrecks[index]["remaining"] <= 0:
			building_wrecks.remove_at(index)
	var had_shells: bool = not shell_effects.is_empty()
	for index in range(shell_effects.size() - 1, -1, -1):
		shell_effects[index]["age"] += delta
		if shell_effects[index]["age"] >= 0.8:
			shell_effects.remove_at(index)
	var had_wrecks: bool = not wrecks.is_empty()
	for index in range(wrecks.size() - 1, -1, -1):
		wrecks[index]["remaining"] -= delta
		if wrecks[index]["remaining"] <= 0:
			wrecks.remove_at(index)
	if world_map == null or match_state.result != "playing":
		if had_wrecks or had_shells or had_building_wrecks:
			queue_redraw()
		return
	animation_time += delta
	for unit in units:
		unit.attack_flash = maxf(0, unit.attack_flash - delta)
		unit.damage_flash = maxf(0, unit.damage_flash - delta)
	var economies: Array[EconomyState] = [economy, match_state.rival_economy]
	AircraftRules.update(delta, units, world_map.map_data["tiles"], economies, territory)
	var previous_shots: Dictionary = {}
	for unit in units:
		if unit.kind == "artillery" or UnitCatalog.is_air(unit.kind):
			previous_shots[unit] = unit.shot_serial
	UnitOrders.update(units, world_map.map_data["tiles"], economies)
	match_state.advance_ai(delta, world_map.map_data["tiles"], territory, units, economy.buildings)
	combat_targets = CombatState.advance(delta, units, world_map.map_data["tiles"], FortificationRules.protection(units, [economy, match_state.rival_economy], territory))
	CombatState.attack_extractors(delta, units, economies, combat_targets, world_map.map_data["tiles"])
	AircraftRules.update(0, units, world_map.map_data["tiles"], economies, territory)
	for unit in previous_shots:
		if unit.shot_serial > previous_shots[unit]:
			shell_effects.append({"from": to_local(world_map.hex_to_world(unit.hex)), "to": to_local(world_map.hex_to_world(unit.last_shot_hex)), "age": 0.0})
			if shell_effects.size() > 128:
				shell_effects.pop_front()
	TransportRules.synchronize(units)
	for index in range(units.size() - 1, -1, -1):
		if not units[index].is_alive():
			var lost: UnitState = units[index]
			if not lost.is_embarked():
				wrecks.append({"kind": lost.kind, "faction": lost.faction, "position": unit_position(lost), "facing": lost.facing, "remaining": 0.65 if UnitCatalog.is_infantry(lost.kind) else WRECK_SECONDS})
			if wrecks.size() > MAX_WRECKS:
				wrecks.pop_front()
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
	TransportRules.synchronize(units)
	units.append_array(economy.advance(delta, world_map.map_data["tiles"], territory))
	units.append_array(match_state.rival_economy.advance(delta, world_map.map_data["tiles"], territory))
	queue_redraw()


func _draw() -> void:
	if world_map == null:
		return
	_draw_territory()
	_draw_roads()
	_draw_artillery_range()
	_draw_isolated_locations()
	for wreck in building_wrecks:
		if not economy.buildings.has(wreck["hex"]) and not match_state.rival_economy.buildings.has(wreck["hex"]):
			_draw_building_badge(to_local(world_map.hex_to_world(wreck["hex"])), wreck["kind"], UnitArt.ACCENTS[UnitArt.faction_slot(wreck["faction"])], false, wreck["rotation"], wreck["faction"], "destroyed")
	for hex in match_state.rival_economy.buildings:
		var rival_building: Dictionary = match_state.rival_economy.buildings[hex]
		var rival_color: Color = UnitArt.ACCENTS[1]
		if rival_building["kind"] == "bunker":
			var owner: int = territory.owner_at(hex)
			rival_color = UnitArt.ACCENTS[UnitArt.faction_slot(owner)] if owner > 0 else Color("889099")
		_draw_building_badge(to_local(world_map.hex_to_world(hex)), rival_building["kind"], rival_color, world_map.selected_hex == hex, rival_building.get("rotation", 0), 0, building_art_state(rival_building))
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
			_draw_building_badge(ghost_center, build_kind, preview_color, true, build_rotation, 1 if valid else 2)
	for hex in economy.buildings:
		var building: Dictionary = economy.buildings[hex]
		var center: Vector2 = to_local(world_map.hex_to_world(hex))
		var owner: int = territory.owner_at(hex)
		var color: Color = UnitArt.ACCENTS[UnitArt.faction_slot(owner)] if owner > 0 else Color("889099")
		_draw_building_badge(center, building["kind"], color, managed_hex == hex, building.get("rotation", 0), 0, building_art_state(building))
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
		if attacker.kind != "artillery" and attacker.is_alive() and target.is_alive():
			draw_line(unit_position(attacker), unit_position(target), Color("ffc875"), 1.5, true)
	for unit in selected_units:
		if not unit.is_alive() or unit.path.is_empty():
			continue
		var points: PackedVector2Array = PackedVector2Array([unit_position(unit)])
		for hex in unit.path:
			points.append(to_local(world_map.hex_to_world(hex)))
		draw_polyline(points, Color("fff0ad"), 2.0, true)
		draw_arc(points[-1], 8.0, 0.0, TAU, 24, Color("fff0ad"), 2.0, true)
	_draw_units()
	_draw_shells()

func _draw_artillery_range() -> void:
	for unit in selected_units:
		if unit.kind != "artillery" or not unit.is_deployed():
			continue
		for q in range(-unit.attack_range, unit.attack_range + 1):
			for r in range(-unit.attack_range, unit.attack_range + 1):
				var hex: Vector2i = unit.hex + Vector2i(q, r)
				if HexMath.distance(unit.hex, hex) > unit.attack_range or not world_map.map_data["tiles"].has(hex):
					continue
				var corners: PackedVector2Array = []
				var center: Vector2 = to_local(world_map.hex_to_world(hex))
				for side in range(7):
					corners.append(center + Vector2.from_angle(deg_to_rad(side * 60 - 30)) * WorldMap.HEX_RADIUS)
				draw_polyline(corners, Color(1, 0.85, 0.45, 0.45), 1, true)

func _draw_shells() -> void:
	for effect in shell_effects:
		var fraction: float = minf(1, effect["age"] / 0.45)
		if fraction < 1:
			var point: Vector2 = effect["from"].lerp(effect["to"], fraction) + Vector2(0, -sin(fraction * PI) * 24)
			draw_circle(point + Vector2(2, 3), 3, Color("302d23"))
			draw_circle(point, 2.5, Color("fff0ad"))
		else:
			var fade: float = 1 - (effect["age"] - 0.45) / 0.35
			draw_circle(effect["to"], 12 * (1 - fade) + 3, Color(1, 0.6, 0.2, fade * 0.65))
			draw_arc(effect["to"], 16 * (1 - fade) + 2, 0, TAU, 24, Color(1, 0.9, 0.6, fade), 2, true)

func _draw_units() -> void:
	var zoom_factor: float = get_canvas_transform().get_scale().x
	for wreck in wrecks:
		var opacity: float = clampf(wreck["remaining"] / 0.65, 0, 1) if UnitCatalog.is_infantry(wreck["kind"]) else 1.0
		UnitArt.draw(self, wreck["kind"], wreck["faction"], "destroyed", wreck["position"], wreck["facing"], false, UnitVisuals.UNIT_BOX, opacity)
	var batches: Array[Dictionary] = military_batches()
	for batch in batches:
		var members: Array = batch["members"]
		var point: Vector2 = group_position(batch, batches, zoom_factor)
		var highlighted: bool = false
		var injured: bool = false
		var health_fraction: float = 1.0
		for member in members:
			highlighted = highlighted or selected_units.has(member)
			injured = injured or UnitArt.state_for(member.health, member.max_health, member.kind) == "damaged"
			health_fraction = minf(health_fraction, member.health / member.max_health)
		var icon_scale: float = UnitVisuals.badge_scale(zoom_factor) / maxf(zoom_factor, 0.15)
		if individual_view(zoom_factor, batch["hex"], batch["faction"]):
			for member in members:
				UnitAppearance.draw_unit(self, member, unit_position(member), faction_color(member.faction), selected_units.has(member), animation_time, 0.85 if member.domain == "air" and zoom_factor < UnitVisuals.CLOSE_ZOOM else 1.0)
				if member.kind == "landing_transport":
					draw_string(ThemeDB.fallback_font, unit_position(member) + Vector2(-9, 21), "%d/%d" % [TransportRules.used(member, units), TransportRules.capacity(member)], HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("fff0ad"))
			continue
		if zoom_factor >= far_zoom_threshold:
			# Army view: one readable sprite per role with the true unit count.
			var box: float = UnitVisuals.sprite_box(zoom_factor)
			var scale_factor: float = box / UnitVisuals.UNIT_BOX
			var representative: UnitState = members[0]
			for member in members:
				if member.attack_flash > 0:
					representative = member
					break
			UnitAppearance.draw_unit(self, representative, point, faction_color(batch["faction"]), highlighted, animation_time, scale_factor, false)
			if health_fraction < 1.0 or highlighted:
				UnitAppearance.stack_health_bar(self, point, health_fraction, faction_color(batch["faction"]), box)
			UnitAppearance.count_badge(self, point + Vector2(box * 0.42, box * 0.30), members.size(), zoom_factor)
			continue
		var firing_member: UnitState = null
		for member in members:
			if member.attack_flash > 0 and (firing_member == null or member.attack_flash > firing_member.attack_flash):
				firing_member = member
		var representative: UnitState = firing_member if firing_member != null else members[0]
		var facing: float = representative.turret_facing if representative.kind in ["tank", "artillery"] else representative.facing
		UnitAppearance.strategic(self, batch["kind"], batch["faction"], point, members.size(), highlighted, injured, icon_scale, facing)
		if firing_member != null:
			UnitAppearance.firing_effect(self, firing_member, point, icon_scale, true)
		if health_fraction < 1.0 or highlighted:
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


static func building_art_state(building: Dictionary) -> String:
	return UnitArt.state_for(building.get("health", EconomyState.BUILD_HEALTH[building["kind"]]), EconomyState.BUILD_HEALTH[building["kind"]])

func _draw_building_badge(center: Vector2, kind: String, color: Color, highlighted: bool, orientation: int = 0, faction: int = 0, state: String = "base") -> void:
	draw_set_transform(center, deg_to_rad(orientation * 60.0))
	_draw_building_icon(Vector2.ZERO, kind, color, highlighted, faction, state)
	draw_set_transform(Vector2.ZERO)

func _draw_building_icon(center: Vector2, kind: String, color: Color, highlighted: bool, faction: int = 0, state: String = "base") -> void:
	var slot: int = 0
	for index in range(UnitArt.ACCENTS.size()):
		if color.is_equal_approx(UnitArt.ACCENTS[index]):
			slot = index
	var image: Texture2D = UnitArt.building_texture(kind, faction if faction > 0 else slot + 1, state)
	if highlighted:
		draw_arc(center, 18.0, 0.0, TAU, 48, Color("131a17"), 4.0, true)
		draw_arc(center, 18.0, 0.0, TAU, 48, Color("fff0ad"), 2.0, true)
	if image != null:
		var tint: Color = Color.WHITE if color != Color("889099") else Color("889099")
		draw_texture_rect(image, Rect2(center - Vector2(16, 16), Vector2(32, 32)), false, tint)
	else:
		draw_string(ThemeDB.fallback_font, center, "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


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
