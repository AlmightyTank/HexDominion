extends RefCounted

static func run(check: Callable) -> void:
	var tiles: Dictionary = _tiles()
	var start: Vector2i = Vector2i.ZERO
	var goal: Vector2i = Vector2i(2, 0)
	tiles[Vector2i(1, 0)]["terrain"] = "mountain"
	var infantry: Array[Vector2i] = HexPathfinding.find_path(tiles, start, goal, "rifle")
	var armor: Array[Vector2i] = HexPathfinding.find_path(tiles, start, goal, "tank")
	check.call(infantry.size() == 3 and armor.size() == 4 and Vector2i(1, 0) not in armor, "Armor avoids costly mountain shortcut while infantry takes it")
	tiles.erase(Vector2i(0, 1))
	tiles.erase(Vector2i(1, 1))
	check.call(HexPathfinding.find_path(tiles, start, goal, "tank").size() == 3, "Only available mountain route remains legal for heavy vehicles")
	tiles = _tiles()
	tiles[Vector2i(1, 0)]["terrain"] = "forest"
	for hex in [Vector2i(0, 1), Vector2i(1, 1)]:
		tiles[hex]["terrain"] = "desert"
	check.call(HexPathfinding.find_path(tiles, start, goal, "tank").size() == 4 and HexPathfinding.find_path(tiles, start, goal, "rifle").size() == 3, "Armor prefers a longer fast desert route; infantry prefers forest shortcut")
	check.call(is_equal_approx(TerrainRules.movement_cost(tiles, start, Vector2i(0, 1), "tank"), 0.9), "Desert armor movement advantage is limited to ten percent")
	tiles = _tiles()
	tiles[start]["river_neighbors"] = [Vector2i(1, 0)]
	check.call(TerrainRules.crosses_river(tiles, Vector2i(1, 0), start), "River crossing detection is symmetric even with one-bank metadata")
	check.call(is_equal_approx(TerrainRules.movement_cost(tiles, start, Vector2i(1, 0), "tank"), 2.0), "River adds armor crossing time")
	tiles[Vector2i(1, 0)]["narrow_crossing"] = true
	check.call(is_equal_approx(TerrainRules.movement_cost(tiles, start, Vector2i(1, 0), "tank"), 2.75), "Narrow crossing and river penalties stack once")
	check.call(HexPathfinding.find_path(tiles, start, goal, "tank").size() == 4, "Pathfinding avoids costly river choke when faster alternate exists")
	tiles.erase(Vector2i(0, 1))
	tiles.erase(Vector2i(1, 1))
	check.call(HexPathfinding.find_path(tiles, start, goal, "tank").size() == 3, "River choke never removes the only valid land route")
	check.call(HexPathfinding.find_path(tiles, start, start).size() == 1 and HexPathfinding.find_path(tiles, start, Vector2i(99, 99)).is_empty(), "Weighted routing retains same-hex and off-map behavior")
	for terrain in WorldMapData.TERRAIN_TYPES:
		if terrain == "ocean":
			continue
		tiles[Vector2i(1, 0)]["terrain"] = terrain
		for kind in ["rifle", "tank"]:
			check.call(HexPathfinding.find_path(tiles, start, goal, kind).size() == 3, "%s can traverse sole %s crossing" % [kind, terrain])
	tiles[Vector2i(1, 0)]["is_land"] = false
	check.call(HexPathfinding.find_path(tiles, start, goal).is_empty(), "Ocean still blocks travel without leaking through expensive paths")
	_test_optimality(check)
	_test_movement(check)
	_test_combat(check)
	_test_world(check)

static func _tiles() -> Dictionary:
	var result: Dictionary = {}
	for hex in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		result[hex] = {"is_land": true, "terrain": "plains", "biome": "plains"}
	return result

static func _cost(tiles: Dictionary, path: Array[Vector2i], kind: String) -> float:
	var result: float = 0.0
	for index in range(1, path.size()):
		result += TerrainRules.movement_cost(tiles, path[index - 1], path[index], kind)
	return result

