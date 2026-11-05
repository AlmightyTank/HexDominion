extends RefCounted


static func run(check: Callable) -> void:
	_test_placement(check)
	_test_capture(check)
	_test_income(check)
	_test_destruction_and_repair(check)
	_test_snapshot_resume(check)
	_test_ai_route(check)
	_test_art(check)


static func _test_placement(check: Callable) -> void:
	var tiles: Dictionary = {}
	for q in range(40):
		for r in range(20):
			tiles[Vector2i(q, r)] = {"is_land": true, "terrain": "plains"}
	var player_hq := Vector2i(1, 1)
	var rival_hq := Vector2i(38, 18)
	tiles[Vector2i(8, 8)]["terrain"] = "city"
	tiles[Vector2i(9, 8)]["terrain"] = "resource"
	tiles[Vector2i(10, 8)]["supply_id"] = "supply_test"
	tiles[Vector2i(11, 8)]["site_name"] = "Named site"
	var reserved: Dictionary = {Vector2i(12, 8): true}
	var first: Array[Vector2i] = OilDerrickNetwork.default_site_hexes(tiles, player_hq, rival_hq, reserved)
	var second: Array[Vector2i] = OilDerrickNetwork.default_site_hexes(tiles, player_hq, rival_hq, reserved)
	check.call(first.size() == OilDerrickNetwork.SITE_COUNT and first == second, "Oil placement creates exactly 20 deterministic sites")
	var legal: bool = true
	var stable_ids: Dictionary = {}
	var player_route: int = 1000000
	var rival_route: int = 1000000
	for hex in first:
		legal = legal and OilDerrickNetwork.valid_site_tile(tiles, hex) and not reserved.has(hex)
		stable_ids[OilDerrickNetwork.site_id(hex)] = true
		var from_player: Array[Vector2i] = HexPathfinding.find_path(tiles, player_hq, hex, "rifle")
		var from_rival: Array[Vector2i] = HexPathfinding.find_path(tiles, rival_hq, hex, "rifle")
		if not from_player.is_empty():
			player_route = mini(player_route, from_player.size() - 1)
		if not from_rival.is_empty():
			rival_route = mini(rival_route, from_rival.size() - 1)
	check.call(legal and stable_ids.size() == OilDerrickNetwork.SITE_COUNT, "Oil sites avoid cities, resources, supply deposits, named and reserved hexes and use stable IDs")
	check.call(player_route <= 9 and rival_route <= 9, "Both factions receive reachable early oil access within nine hexes")


static func _test_capture(check: Callable) -> void:
	var hex := Vector2i(3, 2)
	var oil := _single_site(hex)
	var territory := TerritoryState.new()
	var tank := UnitState.new(hex)
	tank.configure_kind("tank")
	oil.advance_capture(6.0, [tank], territory)
	check.call(oil.sites[hex]["owner"] == 0 and oil.sites[hex]["capture_elapsed"] == 0.0, "Vehicles can defend an oil site but cannot capture it")
	var infantry := UnitState.new(hex)
	oil.advance_capture(2.0, [infantry], territory)
	check.call(oil.sites[hex]["capture_faction"] == 1 and is_equal_approx(oil.sites[hex]["capture_elapsed"], 2.0), "Stationary infantry starts the independent five-second oil capture")
	var defender := UnitState.new(hex)
	defender.faction = 2
	defender.configure_kind("tank")
	oil.advance_capture(0.25, [infantry, defender], territory)
	check.call(oil.sites[hex]["contested"] and oil.sites[hex]["capture_faction"] == 0 and oil.sites[hex]["capture_elapsed"] == 0.0, "An opposing stationary ground force contests and resets oil capture")
	oil.advance_capture(5.0, [infantry], territory)
	check.call(oil.sites[hex]["owner"] == 1 and territory.owner_at(hex) == 1, "Infantry captures a neutral oil derrick atomically after five seconds")
	var rival := UnitState.new(hex)
	rival.faction = 2
	oil.advance_capture(5.0, [rival], territory)
	check.call(oil.sites[hex]["owner"] == 2 and territory.owner_at(hex) == 2, "Enemy infantry can recapture an owned oil derrick")


