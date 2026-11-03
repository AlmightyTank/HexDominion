extends RefCounted

static func run(check: Callable) -> void:
	for faction in [1, 2]:
		var tiles: Dictionary = {}
		var territory: TerritoryState = TerritoryState.new()
		var economy: EconomyState = EconomyState.new(0)
		economy.faction = faction
		for x in range(5):
			var hex: Vector2i = Vector2i(x, 0)
			tiles[hex] = {"is_land": true, "terrain": "plains"}
			territory.owners[hex] = faction
		var home: Vector2i = Vector2i.ZERO
		var city: Vector2i = Vector2i(2, 0)
		var deposit: Vector2i = Vector2i(4, 0)
		var corridor: Vector2i = Vector2i(1, 0)
		tiles[city]["terrain"] = "city"
		tiles[deposit]["terrain"] = "resource"
		economy.add_building(home, "headquarters")
		economy.add_building(deposit, "extractor")
		check.call(economy.income_rate(tiles, territory) == 8, "Faction %d supplies city and extractor over ordinary land" % faction)
		economy.advance(0.25, tiles, territory)
		check.call(economy.credits == 2, "Supply credits exact fractional income once")
		var rebuilds: int = economy.supply.rebuild_count
		for iteration in range(100):
			economy.income_rate(tiles, territory)
		check.call(economy.supply.rebuild_count == rebuilds and economy.credits == 2, "Repeated income queries neither rebuild graph nor credit money")
		territory.owners[corridor] = 3 - faction
		check.call(economy.income_rate(tiles, territory) == 5 and territory.owner_at(city) == faction and not economy.income_status(deposit, tiles, territory)["supplied"], "Enemy corridor capture isolates still-owned city and extractor")
		territory.owners[corridor] = faction
		check.call(economy.income_rate(tiles, territory) == 8, "Recapturing corridor restores income immediately")
		territory.contested[corridor] = true
		check.call(economy.income_rate(tiles, territory) == 5, "Contested corridor cannot carry supply")
		territory.contested.clear()
		for x in range(1, 4):
			tiles[Vector2i(x, 0)]["road"] = true
		check.call(is_equal_approx(economy.income_rate(tiles, territory), 8.3), "Road-adjacent HQ city and extractor endpoints earn exactly ten percent bonus")
		check.call(economy.income_status(city, tiles, territory)["road_bonus"] and economy.income_status(deposit, tiles, territory)["road_bonus"], "Both economic endpoint types report road connection")
		territory.owners[Vector2i(3, 0)] = 3 - faction
		check.call(is_equal_approx(economy.income_rate(tiles, territory), 6.1) and tiles[Vector2i(3, 0)]["road"], "Enemy road capture cuts downstream supply without deleting infrastructure")
		territory.owners[Vector2i(3, 0)] = faction
		check.call(is_equal_approx(economy.income_rate(tiles, territory), 8.3), "Road recapture restores income and bonus once")
		for iteration in range(10):
			check.call(is_equal_approx(economy.income_rate(tiles, territory), 8.3), "Road bonus never compounds across repeated queries")
		economy.credits = 0
		economy.advance(2, tiles, territory)
		check.call(is_equal_approx(economy.credits, 16.6) and CreditsAccount.valid_snapshot(economy.account.snapshot()), "Road income credits once with valid nonnegative ledger")
		tiles[city].erase("road")
		check.call(is_equal_approx(economy.income_rate(tiles, territory), 8.1) and not economy.income_status(deposit, tiles, territory)["road_bonus"], "Unroaded city can receive bonus but cannot bridge separate highways")
		tiles[corridor].erase("road")
		check.call(economy.income_rate(tiles, territory) == 8, "Road gap removes bonus without interrupting basic supply")
		tiles[corridor]["is_land"] = false
		check.call(economy.income_rate(tiles, territory) == 5, "Terrain becoming impassable invalidates cached supply")
		tiles[corridor]["is_land"] = true
		check.call(economy.income_rate(tiles, territory) == 8, "Restored land reconnects without cached stale isolation")
		economy.damage_building(deposit, 10000)
		check.call(economy.income_rate(tiles, territory) == 6, "Destroyed extractor no longer earns income")
		economy.add_building(deposit, "extractor")
		economy.buildings[deposit]["construction"] = 0.0
		check.call(economy.income_rate(tiles, territory) == 6, "Unfinished supplied extractor cannot earn income")
		economy.buildings[deposit]["construction"] = EconomyState.BUILD_SECONDS["extractor"]
		economy.add_building(Vector2i(3, 0), "factory")
		check.call(economy.low_power(territory) and economy.income_rate(tiles, territory) == 6, "Supply does not bypass low-power extractor restriction")
		economy.buildings.erase(Vector2i(3, 0))
		territory.contested[home] = true
		check.call(economy.income_rate(tiles, territory) == 0, "Contested HQ cannot originate supply")
		territory.contested.clear()
		territory.owners[home] = 3 - faction
		check.call(economy.income_rate(tiles, territory) == 0, "Lost HQ cannot supply original faction")
		territory.owners[home] = faction
		economy.damage_building(home, 10000)
		check.call(economy.income_rate(tiles, territory) == 0, "Destroyed HQ disconnects all economic locations")
		economy.add_building(home, "headquarters")
		economy.buildings[home]["construction"] = 11.0
		economy.credits = 0
		economy.advance(2, tiles, territory)
		check.call(economy.credits == 8 and economy.income_rate(tiles, territory) == 8, "HQ completion mid-tick supplies income only for subsequent time")
		var other: EconomyState = EconomyState.new(0)
		other.faction = 3 - faction
		check.call(other.income_rate(tiles, territory) == 0, "Factions never borrow each other's HQ or friendly corridor")
