extends Node2D
class_name UnitLayer
## Lightweight live overlay; never invalidates the cached terrain.

var world_map: WorldMap
var units: Array[UnitState] = []
var selected: UnitState
var territory: TerritoryState = TerritoryState.new()
var combat_targets: Dictionary = {}


func faction_color(faction: int) -> Color:
	return Color("65ebd0") if faction == 1 else Color("f08075")


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
	var rival_home: Vector2i = units[-1].hex
	for neighbor in map.map_data["tiles"]:
		if HexMath.distance(rival_home, neighbor) == 3 and HexPathfinding.is_walkable(map.map_data["tiles"], neighbor) and territory.owner_at(neighbor) == 0 and not HexPathfinding.find_path(map.map_data["tiles"], rival_home, neighbor).is_empty():
			var defender: UnitState = UnitState.new(neighbor, "Rival garrison")
			defender.faction = 2
			defender.garrisoned = true
			units.append(defender)
			territory.owners[neighbor] = 2
			break
	queue_redraw()


func unit_position(unit: UnitState) -> Vector2:
	var point: Vector2 = world_map.hex_to_world(unit.hex)
	if not unit.path.is_empty():
		point = point.lerp(world_map.hex_to_world(unit.path[0]), unit.progress)
	return to_local(point)


func pick(global_point: Vector2, zoom_factor: float) -> UnitState:
	var nearest: UnitState = null
	var best: float = maxf(10.0, 9.0 / zoom_factor)
	for unit in units:
		var distance: float = unit_position(unit).distance_to(to_local(global_point))
		if unit.faction != 1:
			continue
		if distance < best:
			best = distance
			nearest = unit
	return nearest


func _physics_process(delta: float) -> void:
	combat_targets = CombatState.advance(delta, units)
	for index in range(units.size() - 1, -1, -1):
		if not units[index].is_alive():
			if selected == units[index]:
				selected = null
			units.remove_at(index)
	# No capture credit on the tick a squad arrives.
	territory.advance(delta, world_map.map_data["tiles"], units)
	for unit in units:
		if not unit.path.is_empty():
			unit.advance(delta)
	queue_redraw()


func _draw() -> void:
	if world_map == null:
		return
	_draw_territory()
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
	for unit in units:
		var point: Vector2 = unit_position(unit)
		if unit == selected:
			draw_arc(point, 13.0, 0.0, TAU, 24, Color("fff0ad"), 2.0, true)
		draw_circle(point, 9.0, Color("071522"))
		draw_circle(point, 6.5, faction_color(unit.faction))
		if unit.kind == "tank":
			draw_rect(Rect2(point - Vector2(7, 5), Vector2(14, 10)), faction_color(unit.faction))
			draw_line(point, point + Vector2(12, 0), faction_color(unit.faction), 3.0)
		draw_rect(Rect2(point + Vector2(-10, -17), Vector2(20, 3)), Color("071522"))
		draw_rect(Rect2(point + Vector2(-10, -17), Vector2(20.0 * unit.health / unit.max_health, 3)), faction_color(unit.faction))
		if unit.garrisoned:
			draw_rect(Rect2(point - Vector2(10, 10), Vector2(20, 20)), faction_color(unit.faction), false, 2.0)
		draw_line(point + Vector2(-3, -3), point + Vector2(3, 3), Color("12364c"), 2.0)
		draw_line(point + Vector2(-3, 3), point + Vector2(3, -3), Color("12364c"), 2.0)


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