static func _oracle(tiles: Dictionary, start: Vector2i, goal: Vector2i, kind: String) -> float:
	# Independent exhaustive relaxation, intentionally not the A* heap/heuristic.
	var distance: Dictionary = {start: 0.0}
	for iteration in range(tiles.size()):
		var changed: bool = false
		for hex in tiles:
			if not distance.has(hex):
				continue
			for neighbor in HexMath.neighbors(hex):
				var candidate: float = distance[hex] + TerrainRules.movement_cost(tiles, hex, neighbor, kind)
				if candidate < distance.get(neighbor, INF):
					distance[neighbor] = candidate
					changed = true
		if not changed:
			break
	return distance.get(goal, INF)

static func _test_optimality(check: Callable) -> void:
	var terrains: Array[String] = ["plains", "forest", "mountain", "desert", "city", "snow", "tundra"]
	for seed_index in range(12):
		var tiles: Dictionary = {}
		for y in range(5):
			for x in range(5):
				var hex: Vector2i = Vector2i(x, y)
				tiles[hex] = {"is_land": (x + y + seed_index) % 6 != 0, "terrain": terrains[(x * 13 + y * 17 + seed_index) % terrains.size()], "narrow_crossing": (x * 3 + y + seed_index) % 9 == 0}
		tiles[Vector2i.ZERO]["is_land"] = true
		tiles[Vector2i(4, 4)]["is_land"] = true
		for kind in ["rifle", "tank"]:
			var route: Array[Vector2i] = HexPathfinding.find_path(tiles, Vector2i.ZERO, Vector2i(4, 4), kind)
			var expected: float = _oracle(tiles, Vector2i.ZERO, Vector2i(4, 4), kind)
			check.call((route.is_empty() and not is_finite(expected)) or (not route.is_empty() and is_equal_approx(_cost(tiles, route, kind), expected)), "Weighted route matches independent shortest-time oracle %d %s" % [seed_index, kind])
			check.call(route == HexPathfinding.find_path(tiles, Vector2i.ZERO, Vector2i(4, 4), kind), "Weighted routing is deterministic %d %s" % [seed_index, kind])

static func _test_movement(check: Callable) -> void:
	var tiles: Dictionary = _tiles()
	tiles.erase(Vector2i(0, 1))
	tiles.erase(Vector2i(1, 1))
	tiles[Vector2i(1, 0)]["terrain"] = "mountain"
	tiles[Vector2i(1, 0)]["river_neighbors"] = [Vector2i(2, 0)]
	for kind in ["rifle", "tank"]:
		var unit: UnitState = UnitState.new()
		unit.configure_kind(kind)
		unit.order_move(tiles, Vector2i(2, 0))
		var first_duration: float = unit.seconds_per_hex * TerrainRules.movement_cost(tiles, Vector2i.ZERO, Vector2i(1, 0), kind)
		unit.advance(first_duration / 2.0, tiles)
		check.call(unit.hex == Vector2i.ZERO and is_equal_approx(unit.progress, 0.5), "Actual %s edge interpolation uses terrain duration" % kind)
		var progress: float = unit.progress
		check.call(not unit.order_move(tiles, Vector2i(99, 99)) and unit.progress == progress, "Invalid terrain order preserves active edge %s" % kind)
		check.call(unit.order_move(tiles, Vector2i.ZERO) and unit.path[0] == Vector2i(1, 0) and unit.progress == progress, "Retargeting preserves terrain-weighted in-flight edge %s" % kind)
		var single: UnitState = UnitState.new()
		var partitioned: UnitState = UnitState.new()
		for mover in [single, partitioned]:
			mover.configure_kind(kind)
			mover.order_move(tiles, Vector2i(2, 0))
		var duration: float = first_duration + single.seconds_per_hex * TerrainRules.movement_cost(tiles, Vector2i(1, 0), Vector2i(2, 0), kind) * 0.4
		single.advance(duration, tiles)
		for index in range(100):
			partitioned.advance(duration / 100.0, tiles)
		check.call(single.hex == partitioned.hex and single.path == partitioned.path and is_equal_approx(single.progress, partitioned.progress) and is_equal_approx(single.progress, 0.4), "Mixed terrain movement preserves leftover time and tick partition %s" % kind)
		partitioned.advance(INF, tiles)
		check.call(is_equal_approx(partitioned.progress, single.progress), "Nonfinite movement delta rejected %s" % kind)
		single.advance(1000, tiles)
		check.call(single.hex == Vector2i(2, 0) and single.path.is_empty() and single.progress == 0, "Large terrain tick completes path exactly %s" % kind)
	check.call(TerrainRules.movement_cost({Vector2i.ZERO: {"is_land": true}, Vector2i(1, 0): {"is_land": true, "terrain": "resource", "biome": "mountain"}}, Vector2i.ZERO, Vector2i(1, 0), "tank") == 4.0, "Resource markers preserve underlying terrain restrictions")

