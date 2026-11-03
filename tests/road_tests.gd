extends RefCounted

static func run(check: Callable) -> void:
	var junction: Dictionary = {Vector2i.ZERO: {"is_land": true, "terrain": "plains", "road": true}}
	var ownership: TerritoryState = TerritoryState.new()
	ownership.owners[Vector2i.ZERO] = 1
	for hex in HexMath.neighbors(Vector2i.ZERO):
		junction[hex] = {"is_land": true, "terrain": "forest", "road": true}
		ownership.owners[hex] = 1
		check.call(Vector2i.ZERO in RoadRules.neighbors(junction, hex) and hex in RoadRules.neighbors(junction, Vector2i.ZERO), "Rendered road adjacency is reciprocal in direction %s" % hex)
	check.call(RoadRules.neighbors(junction, Vector2i.ZERO).size() == 6, "Road junction connects all six directions")
	var endpoint: Vector2i = HexMath.neighbors(Vector2i.ZERO)[0]
	check.call(RoadRules.connected(junction, Vector2i.ZERO, endpoint, ownership, 1), "Friendly supply connectivity works")
	ownership.owners[endpoint] = 2
	check.call(RoadRules.connected(junction, Vector2i.ZERO, endpoint) and not RoadRules.connected(junction, Vector2i.ZERO, endpoint, ownership, 1), "Capture preserves physical roads but breaks friendly supply network")
	ownership.owners[endpoint] = 1
	ownership.contested[endpoint] = true
	check.call(not RoadRules.connected(junction, Vector2i.ZERO, endpoint, ownership, 1), "Contested roads excluded from friendly supply")
	check.call(not RoadRules.connected(junction, Vector2i.ZERO, Vector2i(99, 99)), "Disconnected road endpoint rejected")
	check.call(RoadRules.connected(junction, Vector2i.ZERO, Vector2i.ZERO) and not RoadRules.connected(junction, Vector2i(99, 99), Vector2i(99, 99)), "Same-cell connectivity requires road")
	var tiles: Dictionary = {}
	var territory: TerritoryState = TerritoryState.new()
	var economy: EconomyState = EconomyState.new(1000)
	for x in range(5):
		for y in range(2):
			var hex: Vector2i = Vector2i(x, y)
			tiles[hex] = {"is_land": true, "terrain": "plains"}
			territory.owners[hex] = 1
	check.call(RoadRules.build(Vector2i.ZERO, tiles, territory, economy), "Road builds on owned land")
	check.call(economy.credits == 900, "Road debits exactly 100")
	check.call(not RoadRules.build(Vector2i.ZERO, tiles, territory, economy) and economy.credits == 900, "Duplicate road has no debit")
	for x in range(1, 5):
		RoadRules.build(Vector2i(x, 0), tiles, territory, economy)
	for kind in ["rifle", "tank"]:
		check.call(is_equal_approx(TerrainRules.movement_cost(tiles, Vector2i.ZERO, Vector2i(1, 0), kind), 1.0 / 1.3), "Road speed is 30 percent faster for " + kind)
		var unit: UnitState = UnitState.new(Vector2i.ZERO)
		unit.configure_kind(kind)
		unit.order_move(tiles, Vector2i(4, 0))
		unit.advance(unit.seconds_per_hex * 4.0 / 1.3, tiles)
		check.call(unit.hex == Vector2i(4, 0), "Unit follows highway with correct travel duration " + kind)
		var route: Array[Vector2i] = HexPathfinding.find_path(tiles, Vector2i.ZERO, Vector2i(4, 0), kind)
		check.call(route.size() == 5 and route[2] == Vector2i(2, 0), "Pathfinding uses fastest road " + kind)
	territory.owners[Vector2i.ZERO] = 2
	check.call(tiles[Vector2i.ZERO]["road"] and is_equal_approx(TerrainRules.movement_cost(tiles, Vector2i.ZERO, Vector2i(1, 0)), 1.0 / 1.3), "Captured roads persist and remain usable")
	for terrain in ["forest", "desert", "city"]:
		tiles[Vector2i(0, 1)]["terrain"] = terrain
		check.call(RoadRules.can_build(Vector2i(0, 1), tiles, territory, economy), "Road supports " + terrain)
	for terrain in ["mountain", "snow", "tundra", "ocean"]:
		tiles[Vector2i(0, 1)]["terrain"] = terrain
		check.call(not RoadRules.can_build(Vector2i(0, 1), tiles, territory, economy), "Road rejects " + terrain)
	tiles[Vector2i(0, 1)]["terrain"] = "plains"
	territory.contested[Vector2i(0, 1)] = true
	check.call(not RoadRules.build(Vector2i(0, 1), tiles, territory, economy), "Contested road placement rejected")
	territory.contested.clear()
	economy.credits = 99
	check.call(not RoadRules.build(Vector2i(0, 1), tiles, territory, economy) and economy.credits == 99, "Unaffordable road cannot overdraw")
	check.call(not RoadRules.build(Vector2i(-99, -99), tiles, territory, economy), "Off map road rejected")
	var detour: Dictionary = {}
	for hex in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1), Vector2i(1, 1)]:
		detour[hex] = {"is_land": true, "terrain": "forest", "road": hex != Vector2i(1, 0)}
	for kind in ["rifle", "tank"]:
		# Make the direct middle cell slower so the longer highway wins by travel time.
		detour[Vector2i(1, 0)]["terrain"] = "mountain"
		detour[Vector2i(1, 0)]["river_neighbors"] = [Vector2i.ZERO]
		var route: Array[Vector2i] = HexPathfinding.find_path(detour, Vector2i.ZERO, Vector2i(2, 0), kind)
		check.call(route.size() == 4 and not Vector2i(1, 0) in route, "Longer faster highway preferred " + kind)
