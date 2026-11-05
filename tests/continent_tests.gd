extends RefCounted

static func run(check: Callable) -> void:
	var tiles: Dictionary = {}
	for x in range(4):
		tiles[Vector2i(x, 0)] = {"is_land": true, "terrain": "city" if x == 3 else "plains", "continent": "West" if x < 2 else "East"}
	tiles[Vector2i(20, 0)] = {"is_land": true, "continent": "East"}
	tiles[Vector2i(21, 0)] = {"is_land": true, "continent": "Antarctica"}
	tiles[Vector2i(2, 1)] = {"is_land": true, "continent": "East", "capturable": false}
	tiles[Vector2i(3, 1)] = {"is_land": false, "continent": "East"}
	var territory: TerritoryState = TerritoryState.new()
	territory.continents.configure(tiles, [Vector2i.ZERO], territory.owners)
	var manager: ContinentControl = territory.continents
	check.call(manager.regions["East"]["total"] == 2 and manager.regions["Antarctica"]["total"] == 0, "Continent eligibility excludes unreachable islands, Antarctica, ocean and explicit exclusions")
	territory.set_owner(Vector2i.ZERO, 1)
	check.call(manager.bonus(1) == 0 and manager.controller("West") == 0, "Partial ownership earns no bonus")
	territory.set_owner(Vector2i(1, 0), 1)
	check.call(is_equal_approx(manager.bonus(1), 0.1), "Exactly complete continent activates ten percent")
	territory.set_owner(Vector2i(1, 0), 2)
	check.call(manager.bonus(1) == 0, "Losing one eligible hex immediately removes bonus")
	territory.set_owner(Vector2i(1, 0), 1)
	for x in [2, 3]:
		territory.set_owner(Vector2i(x, 0), 1)
	check.call(is_equal_approx(manager.bonus(1), 0.2), "Recapture and two continents stack additively")
	var revision: int = manager.revision
	for index in range(20):
		territory.set_owner(Vector2i.ZERO, 1)
		manager.bonus(1)
	check.call(manager.revision == revision, "Repeated capture and income queries do not recount or duplicate rewards")
	var economy: EconomyState = EconomyState.new()
	economy.faction = 1
	economy.add_building(Vector2i.ZERO, "headquarters")
	for x in range(4):
		tiles[Vector2i(x, 0)]["road"] = true
	check.call(economy.income_rate(tiles, territory) == 0 and economy.credits == CreditsAccount.DEFAULT_STARTING_FUNDS, "Continent control, roads, HQ and city mint no passive income")
	var delivery: float = economy.credit_approved_income(100.0, EconomyState.SOURCE_DELIVERY, territory, true)
	check.call(is_equal_approx(delivery, 130.0), "Delivery payout adds one road bonus and two continent bonuses against base")
	tiles[Vector2i(1, 0)].erase("road")
	var oil: float = economy.credit_approved_income(100.0, EconomyState.SOURCE_OIL_DERRICK, territory, true)
	check.call(is_equal_approx(oil, 120.0) and is_equal_approx(manager.bonus(1), 0.2), "Oil income receives continent bonuses but never a road bonus")
	territory.contested[Vector2i(1, 0)] = true
	check.call(economy.income_rate(tiles, territory) == 0 and is_equal_approx(economy.income_last_seconds(), 250.0), "Connectivity changes do not mint or duplicate approved payouts")
	territory.contested.clear()
	var saved: Dictionary = territory.owners.duplicate(true)
	for x in range(4):
		territory.set_owner(Vector2i(x, 0), 2)
	check.call(manager.bonus(1) == 0 and is_equal_approx(manager.bonus(2), 0.2), "Multiple factions have independent control counts")
	territory.owners = saved
	check.call(is_equal_approx(manager.bonus(1), 0.2) and manager.bonus(2) == 0, "Save ownership replacement reconstructs derived bonuses without duplication")
