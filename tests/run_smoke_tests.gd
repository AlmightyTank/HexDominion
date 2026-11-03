extends SceneTree
## Run: godot --headless --path . --script res://tests/run_smoke_tests.gd
## No external test framework needed. Exits non-zero on a failed assertion.

var _successes: int = 0
var _failures: int = 0


func _init() -> void:
	call_deferred("_run_tests")


func _check(condition: bool, description: String) -> void:
	if condition:
		_successes += 1
	else:
		_failures += 1
		push_error("FAIL: %s" % description)


func _run_tests() -> void:
	for hex in [Vector2i.ZERO, Vector2i(1, -1), Vector2i(-6, 4), Vector2i(20, 10)]:
		var world_point: Vector2 = HexMath.axial_to_world(hex, 26.0)
		_check(HexMath.world_to_axial(world_point, 26.0) == hex, "Hex coordinate round trip %s" % hex)
	_check(HexMath.distance(Vector2i.ZERO, Vector2i(3, -2)) == 3, "Hex distance")
	var neighbors: Array[Vector2i] = HexMath.neighbors(Vector2i.ZERO)
	_check(neighbors.size() == 6, "Six neighbors")
	var unique: Dictionary = {}
	for neighbor in neighbors:
		unique[neighbor] = true
	_check(unique.size() == 6, "Neighbor directions are unique")

	for row in [0, 1, 2, 3, 13, 35]:
		for column in [0, 1, 15, 65]:
			var key: Vector2i = WorldMapData.offset_to_axial(column, row)
			_check(WorldMapData.axial_to_offset(key) == Vector2i(column, row), "Offset/axial round trip %s,%s" % [column, row])

	var columns: int = WorldMap.COLUMNS
	var rows: int = WorldMap.ROWS
	var world: Dictionary = WorldMapData.build(columns, rows)
	_check(not world.is_empty(), "World definition parses")
	if world.is_empty():
		print("Hex Dominion v0.1 Slice B: %d passed, %d failed" % [_successes, _failures])
		quit(1)
		return
	var tiles: Dictionary = world["tiles"]
	var counts: Dictionary = world["terrain_counts"]
	_check(tiles.size() == columns * rows, "All world hexes created")
	var num_land: int = tiles.size() - int(counts.get("ocean", 0))
	_check(float(num_land) / tiles.size() > 0.2 and float(num_land) / tiles.size() < 0.5, "Ocean/land ratio is plausible")
	_check(int(counts.get("city", 0)) == 14, "14 unique city hexes")
	_check(int(counts.get("resource", 0)) == 10, "10 unique resource hexes")
	for terrain in WorldMapData.TERRAIN_TYPES:
		_check(int(counts.get(terrain, 0)) > 0, "Terrain present: %s" % terrain)
	var continents: Dictionary = {}
	for tile in tiles.values():
		if tile["is_land"]:
			continents[String(tile["continent"])] = true
		if tile["terrain"] in ["city", "resource"]:
			_check(tile["is_land"], "Special site lies on land")
			_check(not String(tile["site_name"]).is_empty(), "Special site has name")
	_check(continents.size() == 6, "All six continent regions have hexes")
	var sample: Vector2i = WorldMapData.offset_to_axial(12, 12)
	# Geographic regression samples are deliberately away from coastlines.
	for sample_location in [
		[-100.0, 40.0, "North America"], [-60.0, -10.0, "South America"],
		[20.0, 10.0, "Africa"], [90.0, 50.0, "Eurasia"],
		[135.0, -25.0, "Australia"], [0.0, -85.0, "Antarctica"],
		[-40.0, 72.0, "North America"], [-140.0, 0.0, "Open Ocean"],
		[-30.0, 0.0, "Open Ocean"], [80.0, -25.0, "Open Ocean"],
	]:
		var row: int = clampi(int((90.0 - float(sample_location[1])) / 180.0 * rows), 0, rows - 1)
		var column: int = clampi(roundi((float(sample_location[0]) + 180.0) / 360.0 * (columns + 0.5) - 0.5 - 0.5 * (row & 1)), 0, columns - 1)
		var tile: Dictionary = tiles[WorldMapData.offset_to_axial(column, row)]
		_check(tile["continent"] == sample_location[2], "Earth geography at %s" % str(sample_location))
	var second_world: Dictionary = WorldMapData.build(columns, rows)
	for climate in [
		[-40.0, 72.0, "snow"], [0.0, -85.0, "snow"],
		[100.0, 70.0, "tundra"], [20.0, 25.0, "desert"],
		[-60.0, -5.0, "forest"], [-140.0, 82.0, "ocean"],
	]:
		var row: int = clampi(int((90.0 - float(climate[1])) / 180.0 * rows), 0, rows - 1)
		var column: int = clampi(roundi((float(climate[0]) + 180.0) / 360.0 * (columns + 0.5) - 0.5 - 0.5 * (row & 1)), 0, columns - 1)
		var tile: Dictionary = tiles[WorldMapData.offset_to_axial(column, row)]
		_check(tile["biome"] == climate[2], "Earth climate at %s" % str(climate))
	var climate_preserves_land: bool = true
	for tile in tiles.values():
		if tile["is_land"] != (tile["biome"] != "ocean"):
			climate_preserves_land = false
	_check(climate_preserves_land, "Climate preserves land/ocean classification")
	_check(tiles[sample] == second_world["tiles"][sample], "Map generation deterministic")
	_check(world["terrain_counts"] == second_world["terrain_counts"], "Distribution deterministic")
	_test_movement()
	_test_territory()
	_test_combat()
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_check(game.units.units.size() == 4, "Three starter squads and a rival garrison on the live map")
	for unit in game.units.units:
		_check(HexPathfinding.is_walkable(tiles, unit.hex), "Starter squad on land")
	var victim: UnitState = game.units.units[-1]
	var attacker: UnitState = game.units.units[0]
	attacker.hex = victim.hex
	attacker.health = 100.0
	victim.health = 1.0
	game.units.selected = victim
	game.units._physics_process(0.1)
	_check(not game.units.units.has(victim) and game.units.selected == null, "Death removes unit and clears selection")
	game.units._physics_process(3.0)
	_check(game.units.territory.owner_at(attacker.hex) == 1, "Defeated garrison allows territory capture")
	game.free()
	print("Hex Dominion v0.1 Slice E: %d passed, %d failed" % [_successes, _failures])
	quit(1 if _failures > 0 else 0)


