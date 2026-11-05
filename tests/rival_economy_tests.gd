extends RefCounted

static func run(check: Callable) -> void:
	var tiles: Dictionary = {}
	for q in range(12):
		for r in range(6):
			tiles[Vector2i(q, r)] = {"is_land": true, "terrain": "plains"}
	var home: Vector2i = Vector2i.ZERO
	var deposit: Vector2i = Vector2i(4, 1)
	tiles[home]["terrain"] = "city"
	tiles[deposit]["terrain"] = "resource"
	var territory: TerritoryState = TerritoryState.new()
	var match_state: MatchState = MatchState.new()
	match_state.rival_hq = home
	match_state.player_hq = Vector2i(11, 0)
	match_state.ai_countdown = 0
	territory.owners[home] = 2
	territory.owners[Vector2i(1, 0)] = 2
	territory.owners[Vector2i(0, 1)] = 2
	territory.owners[match_state.player_hq] = 1
	var economy: EconomyState = match_state.rival_economy
	economy.add_building(home, "headquarters")
	economy.add_building(Vector2i(1, 0), "barracks")
	var units: Array[UnitState] = []
	for index in range(3):
		var unit: UnitState = UnitState.new(home)
		unit.faction = 2
		units.append(unit)
	var saw_factory: bool = false
	var saw_extractor: bool = false
	var saw_tank: bool = false
	for tick in range(1200):
		_step(match_state, tiles, territory, units)
		for site in economy.buildings.values():
			saw_factory = saw_factory or site["kind"] == "factory" and EconomyState.is_complete(site)
			saw_extractor = saw_extractor or site["kind"] == "extractor" and EconomyState.is_complete(site)
		for unit in units:
			saw_tank = saw_tank or unit.kind == "tank"
	check.call(saw_factory and saw_tank and not saw_extractor, "AI spends its finite starting funds on production and armor, not passive extractors")
	check.call(economy.income_rate(tiles, territory) == 0 and economy.income_last_seconds() == 0, "AI receives no free HQ, city or resource income")
	check.call(CreditsAccount.valid_snapshot(economy.account.snapshot()) and economy.credits >= 0 and units.size() <= RivalEconomyAI.ARMY_LIMIT, "Long-running AI keeps a valid ledger, no overdraft and bounded army")
	economy.damage_building(home, 80)
	economy.credits = 500
	match_state.ai_countdown = 0
	_step(match_state, tiles, territory, units)
	check.call(economy.buildings[home].get("repairing", false), "AI starts affordable damaged infrastructure repairs")
	for tick in range(100):
		_step(match_state, tiles, territory, units)
	check.call(economy.buildings[home]["health"] == EconomyState.BUILD_HEALTH["headquarters"] and not economy.buildings[home].get("repairing", false), "AI repairs finish without exceeding maximum health")
	# Territory alone cannot fund recovery when the last HQ has been destroyed.
	economy.buildings.clear()
	economy.credits = 0
	units.clear()
	for tick in range(2300):
		_step(match_state, tiles, territory, units)
	var recovered_hq: bool = false
	var recovered_barracks: bool = false
	for building in economy.buildings.values():
		recovered_hq = recovered_hq or building["kind"] == "headquarters" and EconomyState.is_complete(building)
		recovered_barracks = recovered_barracks or building["kind"] == "barracks" and EconomyState.is_complete(building)
	check.call(not recovered_barracks and units.is_empty() and economy.credits == 0, "Zero-cash HQ-less AI cannot bypass supply rules or receive a bailout")
	economy.credits = 500 # Scenario funds sufficient to rebuild command and production.
	for tick in range(3000):
		_step(match_state, tiles, territory, units)
	for building in economy.buildings.values():
		recovered_hq = recovered_hq or building["kind"] == "headquarters" and EconomyState.is_complete(building)
	check.call(recovered_hq and not units.is_empty() and CreditsAccount.valid_snapshot(economy.account.snapshot()), "Funded AI restores HQ supply before recruitment with a valid ledger")
	_test_exploits(check, tiles)
	_test_military(check, tiles)
	_test_salvage_and_reachability(check, tiles)

static func _step(match_state: MatchState, tiles: Dictionary, territory: TerritoryState, units: Array[UnitState]) -> void:
	match_state.advance_ai(0.1, tiles, territory, units)
	territory.advance(0.1, tiles, units)
	for unit in units:
		unit.advance(0.1, tiles)
	units.append_array(match_state.rival_economy.advance(0.1, tiles, territory))

