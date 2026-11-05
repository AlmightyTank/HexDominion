extends RefCounted


static func run(check: Callable) -> void:
	var fresh: MatchState = MatchState.new()
	check.call(fresh.difficulty == AIDifficulty.EASY and fresh.ai_countdown == 16.0, "New matches default to Easy with its full opening grace")
	check.call(fresh.set_difficulty(AIDifficulty.MEDIUM) and fresh.difficulty == AIDifficulty.MEDIUM and fresh.ai_countdown == 12.0, "Medium selection applies its opening grace")
	check.call(fresh.set_difficulty(AIDifficulty.HARD) and fresh.ai_countdown == 8.0, "Hard retains the original eight-second opening")
	check.call(not fresh.set_difficulty("nightmare") and fresh.difficulty == AIDifficulty.HARD, "Unknown difficulty cannot corrupt match state")
	for id in AIDifficulty.ORDER:
		check.call(AIDifficulty.is_valid(id), "Difficulty profile available: " + id)
	check.call(AIDifficulty.opening_delay(AIDifficulty.EASY) > AIDifficulty.opening_delay(AIDifficulty.MEDIUM) and AIDifficulty.opening_delay(AIDifficulty.MEDIUM) > AIDifficulty.opening_delay(AIDifficulty.HARD), "Opening grace decreases from Easy to Hard")
	check.call(AIDifficulty.think_interval(AIDifficulty.EASY) > AIDifficulty.think_interval(AIDifficulty.MEDIUM) and AIDifficulty.think_interval(AIDifficulty.MEDIUM) > AIDifficulty.think_interval(AIDifficulty.HARD), "Decision cadence increases from Easy to Hard")
	_test_opening_and_costs(check)
	_test_army_caps(check)
	_test_production(check)
	_test_defense(check)


static func _test_opening_and_costs(check: Callable) -> void:
	var tiles: Dictionary = {}
	for index in range(9):
		tiles[Vector2i(index, 0)] = {"is_land": true}
	var territory: TerritoryState = TerritoryState.new()
	territory.owners[Vector2i.ZERO] = 1
	territory.owners[Vector2i(7, 0)] = 2
	territory.owners[Vector2i(8, 0)] = 2
	var match_state: MatchState = MatchState.new()
	match_state.player_hq = Vector2i.ZERO
	match_state.rival_hq = Vector2i(8, 0)
	match_state.rival_economy.add_building(Vector2i(8, 0), "headquarters")
	match_state.rival_economy.add_building(Vector2i(7, 0), "barracks")
	var rival: UnitState = UnitState.new(Vector2i(8, 0))
	rival.faction = 2
	var roster: Array[UnitState] = [rival]
	match_state.advance_ai(15.9, tiles, territory, roster)
	check.call(rival.path.is_empty() and match_state.rival_economy.credits == 2000, "Easy waits through its longer opening without early spending")
	match_state.advance_ai(0.1, tiles, territory, roster)
	check.call(match_state.rival_economy.credits == 1950 and match_state.ai_countdown == 2.0, "Easy pays the normal rifle price and adopts its slower cadence")
	match_state.advance_ai(1.9, tiles, territory, roster)
	check.call(match_state.rival_economy.credits == 1950, "Easy does not make another decision before two seconds elapse")


static func _test_army_caps(check: Callable) -> void:
	for id in AIDifficulty.ORDER:
		var home: Vector2i = Vector2i.ZERO
		var barracks: Vector2i = Vector2i(1, 0)
		var tiles: Dictionary = {home: {"is_land": true}, barracks: {"is_land": true}}
		var territory: TerritoryState = TerritoryState.new()
		territory.owners[home] = 2
		territory.owners[barracks] = 2
		var economy: EconomyState = EconomyState.new(50)
		economy.faction = 2
		economy.add_building(home, "headquarters")
		economy.add_building(barracks, "barracks")
		var army: Array[UnitState] = []
		for index in range(int(AIDifficulty.profile(id)["army_limit"])):
			var unit: UnitState = UnitState.new(home)
			unit.faction = 2
			army.append(unit)
		RivalEconomyAI.plan(economy, tiles, territory, army, {}, home, Vector2i(-99999, -99999), id)
		check.call(economy.credits == 50 and economy.buildings[barracks]["queue"].is_empty(), "Army cap respected without spending: " + id)


static func _test_production(check: Callable) -> void:
	var tiles: Dictionary = {}
	var territory: TerritoryState = TerritoryState.new()
	for x in range(9):
		var hex: Vector2i = Vector2i(x, 0)
		tiles[hex] = {"is_land": true}
		territory.owners[hex] = 2
	var economy: EconomyState = EconomyState.new(10000)
	economy.faction = 2
	economy.add_building(Vector2i.ZERO, "headquarters")
	economy.add_building(Vector2i(1, 0), "factory")
	economy.add_building(Vector2i(2, 0), "power_plant")
	economy.add_building(Vector2i(3, 0), "airfield")
	var roster: Array[UnitState] = []
	for kind in ["rifle", "tank", "gunner", "rifle", "artillery"]:
		var unit: UnitState = UnitState.new(Vector2i.ZERO)
		unit.configure_kind(kind)
		unit.faction = 2
		roster.append(unit)
	check.call(not CombinedArmsAI.production(economy, tiles, territory, roster, {}, Vector2i.ZERO, Vector2i(8, 0), AIDifficulty.EASY), "Easy uses basic production rather than combined-arms purchases")
	check.call(not CombinedArmsAI.production(economy, tiles, territory, roster, {}, Vector2i.ZERO, Vector2i(8, 0), AIDifficulty.MEDIUM), "Medium does not purchase aircraft")
	check.call(CombinedArmsAI.production(economy, tiles, territory, roster, {}, Vector2i.ZERO, Vector2i(8, 0), AIDifficulty.HARD) and economy.buildings[Vector2i(3, 0)]["queue"] == ["helicopter"], "Hard keeps full combined-arms aircraft production")


static func _test_defense(check: Callable) -> void:
	for id in AIDifficulty.ORDER:
		var tiles: Dictionary = {}
		var territory: TerritoryState = TerritoryState.new()
		for q in range(-2, 3):
			for r in range(-2, 3):
				if absi(q + r) <= 2:
					var hex: Vector2i = Vector2i(q, r)
					tiles[hex] = {"is_land": true, "terrain": "plains"}
					territory.owners[hex] = 2
		var economy: EconomyState = EconomyState.new(1000)
		economy.faction = 2
		economy.add_building(Vector2i.ZERO, "headquarters")
		var army: Array[UnitState] = []
		for index in range(4):
			var unit: UnitState = UnitState.new(Vector2i.ZERO)
			unit.faction = 2
			army.append(unit)
		var reserved: Dictionary = {}
		for index in range(20):
			reserved = DefenseAI.plan(economy, tiles, territory, army, {}, Vector2i.ZERO, id)
		var bunkers: int = 0
		for building in economy.buildings.values():
			bunkers += int(building["kind"] == "bunker")
		var profile: Dictionary = AIDifficulty.profile(id)
		check.call(bunkers == int(profile["bunker_limit"]) and reserved.size() == int(profile["defender_limit"]), "Defense limits match profile: " + id)