func _test_combat() -> void:
	var rifle: UnitState = UnitState.new()
	var enemy: UnitState = UnitState.new(Vector2i(1, 0))
	enemy.faction = 2
	var forces: Array[UnitState] = [rifle, enemy]
	CombatState.advance(1.0, forces)
	_check(rifle.health == 80.0 and enemy.health == 80.0, "Adjacent rifles exchange simultaneous damage")
	enemy.hex = Vector2i(3, 0)
	CombatState.advance(1.0, forces)
	_check(rifle.health == 80.0 and enemy.health == 80.0, "No damage outside range")
	enemy.hex = Vector2i(1, 0)
	enemy.faction = 1
	CombatState.advance(1.0, forces)
	_check(rifle.health == 80.0 and enemy.health == 80.0, "No friendly fire")
	enemy.faction = 2
	rifle.configure_kind("tank")
	CombatState.advance(1.0, forces)
	_check(rifle.health == 230.0 and enemy.health == 35.0, "Tank has distinct durability and damage")
	rifle.path.append(Vector2i(1, 0))
	CombatState.advance(1.0, forces)
	_check(enemy.health == 35.0 and rifle.health == 210.0, "Moving units take damage but do not fire")
	rifle.path.clear()
	rifle.health = 10.0
	enemy.health = 10.0
	CombatState.advance(1.0, forces)
	_check(not rifle.is_alive() and not enemy.is_alive(), "Lethal exchange is simultaneous and clamps health")
	_check(CombatState.advance(1.0, forces).is_empty(), "Dead units cannot attack or be targeted")
	_check(not rifle.order_move({Vector2i.ZERO: {"is_land": true}}, Vector2i.ZERO), "Dead units reject orders")
	var state: TerritoryState = TerritoryState.new()
	state.advance(10.0, {Vector2i.ZERO: {"is_land": true}}, forces)
	_check(state.owners.is_empty(), "Dead units cannot capture")


