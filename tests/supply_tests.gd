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
		var home := Vector2i.ZERO
		var city := Vector2i(2, 0)
		var deposit := Vector2i(4, 0)
		var corridor := Vector2i(1, 0)
		tiles[city]["terrain"] = "city"
		tiles[deposit]["terrain"] = "resource"
		economy.add_building(home, "headquarters")
		economy.add_building(deposit, "extractor")

		check.call(economy.income_rate(tiles, territory) == 0 and economy.income_status(deposit, tiles, territory)["supplied"], "Faction %d retains supply connectivity without passive income" % faction)
		economy.advance(10.0, tiles, territory)
		check.call(economy.credits == 0 and economy.income_last_seconds() == 0, "HQ, city and extractor mint no credits over time")
		var rebuilds: int = economy.supply.rebuild_count
		for iteration in range(100):
			economy.income_rate(tiles, territory)
		check.call(economy.supply.rebuild_count == rebuilds and economy.credits == 0, "Repeated supply queries neither rebuild unchanged graphs nor credit money")

		territory.owners[corridor] = 3 - faction
		check.call(not economy.income_status(deposit, tiles, territory)["supplied"] and economy.income_rate(tiles, territory) == 0, "Enemy corridor capture isolates supply without changing income")
		territory.owners[corridor] = faction
		check.call(economy.income_status(deposit, tiles, territory)["supplied"] and economy.income_rate(tiles, territory) == 0, "Recapturing corridor restores connectivity but mints nothing")
		territory.contested[corridor] = true
		check.call(not economy.income_status(deposit, tiles, territory)["supplied"], "Contested corridor cannot carry supply")
		territory.contested.clear()

		var route: Array[Vector2i] = []
		for x in range(5):
			var hex := Vector2i(x, 0)
			tiles[hex]["road"] = true
			route.append(hex)
		check.call(SupplyNetwork.qualifies_delivery_route(route, tiles, territory, faction), "Continuous friendly road route qualifies for a delivery bonus")
		check.call(economy.credits == 0 and economy.income_rate(tiles, territory) == 0, "Road connectivity alone mints no money")
		var payout: float = economy.credit_approved_income(100.0, EconomyState.SOURCE_DELIVERY, territory, true)
		check.call(is_equal_approx(payout, 110.0) and is_equal_approx(economy.credits, 110.0), "One qualifying delivery receives the road bonus exactly once")
		for iteration in range(10):
			economy.income_rate(tiles, territory)
		check.call(is_equal_approx(economy.credits, 110.0) and is_equal_approx(economy.income_last_seconds(), 110.0), "Repeated queries never compound an approved payout")
		check.call(economy.credit_approved_income(25.0, "city", territory, true) == 0 and is_equal_approx(economy.credits, 110.0), "Unapproved income sources are rejected")
		check.call(economy.credit_approved_income(NAN, EconomyState.SOURCE_DELIVERY, territory, true) == 0 and CreditsAccount.valid_snapshot(economy.account.snapshot()), "Invalid payouts cannot corrupt the shared wallet")

		tiles[corridor].erase("road")
		check.call(not SupplyNetwork.qualifies_delivery_route(route, tiles, territory, faction), "A road gap disqualifies the delivery route")
		territory.owners[corridor] = 3 - faction
		check.call(not SupplyNetwork.qualifies_delivery_route(route, tiles, territory, faction), "A hostile road cell disqualifies the delivery route")
		territory.owners[corridor] = faction
		tiles[corridor]["road"] = true
		territory.contested[corridor] = true
		check.call(not SupplyNetwork.qualifies_delivery_route(route, tiles, territory, faction), "A contested road cell disqualifies the delivery route")

		var other: EconomyState = EconomyState.new(0)
		other.faction = 3 - faction
		check.call(other.income_rate(tiles, territory) == 0, "Factions never borrow another faction's supply root")