static func _test_exploits(check: Callable, tiles: Dictionary) -> void:
	var hex: Vector2i = Vector2i(2, 2)
	for faction in [1, 2]:
		var territory: TerritoryState = TerritoryState.new()
		territory.owners[hex] = faction
		var economy: EconomyState = EconomyState.new(1000)
		economy.faction = faction
		var starting: float = economy.credits
		var valid: bool = true
		for index in range(10):
			valid = economy.build(hex, "barracks", tiles, territory) and valid
			var stale: Dictionary = economy.buildings[hex]
			valid = economy.cancel_construction(hex, territory, stale) and valid
			valid = not economy.cancel_construction(hex, territory, stale) and valid
			valid = not economy.sell_building(hex, territory, stale) and valid
		check.call(valid and economy.credits == starting - 500, "Repeated build/cancel/replayed stale sale never profits for faction %d" % faction)
		economy.build(hex, "barracks", tiles, territory)
		economy.advance(6, tiles, territory)
		var site: Dictionary = economy.buildings[hex]
		economy.train(hex, "rifle", territory)
		var before_sale: float = economy.credits
		check.call(economy.sell_building(hex, territory, site) and economy.credits == before_sale + 50 and economy.advance(100, tiles, territory).is_empty(), "Selling queued production grants only structure salvage and no orphan recruit for faction %d" % faction)
		check.call(not economy.sell_building(hex, territory, site) and CreditsAccount.valid_snapshot(economy.account.snapshot()), "Replayed sale preserves ledger for faction %d" % faction)
	# Both sides share placement occupancy, including a captured foreign structure.
	var territory: TerritoryState = TerritoryState.new()
	territory.owners[hex] = 2
	var opponent: EconomyState = EconomyState.new()
	opponent.add_building(hex, "factory")
	var rival: EconomyState = EconomyState.new()
	rival.faction = 2
	check.call(not rival.build(hex, "barracks", tiles, territory, 0, opponent.buildings) and rival.credits == 2000, "AI cannot overlap player infrastructure or debit on rejected placement")

static func _test_military(check: Callable, tiles: Dictionary) -> void:
	var match_state: MatchState = MatchState.new()
	match_state.rival_hq = Vector2i.ZERO
	match_state.player_hq = Vector2i(11, 0)
	match_state.ai_countdown = 0
	var territory: TerritoryState = TerritoryState.new()
	territory.owners[Vector2i(4, 1)] = 2
	var unit: UnitState = UnitState.new(Vector2i(4, 1))
	unit.faction = 2
	var units: Array[UnitState] = [unit]
	var player: EconomyState = EconomyState.new()
	player.add_building(Vector2i(4, 1), "extractor")
	match_state.advance_ai(1, tiles, territory, units, player.buildings)
	check.call(unit.path.is_empty(), "AI holds position to destroy hostile infrastructure on captured resource")
	var economies: Array[EconomyState] = [player, match_state.rival_economy]
	CombatState.attack_extractors(10, units, economies, {})
	check.call(player.buildings.is_empty(), "Infrastructure attack clears captured deposit for a replacement extractor")

static func _test_salvage_and_reachability(check: Callable, tiles: Dictionary) -> void:
	var territory: TerritoryState = TerritoryState.new()
	var economy: EconomyState = EconomyState.new(0)
	economy.faction = 2
	var home: Vector2i = Vector2i(2, 2)
	var factory: Vector2i = Vector2i(3, 2)
	territory.owners[home] = 2
	territory.owners[factory] = 2
	economy.add_building(home, "barracks")
	economy.add_building(factory, "factory")
	var units: Array[UnitState] = []
	RivalEconomyAI.plan(economy, tiles, territory, units, {}, home)
	check.call(not economy.buildings.has(factory) and economy.credits == 100, "Cash-starved AI liquidates optional infrastructure using the exact player salvage refund")
	RivalEconomyAI.plan(economy, tiles, territory, units, {}, home)
	check.call(economy.buildings[home]["queue"] == ["rifle"] and economy.credits == 50, "Salvage recovery buys a scout at the normal price without duplicate refunds")
	var land: Dictionary = tiles.duplicate(true)
	# A tempting isolated deposit must not prevent choosing a reachable objective.
	land[Vector2i(4, 1)]["terrain"] = "plains"
	land[Vector2i(4, 2)]["terrain"] = "resource"
	for neighbor in HexMath.neighbors(Vector2i(4, 2)):
		land[neighbor]["is_land"] = false
	land[Vector2i(0, 5)]["terrain"] = "city"
	for hex in land:
		if HexPathfinding.is_walkable(land, hex) and HexMath.distance(hex, home) <= 1:
			territory.owners[hex] = 2
	var goal: Vector2i = RivalEconomyAI.expansion_goal(home, home, land, territory, economy)
	check.call(goal == Vector2i(0, 5) and not HexPathfinding.find_path(land, home, goal).is_empty(), "AI ignores unreachable valuable territory rather than repeatedly ordering an impossible route")
	var credits: float = economy.credits
	var match_state: MatchState = MatchState.new()
	match_state.rival_economy = economy
	match_state.advance_ai(NAN, tiles, territory, units)
	match_state.advance_ai(INF, tiles, territory, units)
	check.call(economy.credits == credits and is_finite(match_state.ai_countdown), "Invalid AI deltas cannot corrupt timer or trigger spending")
	economy.add_building(Vector2i(1, 1), "headquarters")
	territory.owners[Vector2i(1, 1)] = 1
	check.call(RivalEconomyAI.expansion_goal(home, home, tiles, territory, economy) == Vector2i(1, 1), "AI prioritizes recapturing inactive core infrastructure over optional economic expansion")