static func _damage(attacker_kind: String, defender_kind: String, attack_ground: String, defense_ground: String, moving: bool = false) -> float:
	var attacker: UnitState = UnitState.new()
	attacker.configure_kind(attacker_kind)
	var defender: UnitState = UnitState.new(Vector2i(1, 0))
	defender.configure_kind(defender_kind)
	defender.faction = 2
	defender.damage_per_second = 0
	if moving:
		defender.path.append(Vector2i(2, 0))
	var roster: Array[UnitState] = [attacker, defender]
	var before: float = defender.health
	CombatState.advance(1.0, roster, {attacker.hex: {"terrain": attack_ground}, defender.hex: {"terrain": defense_ground}})
	return before - defender.health

static func _test_combat(check: Callable) -> void:
	check.call(is_equal_approx(_damage("rifle", "rifle", "plains", "forest"), 17), "Forest grants stationary infantry 15 percent cover")
	check.call(is_equal_approx(_damage("rifle", "tank", "plains", "forest"), 20), "Forest cover is infantry-specific")
	check.call(is_equal_approx(_damage("rifle", "rifle", "plains", "mountain"), 16), "Mountain infantry defenders take 20 percent less damage")
	check.call(is_equal_approx(_damage("rifle", "tank", "plains", "mountain"), 18), "Mountains grant armored defenders ten percent protection")
	check.call(is_equal_approx(_damage("rifle", "rifle", "plains", "city"), 15) and is_equal_approx(_damage("rifle", "tank", "plains", "city"), 17), "Cities provide infantry and armor defensive positions")
	check.call(is_equal_approx(_damage("tank", "rifle", "desert", "plains"), 49.5), "Desert armor gains ten percent outgoing damage")
	check.call(is_equal_approx(_damage("tank", "rifle", "desert", "city"), 37.125), "Attacker terrain and defender cover combine multiplicatively")
	check.call(is_equal_approx(_damage("rifle", "rifle", "plains", "city", true), 20), "Moving defenders cannot carry stationary city cover between tiles")
	check.call(is_equal_approx(_damage("rifle", "rifle", "snow", "plains"), 20) and is_equal_approx(_damage("rifle", "rifle", "tundra", "plains"), 20) and is_equal_approx(_damage("tank", "rifle", "snow", "plains"), 45) and is_equal_approx(_damage("tank", "rifle", "tundra", "plains"), 45), "Snow and tundra have no combat penalties for either unit kind")
	var attacker: UnitState = UnitState.new()
	attacker.configure_kind("tank")
	var roster: Array[UnitState] = [attacker]
	var economy: EconomyState = EconomyState.new()
	economy.faction = 2
	economy.add_building(Vector2i(1, 0), "barracks")
	var economies: Array[EconomyState] = [economy]
	CombatState.attack_extractors(1, roster, economies, {}, {Vector2i.ZERO: {"terrain": "desert"}})
	check.call(is_equal_approx(economy.buildings[Vector2i(1, 0)]["health"], 250.5), "Terrain outgoing damage also applies to infrastructure attacks")

static func _test_world(check: Callable) -> void:
	var world: Dictionary = WorldMapData.build(120, 70)
	var tiles: Dictionary = world["tiles"]
	var rivers: int = 0
	var narrow: int = 0
	var valid: bool = true
	for hex in tiles:
		narrow += int(tiles[hex].get("narrow_crossing", false))
		for neighbor in tiles[hex].get("river_neighbors", []):
			rivers += 1
			valid = valid and HexMath.distance(hex, neighbor) == 1 and HexPathfinding.is_walkable(tiles, hex) and HexPathfinding.is_walkable(tiles, neighbor) and hex in tiles[neighbor].get("river_neighbors", [])
	check.call(rivers > 0 and valid, "Real Earth river data produces symmetric adjacent land crossings")
	check.call(narrow > 0, "Earth coastline topology marks narrow land crossings")
	check.call(world == WorldMapData.build(120, 70), "Terrain and river generation remain deterministic for save reconstruction")
