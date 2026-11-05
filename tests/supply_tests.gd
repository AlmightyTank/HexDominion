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
	_test_physical_collection(check)


static func _truck(hex: Vector2i, faction: int = 1) -> UnitState:
	var truck: UnitState = UnitState.new(hex, "Supply Truck")
	truck.configure_kind("supply_truck")
	truck.faction = faction
	return truck


static func _test_physical_collection(check: Callable) -> void:
	var tiles: Dictionary = {}
	var territory: TerritoryState = TerritoryState.new()
	for x in range(6):
		var hex: Vector2i = Vector2i(x, 0)
		tiles[hex] = {"is_land": true, "terrain": "plains", "road": true}
		territory.owners[hex] = 1
	var deposit := Vector2i.ZERO
	var center := Vector2i(2, 0)
	SupplyLogistics.configure_deposit(tiles[deposit], deposit, "small")
	var economy: EconomyState = EconomyState.new(0)
	economy.add_building(Vector2i(1, 0), "headquarters")
	economy.add_building(center, "supply_center")
	var rival: EconomyState = EconomyState.new(0)
	rival.faction = 2
	var economies: Array[EconomyState] = [economy, rival]
	var truck: UnitState = _truck(deposit)
	var roster: Array[UnitState] = [truck]
	check.call(SupplyLogistics.assign_deposit(truck, deposit, tiles), "Truck accepts an explicit friendly deposit assignment")
	SupplyLogistics.advance_all(2.9, roster, tiles, territory, economies)
	check.call(truck.supply_cargo == 0.0 and tiles[deposit]["supply_remaining"] == 1500.0, "Loading is physical and does not withdraw before three seconds")
	SupplyLogistics.advance_all(0.1, roster, tiles, territory, economies)
	check.call(truck.supply_cargo == 150.0 and tiles[deposit]["supply_remaining"] == 1350.0 and economy.credits == 0.0, "Completed loading atomically withdraws stock without minting credits")
	truck.advance(100.0, tiles)
	SupplyLogistics.advance_all(1.9, roster, tiles, territory, economies)
	check.call(truck.supply_cargo == 150.0 and economy.credits == 0.0, "Supply Center unload takes two seconds and retains cargo while pending")
	SupplyLogistics.advance_all(0.1, roster, tiles, territory, economies)
	check.call(truck.supply_cargo == 0.0 and economy.credits == 165.0 and economy.income_events.size() == 1, "All-road delivery pays cargo plus ten percent exactly once")
	SupplyLogistics.advance_all(0.5, roster, tiles, territory, economies)
	check.call(economy.credits == 165.0 and economy.income_events.size() == 1, "A completed unload cannot be paid twice")

	var first: UnitState = _truck(deposit)
	var second: UnitState = _truck(deposit)
	tiles[deposit]["supply_remaining"] = 200.0
	for candidate in [first, second]:
		candidate.assigned_deposit_id = tiles[deposit]["supply_id"]
		candidate.supply_task = "loading"
	var pair: Array[UnitState] = [first, second]
	SupplyLogistics.advance_all(3.0, pair, tiles, territory, economies)
	check.call(first.supply_cargo + second.supply_cargo == 200.0 and tiles[deposit]["supply_remaining"] == 0.0, "Simultaneous pickups cannot overdraw a finite deposit")
	check.call((first.supply_cargo == 150.0 and second.supply_cargo == 50.0), "Atomic pickup deterministically grants a final partial load")
	var empty_seeker: UnitState = _truck(deposit)
	SupplyLogistics.advance_all(0.1, [empty_seeker], tiles, territory, economies)
	check.call(empty_seeker.supply_task == "waiting_deposit" and empty_seeker.supply_cargo == 0.0, "A depleted deposit cannot create another load")

	tiles[deposit]["supply_remaining"] = 150.0
	var blocked: UnitState = _truck(deposit)
	blocked.assigned_deposit_id = tiles[deposit]["supply_id"]
	blocked.supply_task = "loading"
	territory.contested[deposit] = true
	SupplyLogistics.advance_all(3.0, [blocked], tiles, territory, economies)
	check.call(blocked.supply_cargo == 0.0 and blocked.supply_task == "waiting_deposit" and tiles[deposit]["supply_remaining"] == 150.0, "Contested deposits pause collection without losing stock")
	territory.contested.clear()
	var power_load: UnitState = _truck(center)
	power_load.supply_cargo = 80.0
	power_load.supply_task = "unloading"
	power_load.assigned_center = center
	power_load.delivery_route.assign([deposit, Vector2i(1, 0), center])
	economy.add_building(Vector2i(4, 0), "factory")
	SupplyLogistics.advance_all(2.0, [power_load], tiles, territory, economies)
	check.call(power_load.supply_cargo == 80.0 and power_load.supply_task == "waiting_center" and economy.credits == 165.0, "A brownout blocks unloading without losing cargo or issuing credits")
	economy.buildings.erase(Vector2i(4, 0))

	var alternate := Vector2i(3, 0)
	economy.add_building(alternate, "supply_center")
	var loaded: UnitState = _truck(center)
	loaded.supply_cargo = 100.0
	loaded.supply_task = "unloading"
	loaded.assigned_center = center
	loaded.delivery_route.assign([deposit, Vector2i(1, 0), center])
	territory.contested[center] = true
	SupplyLogistics.advance_all(0.5, [loaded], tiles, territory, economies)
	SupplyLogistics.advance_all(0.1, [loaded], tiles, territory, economies)
	check.call(loaded.supply_cargo == 100.0 and loaded.assigned_center == alternate and loaded.supply_task == "to_center", "Failed center preserves cargo and reroutes to an operational alternate")
	check.call(loaded.delivery_route == [deposit, Vector2i(1, 0), center, alternate], "Center rerouting preserves the full traveled delivery route as road-bonus evidence")
	loaded.health = 0.0
	check.call(loaded.supply_cargo == 100.0 and economy.credits == 165.0, "Destroying a loaded truck loses uncredited cargo with the unit")