func _test_territory() -> void:
	var tiles: Dictionary = {Vector2i.ZERO: {"is_land": true}, Vector2i(1, 0): {"is_land": true}}
	var state: TerritoryState = TerritoryState.new()
	var squad: UnitState = UnitState.new()
	var forces: Array[UnitState] = [squad]
	state.advance(1.0, tiles, forces)
	_check(state.owner_at(Vector2i.ZERO) == 0 and state.captures.has(Vector2i.ZERO), "Capture needs sustained occupation")
	state.advance(2.0, tiles, forces)
	_check(state.owner_at(Vector2i.ZERO) == 1 and state.captures.is_empty(), "Capture completes after three seconds")
	squad.hex = Vector2i(1, 0)
	state.advance(1.0, tiles, forces)
	_check(state.owner_at(Vector2i.ZERO) == 1, "Ownership persists after departure")
	var rival: UnitState = UnitState.new(Vector2i(1, 0))
	rival.faction = 2
	rival.garrisoned = true
	forces.append(rival)
	state.advance(10.0, tiles, forces)
	_check(state.owner_at(squad.hex) == 0 and state.captures[squad.hex]["elapsed"] == 1.0, "Contested capture freezes")
	forces.erase(squad)
	state.advance(2.0, tiles, forces)
	_check(state.owner_at(rival.hex) == 0 and state.captures[rival.hex]["faction"] == 2, "New captor resets previous progress")
	state.advance(1.0, tiles, forces)
	_check(state.owner_at(rival.hex) == 2, "Rival can capture territory")
	_check(not rival.order_move(tiles, Vector2i.ZERO), "Garrison refuses movement")
	rival.garrisoned = false
	_check(rival.order_move(tiles, Vector2i.ZERO), "Released garrison can move")
	state.advance(10.0, tiles, forces)
	_check(not state.captures.has(Vector2i.ZERO), "Moving units cannot capture")
	rival.advance(1.0)
	state.advance(1.0, tiles, forces)
	forces.clear()
	state.advance(1.0, tiles, forces)
	_check(state.captures.is_empty(), "Abandoned capture resets")
	forces.append(rival)
	state.advance(3.0, tiles, forces)
	_check(state.owner_at(Vector2i.ZERO) == 2, "Empty enemy territory can be recaptured")


func _test_movement() -> void:
	var tiles: Dictionary = {}
	for q in range(5):
		for r in range(3):
			tiles[Vector2i(q, r)] = {"is_land": true}
	var start: Vector2i = Vector2i.ZERO
	var goal: Vector2i = Vector2i(4, 0)
	var route: Array[Vector2i] = HexPathfinding.find_path(tiles, start, goal)
	_check(route.size() == 5 and route[0] == start and route[-1] == goal, "Shortest land route includes endpoints")
	tiles[Vector2i(2, 0)]["is_land"] = false
	route = HexPathfinding.find_path(tiles, start, goal)
	_check(route.size() > 5, "Route detours around ocean")
	for index in range(1, route.size()):
		_check(HexMath.distance(route[index - 1], route[index]) == 1 and tiles[route[index]]["is_land"], "Route uses adjacent land cells")
	_check(HexPathfinding.find_path(tiles, start, start).size() == 1, "Already at destination")
	_check(HexPathfinding.find_path(tiles, start, Vector2i(99, 99)).is_empty(), "Off-map rejected")
	_check(HexPathfinding.find_path(tiles, start, Vector2i(2, 0)).is_empty(), "Ocean destination rejected")
	var unit: UnitState = UnitState.new(start)
	_check(unit.order_move(tiles, goal), "Move order accepted")
	unit.advance(unit.seconds_per_hex * 0.5)
	_check(unit.hex == start and is_equal_approx(unit.progress, 0.5), "Partial edge keeps logical occupancy")
	var prior: Array[Vector2i] = unit.path.duplicate()
	_check(not unit.order_move(tiles, Vector2i(2, 0)) and unit.path == prior, "Invalid order preserves active route")
	var next: Vector2i = unit.path[0]
	_check(unit.order_move(tiles, start) and unit.path[0] == next and is_equal_approx(unit.progress, 0.5), "Retarget preserves in-flight edge")
	unit.advance(20.0)
	_check(unit.hex == start and unit.path.is_empty() and unit.progress == 0.0, "Large tick reaches destination without overshoot")
	var a: UnitState = UnitState.new(start)
	var b: UnitState = UnitState.new(start)
	a.order_move(tiles, goal)
	b.order_move(tiles, goal)
	a.advance(0.9)
	for index in range(9):
		b.advance(0.1)
	_check(a.hex == b.hex and is_equal_approx(a.progress, b.progress), "Movement independent of tick partition")
	for r in range(3):
		tiles[Vector2i(2, r)]["is_land"] = false
	_check(HexPathfinding.find_path(tiles, start, goal).is_empty(), "Disconnected land rejected")