static func _test_income(check: Callable) -> void:
	var hex := Vector2i.ZERO
	var oil := _single_site(hex)
	var territory := TerritoryState.new()
	_claim(oil, territory, hex, 1)
	var economy := EconomyState.new(0.0)
	economy.faction = 1
	oil.advance_economy(0.4, territory, [economy])
	check.call(economy.credits == 0.0, "Oil income does not credit before the saved one-second boundary")
	oil.advance_economy(0.6, territory, [economy])
	check.call(is_equal_approx(economy.credits, 3.0) and economy.oil_derrick_count == 1, "One operational oil derrick credits exactly 3 CR per second through the economy account")
	check.call(economy.income_events.size() == 1 and economy.income_events[0]["source"] == EconomyState.SOURCE_OIL_DERRICK and economy.income_events[0]["road_bonus"] == 0.0, "Oil income is recorded as approved oil income with no road bonus")

	var bonus_tiles: Dictionary = {hex: {"is_land": true, "terrain": "plains", "continent": "Test"}}
	var bonus_territory := TerritoryState.new()
	bonus_territory.continents.configure(bonus_tiles, [hex], bonus_territory.owners)
	bonus_territory.set_owner(hex, 1)
	var bonus_oil := _single_site(hex)
	bonus_oil.sites[hex]["owner"] = 1
	var bonus_economy := EconomyState.new(0.0)
	bonus_economy.faction = 1
	bonus_oil.advance_economy(1.0, bonus_territory, [bonus_economy])
	check.call(is_equal_approx(bonus_economy.credits, 3.3) and is_equal_approx(bonus_economy.income_events[0]["continent_bonus"], 0.1), "Oil receives the additive continent bonus without receiving a road bonus")

	var offline := _single_site(hex)
	var offline_territory := TerritoryState.new()
	var offline_economy := EconomyState.new(0.0)
	offline_economy.faction = 1
	offline.advance_economy(1.0, offline_territory, [offline_economy])
	_claim(offline, offline_territory, hex, 1)
	offline.sites[hex]["contested"] = true
	offline.advance_economy(1.0, offline_territory, [offline_economy])
	offline.sites[hex]["contested"] = false
	offline.sites[hex]["health"] = 0.0
	offline.advance_economy(1.0, offline_territory, [offline_economy])
	check.call(offline_economy.credits == 0.0, "Neutral, contested and destroyed oil derricks pay zero income")


static func _test_destruction_and_repair(check: Callable) -> void:
	var hex := Vector2i(1, 1)
	var oil := _single_site(hex)
	var territory := TerritoryState.new()
	_claim(oil, territory, hex, 1)
	check.call(oil.damage(hex, OilDerrickNetwork.MAX_HEALTH) and oil.sites[hex]["owner"] == 1 and oil.sites[hex]["health"] == 0.0, "Oil destruction retains ownership")
	var economy := EconomyState.new(100.0)
	economy.faction = 1
	oil.advance_economy(1.0, territory, [economy])
	check.call(economy.credits == 100.0 and economy.oil_derrick_count == 0, "Destroyed oil remains offline and pays zero")
	check.call(oil.set_repair(hex, 1, territory, oil.sites[hex], true), "The controlling owner can order an oil derrick repair")
	oil.advance_economy(0.5, territory, [economy])
	check.call(is_equal_approx(oil.sites[hex]["health"], 10.0) and is_equal_approx(economy.credits, 90.0), "Oil repairs restore 20 HP per second at 1 CR per HP")
	oil.advance_economy(0.5, territory, [economy])
	check.call(is_equal_approx(economy.credits, 81.5) and oil.operational(hex, territory), "A restored oil derrick resumes income only after becoming operational")


static func _test_snapshot_resume(check: Callable) -> void:
	var hex := Vector2i(2, 0)
	var territory := TerritoryState.new()
	var original := _single_site(hex)
	_claim(original, territory, hex, 1)
	var before := EconomyState.new(0.0)
	before.faction = 1
	original.advance_economy(0.4, territory, [before])
	var restored := OilDerrickNetwork.new()
	restored.restore(original.snapshot())
	var after := EconomyState.new(0.0)
	after.faction = 1
	restored.advance_economy(0.6, territory, [after])
	check.call(is_equal_approx(after.credits, 3.0) and restored.payout_elapsed == 0.0 and restored.pending_income[1] == 0.0, "Restoring partial oil accrual credits the boundary once without duplicate income")


static func _test_ai_route(check: Callable) -> void:
	var tiles: Dictionary = {}
	for q in range(7):
		tiles[Vector2i(q, 0)] = {"is_land": true, "terrain": "plains"}
	var oil := _single_site(Vector2i(4, 0))
	var territory := TerritoryState.new()
	territory.set_owner(Vector2i(6, 0), 2)
	var rival := UnitState.new(Vector2i(6, 0))
	rival.faction = 2
	var match_state := MatchState.new()
	match_state.player_hq = Vector2i.ZERO
	match_state.rival_hq = Vector2i(6, 0)
	match_state.ai_countdown = 0.0
	match_state.advance_ai(0.1, tiles, territory, [rival], {}, oil)
	check.call(rival.path == [Vector2i(5, 0)] and oil.sites[Vector2i(4, 0)]["owner"] == 0, "AI physically routes infantry toward reachable oil without directly changing ownership")


static func _test_art(check: Callable) -> void:
	var loaded: bool = true
	for faction in [0, 1, 2]:
		for state in ["base", "damaged", "destroyed"]:
			var texture: Texture2D = UnitArt.oil_derrick_texture(faction, state)
			loaded = loaded and texture != null and texture.get_size() == Vector2(128, 128)
	for state in ["selected", "icon"]:
		var texture: Texture2D = UnitArt.oil_derrick_texture(0, state)
		loaded = loaded and texture != null and texture.get_size() == Vector2(128, 128)
	check.call(loaded, "Neutral, faction, damaged, destroyed, selected and strategic oil artwork loads at 128x128")


static func _single_site(hex: Vector2i) -> OilDerrickNetwork:
	var oil := OilDerrickNetwork.new()
	oil.sites[hex] = OilDerrickNetwork._new_site(hex)
	return oil


static func _claim(oil: OilDerrickNetwork, territory: TerritoryState, hex: Vector2i, faction: int) -> void:
	oil.sites[hex]["owner"] = faction
	territory.set_owner(hex, faction)
