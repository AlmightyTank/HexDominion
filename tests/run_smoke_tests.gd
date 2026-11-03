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


func _test_supply_ui_and_save() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.units.set_physics_process(false)
	var tiles: Dictionary = game.world_map.map_data["tiles"]
	var home: Vector2i = game.units.match_state.player_hq
	game.world_map.inspect_at_world(game.world_map.hex_to_world(home))
	game._process(0)
	_check(game.hud.supply_info.visible and "SUPPLIED" in game.hud.supply_info.text and "6.00" in game.hud.supply_info.text, "Selected HQ city displays live supplied income")
	var snapshot: Dictionary = MatchSave.capture(game.units, game.camera.position, game.camera.zoom, home)
	game.units.economy.damage_building(home, 10000)
	game._process(0)
	_check("ISOLATED" in game.hud.supply_info.text and "0.00" in game.hud.supply_info.text and game.units.economy.income_rate(tiles, game.units.territory) == 0, "HQ destruction updates inspected city and faction income immediately")
	_check(MatchSave.restore(game.units, snapshot), "Supply state snapshot restores without serializing a graph")
	game._process(0)
	_check("SUPPLIED" in game.hud.supply_info.text and game.units.economy.income_status(home, tiles, game.units.territory)["income"] == 6, "Load rebuilds supply without stale isolation")
	_check(snapshot == MatchSave.capture(game.units, game.camera.position, game.camera.zoom, home), "Derived supply caches do not alter saved authoritative state")
	game.free()


func _test_economy_interface() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.units.set_physics_process(false)
	var tiles: Dictionary = game.world_map.map_data["tiles"]
	var route: Array[Vector2i] = HexPathfinding.find_path(tiles, game.units.match_state.player_hq, game.units.match_state.rival_hq)
	var first: Vector2i = route[2]
	var second: Vector2i = route[3]
	var site: Vector2i = route[4]
	for hex in [first, second, site]:
		game.units.territory.owners[hex] = 1
	game.units.economy.credits = 2000
	var road_hex: Vector2i = game.units.match_state.player_hq
	game._begin_build("road")
	game._place_build(game.world_map.hex_to_world(road_hex))
	_check(tiles[road_hex].get("road", false) and game.units.build_kind == "road" and game.units.economy.credits == 1900, "Road tool builds under HQ and remains active for highway")
	var road_save: Dictionary = MatchSave.capture(game.units, game.camera.position, game.camera.zoom, road_hex)
	_check(MatchSave.validate(road_save, tiles), "Road snapshot validates")
	tiles[road_hex].erase("road")
	_check(MatchSave.restore(game.units, road_save) and tiles[road_hex].get("road", false), "Road snapshot restores roads")
	var bad_road: Dictionary = road_save.duplicate(true)
	bad_road["roads"][Vector2i(-999, -999)] = true
	_check(not MatchSave.restore(game.units, bad_road) and tiles[road_hex].get("road", false), "Invalid road load leaves live roads unchanged")
	var legacy: Dictionary = road_save.duplicate(true)
	legacy.erase("roads")
	_check(MatchSave.restore(game.units, legacy) and not tiles[road_hex].get("road", false), "Legacy snapshot clears newer roads")
	game.units.economy.credits = 2000
	game.units.economy.add_building(first, "factory")
	game.units.economy.add_building(second, "factory")
	game._process(0)
	_check(game.hud.facility_buttons.has(first) and game.hud.facility_buttons.has(second), "Sidebar lists multiple factories separately without map hunting")
	game.hud.facility_buttons[first].pressed.emit()
	_check(game._economy_hex() == first and game.hud.facility_buttons[first].button_pressed, "Roster selection pins exact factory")
	game._inspect_world_at(game.world_map.hex_to_world(site))
	game._process(0)
	_check(game._economy_hex() == first and game.units.managed_hex == first, "Terrain inspection preserves pinned factory and world highlight")
	game.hud.train_buttons["tank"].pressed.emit()
	_check(game.units.economy.buildings[first]["queue"] == ["tank"] and game.units.economy.buildings[second]["queue"].is_empty(), "Training controls enqueue only in pinned factory")
	game.hud.rally_button.pressed.emit()
	game._select_at(game.world_map.hex_to_world(site))
	_check(game._economy_hex() == first and game.units.economy.buildings[first]["rally"] == site and game.units.economy.buildings[second]["rally"] == second, "Explicit rally destination preserves selection and other factory rally")
	game._begin_rally()
	game._set_facility_rally(game.world_map.hex_to_world(Vector2i(-9999, -9999)))
	_check(game._rally_mode and game._economy_hex() == first and game.units.economy.buildings[first]["rally"] == site, "Invalid rally retains pinned factory and previous destination")
	var escape: InputEventKey = InputEventKey.new()
	escape.pressed = true
	escape.keycode = KEY_ESCAPE
	game._input(escape)
	_check(not game._rally_mode and not game.hud.pause_overlay.visible and game._economy_hex() == first, "Escape cancels rally picking without deselecting facility or opening pause")
	game.hud.facility_buttons[second].pressed.emit()
	game.hud.rally_button.pressed.emit()
	game._select_at(game.world_map.hex_to_world(first))
	game._train_selected("tank")
	_check(game.units.economy.buildings[second]["rally"] == first and game.units.economy.buildings[first]["rally"] == site, "Second factory retains its own independent rally")
	game._begin_build("barracks")
	game._place_build(game.world_map.hex_to_world(site))
	game._process(0)
	_check(game._economy_hex() == second and game.hud.train_buttons["tank"].visible, "Placing construction does not steal selected factory controls")
	_check(game.hud.facility_buttons[site].text.contains("Construction 0%") and game.hud.facility_buttons[first].text.contains("tank"), "Roster exposes construction and production jobs simultaneously")
	_check(game.hud.build_buttons["extractor"].tooltip_text.contains("resource deposit") and game.hud.build_buttons["factory"].tooltip_text.contains("20 power") and game.hud.build_buttons["factory"].text.contains("200 CR"), "Construction tiles expose costs and tooltips expose power and terrain requirements")
	_check(game.hud.economy_summary.text.contains("LOW") and game.hud.facility_buttons[second].text.contains("50% speed"), "Grid deficit and reduced production speed are visible")
	game.units.economy.buildings[first]["elapsed"] = 2.0
	game.hud.facility_buttons[first].pressed.emit()
	_check(is_equal_approx(game.hud.training_progress.value, 25.0) and game.hud.build_status.text.contains("Rally:"), "Selected facility shows precise production progress and own rally coordinates")
	game.units.economy.damage_building(first, 50)
	game._process(0)
	game.hud.repair_button.pressed.emit()
	game._process(0)
	_check(game.hud.facility_buttons[first].text.contains("Repair") and game.hud.repair_button.text == "Stop repairs", "Roster and pinned controls expose active repair jobs")
	var old: Dictionary = game.units.economy.buildings[first]
	game.units.economy.damage_building(first, 10000)
	game.units.economy.add_building(first, "factory")
	game._process(0)
	_check(game._economy_hex() == game.NO_FACILITY and not game.hud.sell_button.visible and not is_same(old, game.units.economy.buildings[first]), "Destroyed and replaced facility cannot inherit stale selection or actions")
	game.hud.facility_buttons[second].pressed.emit()
	game.units.territory.owners[second] = 2
	game._process(0)
	_check(game._economy_hex() == game.NO_FACILITY and not game.hud.facility_buttons.has(second), "Ownership loss clears pinned selection and removes uncontrolled roster entry")
	game.hud.show_tile_actions(Vector2i.ZERO, EconomyState.new(), TerritoryState.new(), tiles)
	_check(game.hud.economy_summary.text.contains("No controlled structures"), "Empty economy has explicit roster empty state")
	root.remove_child(game)
	game.free()


func _test_building_placement() -> void:
	var site: Vector2i = Vector2i.ZERO
	var tiles: Dictionary = {site: {"is_land": true, "terrain": "plains"}}
	var territory: TerritoryState = TerritoryState.new()
	var economy: EconomyState = EconomyState.new(1000)
	_check(not economy.build(site, "barracks", tiles, territory), "Neutral hex rejects construction")
	territory.owners[site] = 2
	_check(not economy.build(site, "barracks", tiles, territory), "Enemy hex rejects construction")
	territory.owners[site] = 1
	territory.contested[site] = true
	_check(not economy.build(site, "barracks", tiles, territory), "Contested controlled hex rejects construction")
	territory.contested.clear()
	_check(not economy.build(site, "barracks", tiles, territory, 0, {site: {"kind": "factory"}}), "Captured rival structure blocks overlap")
	_check(not economy.build(site, "barracks", tiles, territory, 6), "Invalid rotation rejects construction")
	_check(not economy.build(site, "extractor", tiles, territory), "Extractor ghost must match deposit terrain")
	_check(not economy.build(Vector2i(99, 99), "barracks", tiles, territory), "Off-map construction rejected")
	tiles[site]["is_land"] = false
	_check(not economy.build(site, "barracks", tiles, territory), "Owned water rejects construction")
	tiles[site]["is_land"] = true
	_check(economy.credits == 1000 and economy.buildings.is_empty(), "Invalid placements preserve money and structures")
	_check(economy.build(site, "barracks", tiles, territory, 4), "Valid controlled empty hex accepts construction")
	_check(economy.buildings[site]["rotation"] == 4 and economy.credits == 900, "Construction records rotation and debits exactly once")
	_check(not economy.build(site, "factory", tiles, territory) and economy.credits == 900, "Repeated placement cannot overlap or charge")
	economy.buildings.clear()
	economy.credits = 0
	_check(not economy.build(site, "barracks", tiles, territory), "Funds rechecked at placement confirmation")


func _test_construction() -> void:
	var site: Vector2i = Vector2i.ZERO
	var tiles: Dictionary = {site: {"is_land": true, "terrain": "resource"}}
	for kind in EconomyState.BUILD_SECONDS:
		var economy: EconomyState = EconomyState.new(1000)
		var territory: TerritoryState = TerritoryState.new()
		territory.owners[site] = 1
		_check(economy.build(site, kind, tiles, territory), "%s foundation placed" % kind)
		var building: Dictionary = economy.buildings[site]
		_check(building["construction"] == 0 and not EconomyState.is_complete(building), "%s starts unfinished" % kind)
		_check(economy.income_rate(tiles, territory) == 0 and not economy.train(site, "rifle", territory) and not economy.train(site, "tank", territory), "%s cannot operate during construction" % kind)
		economy.advance(1, tiles, territory)
		_check(building["construction"] == 1, "%s timer advances" % kind)
		territory.contested[site] = true
		economy.advance(2, tiles, territory)
		_check(building["construction"] == 1, "%s contested construction pauses" % kind)
		territory.contested.clear()
		territory.owners[site] = 2
		economy.advance(2, tiles, territory)
		_check(building["construction"] == 1, "%s lost construction pauses" % kind)
		territory.owners[site] = 1
		var enemy: UnitState = UnitState.new(Vector2i(1, 0))
		enemy.faction = 2
		CombatState.attack_extractors(1, [enemy], [economy], {})
		_check(building["health"] == EconomyState.BUILD_HEALTH[kind] - 20, "%s foundation vulnerable to enemy fire" % kind)
		economy.advance(EconomyState.BUILD_SECONDS[kind] - 1, tiles, territory)
		_check(EconomyState.is_complete(building) and building["health"] == EconomyState.BUILD_HEALTH[kind] - 20, "%s completes without healing damage" % kind)
		economy.buildings.clear()
		economy.build(site, kind, tiles, territory)
		var paid: float = economy.credits
		CombatState.attack_extractors(100, [enemy], [economy], {})
		_check(economy.buildings.is_empty() and economy.credits == paid, "%s foundation destroyed without refund" % kind)


func _test_construction_cancellation() -> void:
	var hex: Vector2i = Vector2i.ZERO
	var tiles: Dictionary = {hex: {"is_land": true, "terrain": "resource"}}
	for faction in [1, 2]:
		for kind in EconomyState.BUILD_COSTS:
			var economy: EconomyState = EconomyState.new(1000)
			economy.faction = faction
			var territory: TerritoryState = TerritoryState.new()
			territory.owners[hex] = faction
			economy.build(hex, kind, tiles, territory)
			var site: Dictionary = economy.buildings[hex]
			economy.advance(1, tiles, territory)
			economy.damage_building(hex, 20)
			var before: float = economy.credits
			_check(economy.cancel_construction(hex, territory, site), "%s faction %d can cancel damaged partial construction" % [kind, faction])
			_check(economy.credits == before + EconomyState.BUILD_COSTS[kind] * 0.5 and not economy.buildings.has(hex), "Cancellation refunds exactly half and removes site")
			var refunded: Dictionary = economy.account.snapshot()
			_check(not economy.cancel_construction(hex, territory, site) and economy.account.snapshot() == refunded, "Repeated cancellation cannot refund or log twice")
			_check(economy.build(hex, kind, tiles, territory), "Cancellation releases occupancy and HQ reservation")
			_check(not economy.cancel_construction(hex, territory, site) and economy.buildings.has(hex), "Stale request cannot cancel replacement site")
			site = economy.buildings[hex]
			territory.owners[hex] = 3 - faction
			_check(not economy.cancel_construction(hex, territory, site), "Cannot refund construction on lost land")
			territory.owners[hex] = faction
			economy.advance(EconomyState.BUILD_SECONDS[kind], tiles, territory)
			_check(not economy.cancel_construction(hex, territory, site), "Completed building cannot use construction refund")
	var economy: EconomyState = EconomyState.new(1000)
	var territory: TerritoryState = TerritoryState.new()
	territory.owners[hex] = 1
	economy.build(hex, "barracks", tiles, territory)
	var site: Dictionary = economy.buildings[hex]
	economy.damage_building(hex, 1000)
	_check(not economy.cancel_construction(hex, territory, site) and economy.credits == 900, "Destroyed site cannot refund")
	economy.build(hex, "barracks", tiles, territory)
	site = economy.buildings[hex]
	economy.credits = CreditsAccount.MAX_CREDITS
	_check(not economy.cancel_construction(hex, territory, site) and economy.buildings.has(hex), "Rejected overflowing refund does not remove site")


func _test_power() -> void:
	var plant: Vector2i = Vector2i.ZERO
	var factory: Vector2i = Vector2i(5, 0)
	var deposit: Vector2i = Vector2i(6, 0)
	var tiles: Dictionary = {plant: {"is_land": true}, factory: {"is_land": true}, deposit: {"is_land": true, "terrain": "resource"}}
	for faction in [1, 2]:
		var economy: EconomyState = EconomyState.new(1000)
		economy.faction = faction
		var territory: TerritoryState = TerritoryState.new()
		for hex in tiles:
			territory.owners[hex] = faction
		economy.add_building(plant, "power_plant")
		economy.add_building(factory, "factory")
		economy.add_building(deposit, "extractor")
		_check(economy.power_balance(territory) == {"supply": 40, "demand": 30} and not economy.low_power(territory), "Faction %d power supply and demand derived from operational structures" % faction)
		economy.train(factory, "tank", territory)
		economy.advance(2, tiles, territory)
		_check(economy.buildings[factory]["elapsed"] == 2 and economy.income_rate(tiles, territory) == 0, "Powered factory operates; extractor still needs HQ supply")
		var enemy: UnitState = UnitState.new(Vector2i(1, 0))
		enemy.faction = 3 - faction
		CombatState.attack_extractors(20, [enemy], [economy], {})
		_check(not economy.buildings.has(plant) and economy.low_power(territory) and economy.income_rate(tiles, territory) == 0, "Enemy destruction of completed plant immediately disables dependent extraction")
		var balance: float = economy.credits
		economy.advance(2, tiles, territory)
		_check(economy.buildings[factory]["elapsed"] == 3 and economy.credits == balance, "Low power halves factory progress without extracting income")
		_check(economy.build(plant, "power_plant", tiles, territory), "Power plant can be rebuilt during outage")
		_check(economy.low_power(territory), "Unfinished plant supplies no power")
		economy.advance(8, tiles, territory)
		_check(not economy.low_power(territory) and economy.buildings[factory]["elapsed"] == 7 and economy.income_rate(tiles, territory) == 0, "Completion restores power while preserving queued progress; no HQ supply")
		_check(economy.advance(1, tiles, territory).size() == 1, "Factory resumes full speed after power restoration")
		territory.contested[plant] = true
		_check(economy.low_power(territory), "Contested plant loses supply immediately")
		territory.contested.clear()
		territory.owners[plant] = 3 - faction
		_check(economy.low_power(territory), "Lost plant no longer supplies original faction")
		territory.owners[plant] = faction
		_check(not economy.low_power(territory), "Recaptured plant restores supply immediately")
		var isolated: EconomyState = EconomyState.new()
		isolated.faction = 3 - faction
		_check(isolated.power_balance(territory) == {"supply": 0, "demand": 0}, "Factions never share power")
		# Crossing plant completion in one tick must match separate pre/post-completion ticks.
		economy.buildings[plant]["construction"] = 7.0
		economy.train(factory, "tank", territory)
		balance = economy.credits
		economy.advance(3, tiles, territory)
		_check(economy.buildings[factory]["elapsed"] == 2.5 and economy.credits == balance, "Power recovery mid-tick restores factory speed without bypassing HQ supply")


func _test_repairs_and_sales() -> void:
	var hex: Vector2i = Vector2i.ZERO
	var tiles: Dictionary = {hex: {"is_land": true, "terrain": "resource"}}
	for faction in [1, 2]:
		for kind in EconomyState.BUILD_COSTS:
			var territory: TerritoryState = TerritoryState.new()
			territory.owners[hex] = faction
			var economy: EconomyState = EconomyState.new(1000)
			economy.faction = faction
			economy.add_building(hex, kind)
			var site: Dictionary = economy.buildings[hex]
			_check(not economy.set_repair(hex, territory, site, true), "Full-health %s cannot start paid repairs" % kind)
			economy.damage_building(hex, 50)
			_check(economy.set_repair(hex, territory, site, true), "Damaged %s faction %d starts repair" % [kind, faction])
			var income: float = economy.income_rate(tiles, territory)
			economy.advance(0.5, tiles, territory)
			_check(site["health"] == EconomyState.BUILD_HEALTH[kind] - 40 and economy.credits == 990 + income * 0.5, "Repair charges only health restored over time")
			_check(economy.set_repair(hex, territory, site, false), "Repair cancellation accepted")
			economy.advance(1, tiles, territory)
			_check(site["health"] == EconomyState.BUILD_HEALTH[kind] - 40, "Cancelled repair no longer heals")
			economy.set_repair(hex, territory, site, true)
			territory.contested[hex] = true
			var balance: float = economy.credits
			economy.advance(1, tiles, territory)
			_check(site["health"] == EconomyState.BUILD_HEALTH[kind] - 40 and economy.credits == balance, "Contested repair pauses without charging")
			territory.contested.clear()
			economy.advance(10, tiles, territory)
			_check(site["health"] == EconomyState.BUILD_HEALTH[kind] and not site["repairing"], "Repair clamps to max health and stops automatically")
			balance = economy.credits
			_check(economy.sell_building(hex, territory, site) and economy.credits == balance + EconomyState.BUILD_COSTS[kind] * 0.5 and not economy.buildings.has(hex), "Sale refunds exact salvage and removes completed building")
			balance = economy.credits
			_check(not economy.sell_building(hex, territory, site) and economy.credits == balance, "Repeated sale cannot duplicate money")
			economy.add_building(hex, kind)
			_check(not economy.sell_building(hex, territory, site) and not economy.set_repair(hex, territory, site, true), "Stale sale and repair requests reject replacement building")
			site = economy.buildings[hex]
			economy.damage_building(hex, 1)
			economy.set_repair(hex, territory, site, true)
			economy.damage_building(hex, 10000)
			economy.advance(1, tiles, territory)
			_check(economy.buildings.is_empty() and not economy.sell_building(hex, territory, site), "Destruction removes repair job and cannot issue salvage")
	var economy: EconomyState = EconomyState.new(7)
	var territory: TerritoryState = TerritoryState.new()
	territory.owners[hex] = 1
	economy.add_building(hex, "barracks")
	var site: Dictionary = economy.buildings[hex]
	economy.damage_building(hex, 50)
	economy.set_repair(hex, territory, site, true)
	economy.advance(1, tiles, territory)
	_check(site["health"] == 257 and economy.credits == 0, "Repair spends only available funds, never overdrafts")
	economy.advance(1, tiles, territory)
	_check(site["health"] == 257, "Unfunded repairs pause")
	economy.credits = 100
	economy.advance(10, tiles, territory)
	_check(site["health"] == 300 and economy.credits == 57, "Funded repair resumes and charges only missing health")
	economy.train(hex, "rifle", territory)
	_check(economy.sell_building(hex, territory, site) and economy.advance(100, tiles, territory).is_empty(), "Sale removes paid training queue without ghost recruits")
	economy.credits = 200
	economy.build(hex, "barracks", tiles, territory)
	site = economy.buildings[hex]
	_check(not economy.sell_building(hex, territory, site) and not economy.set_repair(hex, territory, site, true), "Unfinished sites cannot use selling or repairs")


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
	_test_economy()
	_test_city_income()
	_test_extractors()
	_test_credits_accounts()
	_test_match_ai()
	var game: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	_check(not game.hud.pause_overlay.visible, "Escape menu starts hidden")
	var escape: InputEventKey = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	game._input(escape)
	_check(game.hud.pause_overlay.visible and not game.units.is_physics_processing() and not game.camera.is_processing(), "Escape opens modal and pauses simulation and camera")
	var paused_credits: float = game.units.economy.credits
	game._begin_build("barracks")
	_check(game.units.economy.credits == paused_credits, "Pause menu blocks gameplay commands")
	game._input(escape)
	_check(not game.hud.pause_overlay.visible and game.units.is_physics_processing() and game.camera.is_processing(), "Escape closes modal and resumes match")
	game._set_menu_open(true)
	game._match_action("resume")
	_check(not game.hud.pause_overlay.visible, "Resume action closes menu")
	_check(game.units.units.size() == 4, "Three starter squads and a mobile AI rival on the live map")
	_check(HexPathfinding.find_path(tiles, game.units.match_state.player_hq, game.units.match_state.rival_hq).size() > 1, "Opposing HQs have a playable land route")
	_test_match_save(game)
	game.units.select_box(Rect2(-100000, -100000, 200000, 200000), Transform2D.IDENTITY)
	_check(game.units.selected_units.size() == 3, "Box selects friendly units only")
	game.units.select_one(game.units.units[0])
	_check(game.units.selected_units.size() == 1, "Click replaces group selection")
	game.units.select_box(Rect2(-100000, -100000, 1, 1), Transform2D.IDENTITY)
	_check(game.units.selected_units.is_empty() and game.units.selected == null, "Empty box clears selection")
	_check(game.hud.build_buttons.size() == 4 and not game.hud.build_buttons.has("headquarters"), "HQ-victory construction menu excludes headquarters and retains power plants")
	game.hud.show_tile_actions(game.units.units[0].hex, game.units.economy, game.units.territory, tiles)
	_check(game.hud.build_panel.visible and game.hud.command_tabs.get_tab_count() == 4 and game.hud.build_buttons["barracks"].visible, "Tabbed construction sidebar remains available while inspecting buildings")
	game.hud.show_tile_actions(Vector2i(-9999, -9999), game.units.economy, game.units.territory, tiles)
	_check(game.hud.build_panel.visible, "Construction sidebar remains available without a valid selected tile")
	var before_selection: float = game.units.economy.credits
	game._begin_build("barracks")
	_check(game.units.build_kind == "barracks" and game.units.economy.credits == before_selection, "Building selection enters ghost mode without spending")
	var rotate: InputEventKey = InputEventKey.new()
	rotate.pressed = true
	rotate.keycode = KEY_Q
	for index in range(7):
		game._unhandled_input(rotate)
	_check(game.units.build_rotation == 1, "Placement rotation wraps through six hex orientations")
	game._place_build(game.world_map.hex_to_world(game.units.match_state.player_hq))
	_check(game.units.build_kind == "barracks" and game.units.economy.credits == before_selection, "Occupied placement retains ghost without debit")
	game._input(escape)
	_check(game.units.build_kind.is_empty() and not game.hud.pause_overlay.visible, "Escape cancels placement before opening pause menu")
	_test_building_placement()
	_test_construction()
	_test_construction_cancellation()
	_test_power()
	_test_repairs_and_sales()
	_test_economy_interface()
	preload("res://tests/rival_economy_tests.gd").run(_check)
	preload("res://tests/terrain_tests.gd").run(_check)
	preload("res://tests/road_tests.gd").run(_check)
	preload("res://tests/supply_tests.gd").run(_check)
	_test_supply_ui_and_save()
	_test_ai_integration()
	game._begin_build("")
	_check(game.units.build_kind.is_empty(), "Placement can be cancelled")
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
	_check(game.units.match_state.result == "victory", "Capturing the rival HQ ends the live match")
	var credits_at_end: float = game.units.economy.credits
	game.units._physics_process(20.0)
	_check(game.units.economy.credits == credits_at_end, "Finished match freezes simulation and income")
	game._begin_build("barracks")
	game._train_selected("rifle")
	_check(game.units.economy.credits == credits_at_end, "Finished match blocks construction and training commands")
	game.hud.show_match_status(game.units.match_state)
	_check(game.hud.match_label.text.begins_with("VICTORY") and not game.hud.build_panel.visible, "Result is visible and build UI hidden")
	current_scene = game
	game.units.economy.credits = 17.0
	game._restart_match()
	await process_frame
	await process_frame
	var restarted: Node = current_scene
	_check(restarted != null and restarted.units.match_state.result == "playing", "Restart reloads a playing match")
	if restarted != null:
		_check(restarted.units.units.size() == 4 and restarted.units.economy.credits >= 400 and restarted.units.economy.credits < 410 and restarted.units.selected == null, "Restart resets roster, economy and selection (allowing initial income ticks)")
		restarted.free()
	current_scene = null
	print("Hex Dominion v0.3 Slice C: %d passed, %d failed" % [_successes, _failures])
	quit(1 if _failures > 0 else 0)


func _test_ai_integration() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	var restored: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	root.add_child(restored)
	game.units.set_physics_process(false)
	restored.units.set_physics_process(false)
	var tiles: Dictionary = game.world_map.map_data["tiles"]
	var barracks: Vector2i = game.units.units[1].hex
	var factory: Vector2i = game.units.units[2].hex
	_check(game.units.economy.build(barracks, "barracks", tiles, game.units.territory, 0, game.units.match_state.rival_economy.buildings) and game.units.economy.build(factory, "factory", tiles, game.units.territory, 0, game.units.match_state.rival_economy.buildings), "Full match player constructs functional production using normal prices")
	for tick in range(300):
		game.units._physics_process(0.1)
	game.units.economy.train(barracks, "rifle", game.units.territory)
	game.units.economy.train(factory, "tank", game.units.territory)
	var rival: EconomyState = game.units.match_state.rival_economy
	var peak_structures: int = rival.buildings.size()
	for hex in rival.buildings.keys():
		if rival.buildings[hex]["kind"] == "power_plant":
			rival.damage_building(hex, 10000)
			break
	if rival.buildings.has(game.units.match_state.rival_hq):
		rival.damage_building(game.units.match_state.rival_hq, 50)
	var snapshot: Dictionary = MatchSave.capture(game.units, Vector2.ZERO, Vector2.ONE, barracks)
	_check(MatchSave.validate(snapshot, tiles) and MatchSave.restore(restored.units, snapshot), "Mid-expansion damaged infrastructure and active jobs restore as a valid match")
	var invariant: bool = true
	var deterministic: bool = true
	var observed_end: bool = false
	for tick in range(3600):
		game.units._physics_process(0.1)
		restored.units._physics_process(0.1)
		peak_structures = maxi(peak_structures, game.units.match_state.rival_economy.buildings.size())
		if tick % 100 == 0:
			var live: Dictionary = MatchSave.capture(game.units, Vector2.ZERO, Vector2.ONE, barracks)
			var clone: Dictionary = MatchSave.capture(restored.units, Vector2.ZERO, Vector2.ONE, barracks)
			invariant = invariant and MatchSave.validate(live, tiles) and MatchSave.validate(clone, tiles)
			deterministic = deterministic and live == clone
		if game.units.match_state.result != "playing":
			observed_end = true
	_check(peak_structures > 2, "Live-map AI expands infrastructure beyond starting HQ and barracks")
	_check(invariant, "Six-minute full-match integration keeps both economies, routes, construction, repairs and ownership savable")
	_check(deterministic, "Saved AI recovery resumes identically through construction, spending, combat and match completion")
	_check(observed_end and game.units.match_state.result == restored.units.match_state.result, "Economic AI still reaches a stable latched full-match result")
	var final_state: Dictionary = MatchSave.capture(game.units, Vector2.ZERO, Vector2.ONE, barracks)
	for tick in range(20):
		game.units._physics_process(0.1)
	_check(MatchSave.capture(game.units, Vector2.ZERO, Vector2.ONE, barracks) == final_state, "Finished full match cannot keep spending or producing after result latch")
	root.remove_child(game)
	root.remove_child(restored)
	game.free()
	restored.free()


func _test_match_ai() -> void:
	var tiles: Dictionary = {}
	for index in range(9):
		tiles[Vector2i(index, 0)] = {"is_land": true}
	var territory: TerritoryState = TerritoryState.new()
	territory.owners[Vector2i.ZERO] = 1
	territory.owners[Vector2i(8, 0)] = 2
	territory.owners[Vector2i(7, 0)] = 2
	var match_state: MatchState = MatchState.new()
	match_state.player_hq = Vector2i.ZERO
	match_state.rival_hq = Vector2i(8, 0)
	match_state.rival_economy.add_building(Vector2i(8, 0), "headquarters")
	match_state.rival_economy.add_building(Vector2i(7, 0), "barracks")
	var rival: UnitState = UnitState.new(Vector2i(8, 0))
	rival.faction = 2
	var roster: Array[UnitState] = [rival]
	match_state.advance_ai(7.0, tiles, territory, roster)
	_check(rival.path.is_empty(), "AI opening grace period")
	match_state.advance_ai(1.0, tiles, territory, roster)
	_check(rival.path == [Vector2i(7, 0)], "AI follows a walkable route toward player HQ")
	_check(match_state.rival_economy.credits == 350, "AI production pays normal training costs")
	var recruits: Array[UnitState] = match_state.rival_economy.advance(4, tiles, territory)
	_check(recruits.size() == 1 and recruits[0].faction == 2, "Rival production creates rival units")
	rival.hex = Vector2i(6, 0)
	rival.path.clear()
	match_state.advance_ai(1, tiles, territory, roster)
	_check(rival.path.is_empty(), "AI stops on neutral hex to finish capture")
	territory.advance(3, tiles, roster)
	match_state.advance_ai(1, tiles, territory, roster)
	_check(rival.path == [Vector2i(5, 0)], "AI resumes expansion after capture")
	rival.path.clear()
	var enemy: UnitState = UnitState.new(Vector2i(5, 0))
	roster.append(enemy)
	match_state.advance_ai(1, tiles, territory, roster)
	_check(rival.path.is_empty(), "AI holds in firing range instead of suppressing its attack")
	var credits: float = match_state.rival_economy.credits
	match_state.rival_economy.credits = 0
	match_state.advance_ai(1, tiles, territory, roster)
	_check(match_state.rival_economy.credits == 0, "AI cannot spend unavailable credits")
	match_state.rival_economy.credits = credits
	for index in range(8):
		var extra: UnitState = UnitState.new(Vector2i(8, 0))
		extra.faction = 2
		extra.garrisoned = true
		roster.append(extra)
	var queued_before: int = 0
	for building in match_state.rival_economy.buildings.values():
		queued_before += building["queue"].size()
	match_state.advance_ai(1, tiles, territory, roster)
	var queued_after: int = 0
	for building in match_state.rival_economy.buildings.values():
		queued_after += building["queue"].size()
	_check(queued_after == queued_before and match_state.rival_economy.credits >= 0, "AI roster cap bounds recruitment while allowing paid infrastructure")
	match_state.evaluate(territory)
	_check(match_state.result == "playing", "Owned HQs keep match active")
	territory.owners[Vector2i.ZERO] = 2
	match_state.evaluate(territory)
	_check(match_state.result == "defeat", "Player HQ captured causes defeat")
	territory.owners[Vector2i(8, 0)] = 1
	match_state.evaluate(territory)
	_check(match_state.result == "defeat", "Match result is latched")
	match_state.result = "playing"
	match_state.evaluate(territory)
	_check(match_state.result == "draw", "Simultaneous HQ capture draws")


func _test_match_save(game: Node) -> void:
	var tiles: Dictionary = game.world_map.map_data["tiles"]
	var initial: Dictionary = MatchSave.capture(game.units, game.camera.position, game.camera.zoom, game.world_map.selected_hex)
	_check(MatchSave.validate(initial, tiles), "Initial match snapshot validates")
	var legacy: Dictionary = initial.duplicate(true)
	legacy["economy"].erase("account")
	legacy["rival_economy"].erase("account")
	_check(MatchSave.restore(game.units, legacy) and game.units.economy.account.get_history().size() == 1, "Balance-only legacy saves initialize an opening ledger")
	_check(MatchSave.restore(game.units, initial), "Account-aware initial save restores")
	var rival_hq: Vector2i = game.units.match_state.rival_hq
	var moving: UnitState = game.units.units[0]
	moving.order_move(tiles, rival_hq)
	moving.advance(0.1, tiles)
	moving.health = 67.0
	game.units.selected_units.append(moving)
	game.units.selected = moving
	game.units.territory.captures[rival_hq] = {"faction": 1, "elapsed": 1.25}
	var player_yard: Vector2i = game.units.units[1].hex
	game.units.economy.add_building(player_yard, "factory")
	game.units.economy.train(player_yard, "tank", game.units.territory)
	game.units.economy.buildings[player_yard]["elapsed"] = 2.5
	game.units.economy.buildings[player_yard]["rotation"] = 3
	var saved_deposit: Vector2i
	for hex in tiles:
		if tiles[hex].get("terrain", "") == "resource" and not game.units.economy.buildings.has(hex) and not game.units.match_state.rival_economy.buildings.has(hex):
			saved_deposit = hex
			game.units.territory.owners[hex] = 1
			game.units.economy.build(hex, "extractor", tiles, game.units.territory)
			game.units.economy.damage_extractor(hex, 37)
			game.units.economy.buildings[hex]["construction"] = 1.25
			break
	var saved_plant: Vector2i
	for hex in tiles:
		if HexPathfinding.is_walkable(tiles, hex) and not game.units.economy.buildings.has(hex) and not game.units.match_state.rival_economy.buildings.has(hex):
			saved_plant = hex
			game.units.territory.owners[hex] = 1
			game.units.economy.add_building(hex, "power_plant")
			game.units.economy.damage_building(hex, 63)
			game.units.economy.set_repair(hex, game.units.territory, game.units.economy.buildings[hex], true)
			break
	var saved_power: Dictionary = game.units.economy.power_balance(game.units.territory)
	var snapshot: Dictionary = MatchSave.capture(game.units, Vector2(42, 78), Vector2(0.8, 0.8), rival_hq)
	_check(MatchSave.validate(snapshot, tiles), "Mid-edge, damage, capture and production snapshot validates")
	_check(snapshot["economy"]["buildings"][saved_deposit]["health"] == 163, "Damaged extractor health is included in match snapshots")
	_check(snapshot["economy"]["buildings"][saved_deposit]["construction"] == 1.25, "Partially built damaged foundation saved with exact timer")
	var invalid: Dictionary = snapshot.duplicate(true)
	invalid["economy"]["buildings"][saved_deposit]["construction"] = INF
	_check(not MatchSave.validate(invalid, tiles), "Non-finite construction timer rejected")
	invalid = snapshot.duplicate(true)
	invalid["economy"]["buildings"][saved_deposit]["construction"] = -1.0
	_check(not MatchSave.validate(invalid, tiles), "Negative construction timer rejected")
	invalid = snapshot.duplicate(true)
	invalid["economy"]["buildings"][saved_deposit]["construction"] = 6.0
	_check(not MatchSave.validate(invalid, tiles), "Construction timer beyond completion rejected")
	invalid = snapshot.duplicate(true)
	invalid["economy"]["buildings"][saved_deposit]["queue"] = ["rifle"]
	_check(not MatchSave.validate(invalid, tiles), "Unfinished structures cannot load production queues")
	invalid = snapshot.duplicate(true)
	_check(snapshot["economy"]["buildings"][player_yard]["rotation"] == 3, "Building orientation survives snapshot capture")
	invalid["economy"]["buildings"][player_yard]["rotation"] = 6
	_check(not MatchSave.validate(invalid, tiles), "Saved building orientation outside six directions rejected")
	invalid = snapshot.duplicate(true)
	invalid["economy"]["buildings"][saved_deposit]["health"] = 0
	_check(not MatchSave.validate(invalid, tiles), "Destroyed extractor cannot persist as operational infrastructure")
	invalid = snapshot.duplicate(true)
	invalid["version"] = 99
	_check(not MatchSave.restore(game.units, invalid) and moving.health == 67, "Future schema rejected without mutating match")
	invalid = snapshot.duplicate(true)
	invalid["units"][0]["path"] = [Vector2i(-9999, -9999)]
	_check(not MatchSave.restore(game.units, invalid) and game.units.selected == moving, "Invalid movement route rejected without losing selection")
	invalid = snapshot.duplicate(true)
	invalid["economy"]["credits"] = -5
	_check(not MatchSave.validate(invalid, tiles), "Negative saved funds rejected")
	invalid = snapshot.duplicate(true)
	invalid["economy"]["account"]["history"][0]["balance"] = -1
	_check(not MatchSave.restore(game.units, invalid), "Malformed saved transaction history rejects entire load")
	invalid = snapshot.duplicate(true)
	invalid["rival_economy"]["credits"] += 1
	_check(not MatchSave.validate(invalid, tiles), "Rival account and saved credits must agree")
	invalid = snapshot.duplicate(true)
	invalid["rival_economy"]["buildings"][rival_hq]["queue"] = ["rifle"]
	_check(not MatchSave.validate(invalid, tiles), "Incompatible production rejected")
	_check(not MatchSave.validate({"version": 1}, tiles), "Missing snapshot fields rejected")
	var path: String = "user://slice_g_test.hds"
	_check(MatchSave.write(snapshot, tiles, path) == OK, "Snapshot writes to temporary file then replaces save")
	_check(MatchSave.write(snapshot, tiles, path) == OK and FileAccess.file_exists(path + ".bak"), "Replacing save preserves previous backup")
	var disk: Dictionary = MatchSave.read_valid(tiles, path)
	_check(disk == snapshot, "Disk round trip preserves complete state")
	var corrupt: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_var({"version": 999})
	corrupt.close()
	_check(MatchSave.read_valid(tiles, path) == snapshot, "Invalid primary save falls back to valid backup")
	_check(MatchSave.write(snapshot, tiles, path) == OK, "Saving after a damaged primary succeeds")
	corrupt = FileAccess.open(path, FileAccess.WRITE)
	corrupt.store_32(200)
	corrupt.close()
	_check(MatchSave.read_valid(tiles, path) == snapshot, "Truncated primary falls back and previous good backup survives")
	_check(MatchSave.restore(game.units, disk), "Validated snapshot restores")
	_check(game.units.economy.buildings[saved_plant]["health"] == 187 and game.units.economy.buildings[saved_plant]["repairing"] and game.units.economy.power_balance(game.units.territory) == saved_power, "Saved repairing power plant restores health, repair job and derived power")
	_check(game.units.selected == null and game.units.selected_units.is_empty() and game.units.combat_targets.is_empty(), "Loading clears stale presentation references")
	_check(MatchSave.capture(game.units, Vector2(42, 78), Vector2(0.8, 0.8), rival_hq) == snapshot, "Restored simulation matches all saved fields")
	var other: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(other)
	MatchSave.restore(other.units, disk)
	for index in range(90):
		game.units._physics_process(1.0 / 60.0)
		other.units._physics_process(1.0 / 60.0)
	_check(MatchSave.capture(game.units, Vector2.ZERO, Vector2.ONE, rival_hq) == MatchSave.capture(other.units, Vector2.ZERO, Vector2.ONE, rival_hq), "Restored matches advance identically through movement and capture")
	var restored_site: Dictionary = other.units.economy.buildings[saved_deposit]
	other.world_map.selected_hex = saved_deposit
	other.hud.show_tile_actions(saved_deposit, other.units.economy, other.units.territory, tiles)
	_check(other.hud.cancel_construction_button.visible, "Restored unfinished site exposes cancellation action")
	var refund_balance: float = other.units.economy.credits
	other.hud.cancel_construction_button.pressed.emit()
	_check(not other.units.economy.buildings.has(saved_deposit) and other.units.economy.credits == refund_balance + 50, "HUD cancellation refunds restored site and releases hex")
	_check(not other.hud.cancel_construction_button.visible, "Cancellation immediately clears stale HUD action")
	var cancelled_save: Dictionary = MatchSave.capture(other.units, Vector2.ZERO, Vector2.ONE, saved_deposit)
	_check(MatchSave.restore(other.units, cancelled_save) and not other.units.economy.cancel_construction(saved_deposit, other.units.territory, restored_site) and other.units.economy.credits == refund_balance + 50, "Post-cancellation save cannot resurrect site or double refund")
	other._select_facility(saved_plant)
	_check(other.hud.repair_button.visible and other.hud.repair_button.text == "Stop repairs" and other.hud.sell_button.visible, "Completed damaged building exposes stop-repair and sale actions")
	other.hud.repair_button.pressed.emit()
	_check(not other.units.economy.buildings[saved_plant]["repairing"], "HUD stop-repair cancels loaded job")
	var sold_site: Dictionary = other.units.economy.buildings[saved_plant]
	var sale_balance: float = other.units.economy.credits
	other.hud.sell_button.pressed.emit()
	_check(not other.units.economy.buildings.has(saved_plant) and other.units.economy.credits == sale_balance + 75 and not other.hud.sell_button.visible, "HUD sale credits salvage and clears stale controls")
	var sold_save: Dictionary = MatchSave.capture(other.units, Vector2.ZERO, Vector2.ONE, saved_plant)
	_check(MatchSave.restore(other.units, sold_save) and not other.units.economy.sell_building(saved_plant, other.units.territory, sold_site) and other.units.economy.credits == sale_balance + 75, "Sold state survives load without duplicate salvage")
	var sold_hq: Vector2i = other.units.match_state.player_hq
	_check(other.units.economy.sell_building(sold_hq, other.units.territory, other.units.economy.buildings[sold_hq]) and MatchSave.validate(MatchSave.capture(other.units, Vector2.ZERO, Vector2.ONE, sold_hq), tiles), "Selling HQ leaves a valid savable match with original capture objective")
	MatchSave.restore(other.units, initial)
	for index in range(2400):
		other.units._physics_process(0.1)
		if other.units.match_state.result != "playing":
			break
	_check(other.units.match_state.result == "defeat", "Unopposed autonomous rival can recruit, fight and capture the player HQ")
	var ended: Dictionary = MatchSave.capture(other.units, Vector2.ZERO, Vector2.ONE, rival_hq)
	_check(MatchSave.restore(other.units, ended) and other.units.match_state.result == "defeat", "Finished match saves and loads without resuming play")
	other.free()
	_check(MatchSave.restore(game.units, initial), "Restore initial state for subsequent integration tests")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	_check(MatchSave.read_valid(tiles, path).is_empty(), "Missing save handled without changing match")
	var slot_dir: String = "user://slice_g_named_test"
	var old_test_dir: DirAccess = DirAccess.open(slot_dir)
	if old_test_dir != null:
		for filename in old_test_dir.get_files():
			if filename.begins_with("save_") and (filename.ends_with(".hds") or filename.ends_with(".hds.bak") or filename.ends_with(".hds.tmp")):
				DirAccess.remove_absolute(slot_dir.path_join(filename))
	var first: Dictionary = MatchSave.write_slot(initial, tiles, "Front line", "", slot_dir)
	var second: Dictionary = MatchSave.write_slot(initial, tiles, "Front line", "", slot_dir)
	_check(first["error"] == OK and second["error"] == OK and first["path"] != second["path"], "Named saves create separate files even with duplicate display names")
	var slots: Array[Dictionary] = MatchSave.list_slots(tiles, slot_dir, false)
	_check(slots.size() == 2 and slots[0]["name"] == "Front line" and slots[0]["valid"] and slots[0]["saved_at"] > 0, "Save browser lists named saves with timestamps and validity")
	_check(MatchSave.write_slot(initial, tiles, "   ", "", slot_dir)["error"] == ERR_INVALID_PARAMETER, "Blank save name rejected")
	_check(MatchSave.write_slot(initial, tiles, "Escape", "user://outside.hds", slot_dir)["error"] == ERR_INVALID_PARAMETER, "Overwrite cannot escape save directory")
	var changed: Dictionary = initial.duplicate(true)
	changed["economy"]["credits"] = 123.0
	changed["economy"]["account"] = CreditsAccount.new(123.0).snapshot()
	_check(MatchSave.write_slot(changed, tiles, "Renamed front", first["path"], slot_dir)["error"] == OK, "Selected named save can be overwritten and renamed")
	var named: Dictionary = MatchSave.read_valid(tiles, first["path"])
	_check(named["save_name"] == "Renamed front" and named["economy"]["credits"] == 123 and FileAccess.file_exists(first["path"] + ".bak"), "Overwrite retains new state and previous backup")
	game._set_menu_open(true)
	game.hud.show_save_browser("save", slots)
	_check(game.hud.save_browser.visible and game.hud.save_list.item_count == 3 and game.hud.save_accept.text == "Create save", "Save screen offers new-save row plus existing saves")
	game.hud.save_list.select(1)
	game.hud._on_save_selected(1)
	_check(game.hud.save_name.text == "Front line" and game.hud.save_accept.text == "Overwrite save", "Selecting an existing save enables named overwrite")
	game.hud._accept_save_browser()
	_check(game.hud.overwrite_dialog.visible, "Overwriting requires explicit confirmation")
	game.hud.overwrite_dialog.hide()
	var empty_slots: Array[Dictionary] = []
	game.hud.show_save_browser("load", empty_slots)
	_check(game.hud.save_accept.disabled and not game.hud.save_name.visible, "Empty load screen disables loading and hides name entry")
	game.hud.show_save_browser("load", slots)
	game.hud.save_list.select(0)
	game.hud._on_save_selected(0)
	_check(not game.hud.save_accept.disabled and game.hud._selected_save_path() == slots[0]["path"], "Load screen selects a specific save path")
	game._load_slot(first["path"])
	_check(game.units.economy.credits == 123 and not game.hud.pause_overlay.visible, "Loading chosen named save restores it and resumes match")
	MatchSave.restore(game.units, initial)
	for slot_path in [first["path"], second["path"]]:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(slot_path + suffix):
				DirAccess.remove_absolute(slot_path + suffix)
	DirAccess.remove_absolute(slot_dir)


func _test_credits_accounts() -> void:
	var wallet: CreditsAccount = CreditsAccount.new(100.0)
	_check(wallet.balance == 100 and wallet.get_history()[0]["type"] == "starting_funds", "Starting funds open an auditable account")
	_check(wallet.can_afford(100) and not wallet.can_afford(100.01), "Affordability includes exact balance but no overdraft")
	_check(wallet.try_spend(100, "Exact funds") and wallet.balance == 0, "Exact-funds debit reaches zero")
	var history: Array[Dictionary] = wallet.get_history()
	_check(not wallet.try_spend(0.01) and wallet.balance == 0 and wallet.get_history() == history, "Rejected debit changes neither balance nor history")
	_check(wallet.add_income(12.5, "Test income") and wallet.balance == 12.5, "Fractional income credited")
	_check(wallet.add_income(2.5, "Test income") and wallet.get_history().size() == 3 and wallet.get_history()[-1]["amount"] == 15, "Continuous income coalesces without dropping value")
	_check(wallet.try_spend(5, "Unit") and wallet.get_history()[-1]["amount"] == -5 and wallet.get_history()[-1]["balance"] == 10, "Purchase ledger records signed amount, reason and resulting balance")
	history = wallet.get_history()
	for amount in [-1.0, NAN, INF, -INF]:
		_check(not wallet.can_afford(amount) and not wallet.try_spend(amount) and not wallet.add_income(amount) and not wallet.set_balance(amount), "Invalid money amount rejected: %s" % amount)
	_check(wallet.balance == 10 and wallet.get_history() == history, "Invalid operations are completely side-effect free")
	_check(wallet.try_spend(0) and wallet.add_income(0) and wallet.get_history() == history, "Zero-value operations do not flood transaction history")
	history[0]["balance"] = -999
	_check(wallet.get_history()[0]["balance"] == 100, "Transaction history returns a defensive copy")
	var full: CreditsAccount = CreditsAccount.new(CreditsAccount.MAX_CREDITS)
	_check(not full.add_income(1) and full.balance == CreditsAccount.MAX_CREDITS, "Income ceiling rejects overflow without changing balance")
	_check(CreditsAccount.new(-1).balance == 0, "Invalid starting funds cannot create debt")
	var restored: CreditsAccount = CreditsAccount.new(0)
	_check(restored.restore(wallet.snapshot()) and restored.snapshot() == wallet.snapshot(), "Account balances and full history restore identically")
	var bad: Dictionary = wallet.snapshot()
	bad["history"][-1]["balance"] = -1
	_check(not restored.restore(bad) and restored.balance == 10, "Invalid ledger rejected without mutating account")
	bad = wallet.snapshot()
	bad["balance"] = 999
	_check(not CreditsAccount.valid_snapshot(bad), "Ledger and balance disagreement rejected")
	for faction in [1, 2]:
		var economy: EconomyState = EconomyState.new(150)
		economy.faction = faction
		var home: Vector2i = Vector2i.ZERO
		var yard: Vector2i = Vector2i(1, 0)
		var territory: TerritoryState = TerritoryState.new()
		territory.owners[home] = faction
		territory.owners[yard] = faction
		var tiles: Dictionary = {home: {"is_land": true, "terrain": "city"}, yard: {"is_land": true}}
		_check(economy.build(home, "barracks", tiles, territory) and economy.credits == 50, "Faction %d construction uses shared wallet" % faction)
		economy.advance(6, {home: {"is_land": true}, yard: {"is_land": true}}, territory)
		_check(economy.train(home, "rifle", territory) and economy.credits == 0, "Faction %d unit training charges exact remaining funds" % faction)
		var before: Dictionary = economy.account.snapshot()
		_check(not economy.train(home, "rifle", territory) and not economy.build(yard, "barracks", tiles, territory) and economy.account.snapshot() == before, "Faction %d repeated purchases cannot overdraw or log rejected charges" % faction)
		var recruits: Array[UnitState] = economy.advance(4, tiles, territory)
		_check(recruits.size() == 1 and recruits[0].faction == faction and economy.credits == 0, "Faction %d production completion does not double-charge; unsupplied city earns nothing" % faction)
		economy.credits = -500
		_check(economy.credits == 0, "Faction %d legacy direct assignment cannot create negative credits" % faction)
		before = economy.account.snapshot()
		economy.advance(NAN, tiles, territory)
		economy.advance(INF, tiles, territory)
		_check(economy.account.snapshot() == before, "Non-finite simulation time cannot corrupt funds")
		var copy: EconomyState = EconomyState.new()
		copy.account.restore(economy.account.snapshot())
		_check(copy.credits == economy.credits and copy.account.get_history() == economy.account.get_history(), "Faction ledger restoration preserves income and purchases")
	var repeated: CreditsAccount = CreditsAccount.new(1)
	for index in range(100):
		repeated.try_spend(0.1, "Repeated purchase")
	_check(repeated.balance >= 0 and repeated.balance < 0.1, "Repeated fractional debit never crosses below zero")


func _test_extractors() -> void:
	var deposit: Vector2i = Vector2i.ZERO
	var plain: Vector2i = Vector2i(1, 0)
	var tiles: Dictionary = {deposit: {"is_land": true, "terrain": "resource"}, plain: {"is_land": true, "terrain": "plains"}}
	for faction in [1, 2]:
		var economy: EconomyState = EconomyState.new(100)
		economy.faction = faction
		var territory: TerritoryState = TerritoryState.new()
		territory.owners[plain] = faction
		_check(not economy.build(deposit, "extractor", tiles, territory) and not economy.build(plain, "extractor", tiles, territory) and economy.credits == 100, "Extractor requires a captured resource deposit for faction %d" % faction)
		territory.owners[deposit] = faction
		_check(economy.income_rate(tiles, territory) == 0, "Bare owned deposit produces no credits")
		_check(economy.build(deposit, "extractor", tiles, territory) and economy.credits == 0, "Extractor charges its full construction cost")
		_check(not economy.build(deposit, "extractor", tiles, territory), "Cannot stack extractors on one deposit")
		var power_site: Vector2i = Vector2i(5, 0)
		economy.add_building(power_site, "power_plant")
		territory.owners[power_site] = faction
		economy.advance(EconomyState.BUILD_SECONDS["extractor"], tiles, territory)
		economy.advance(0.5, tiles, territory)
		_check(economy.credits == 0 and economy.income_rate(tiles, territory) == 0, "Powered extractor without HQ supply earns nothing")
		_check(not economy.train(deposit, "rifle", territory), "Extractor is not a production building")
		territory.contested[deposit] = true
		_check(economy.income_rate(tiles, territory) == 0, "Contesting a deposit suspends extraction")
		territory.contested.clear()
		territory.owners[deposit] = 3 - faction
		_check(economy.income_rate(tiles, territory) == 0, "Territory loss immediately stops extraction")
		territory.owners[deposit] = faction
		_check(economy.income_rate(tiles, territory) == 0, "Recapture without HQ does not enable surviving extractor")
		_check(not economy.damage_extractor(deposit, -1) and not economy.damage_extractor(deposit, INF), "Invalid extractor damage rejected")
		var enemy: UnitState = UnitState.new(plain)
		enemy.faction = 3 - faction
		var roster: Array[UnitState] = [enemy]
		var economies: Array[EconomyState] = [economy]
		CombatState.attack_extractors(1, roster, economies, {})
		_check(economy.buildings[deposit]["health"] == 180 and economy.income_rate(tiles, territory) == 0, "Hostile rifle damages unsupplied extractor without destroying it prematurely")
		var defender: UnitState = UnitState.new(deposit)
		defender.faction = faction
		roster.append(defender)
		var targets: Dictionary = CombatState.advance(0.1, roster)
		CombatState.attack_extractors(0.1, roster, economies, targets)
		_check(economy.buildings[deposit]["health"] == 180, "Defending units take combat priority; no duplicate attack budget")
		roster.erase(defender)
		enemy.path.append(Vector2i(2, 0))
		CombatState.attack_extractors(1, roster, economies, {})
		_check(economy.buildings[deposit]["health"] == 180, "Moving attackers cannot damage extractors")
		enemy.path.clear()
		CombatState.attack_extractors(10, roster, economies, {})
		_check(not economy.buildings.has(deposit) and economy.income_rate(tiles, territory) == 0, "Destroyed extractor is removed and immediately stops earning")
		economy.credits = 100
		_check(economy.build(deposit, "extractor", tiles, territory) and economy.buildings[deposit]["health"] == 200, "Destroyed extractor can be rebuilt at full cost")


func _test_city_income() -> void:
	var city: Vector2i = Vector2i.ZERO
	var plain: Vector2i = Vector2i(1, 0)
	var resource: Vector2i = Vector2i(2, 0)
	var tiles: Dictionary = {city: {"is_land": true, "terrain": "city"}, plain: {"is_land": true, "terrain": "plains"}, resource: {"is_land": true, "terrain": "resource"}}
	var territory: TerritoryState = TerritoryState.new()
	var player: EconomyState = EconomyState.new(0)
	var rival: EconomyState = EconomyState.new(0)
	rival.faction = 2
	territory.owners[plain] = 1
	territory.owners[resource] = 1
	_check(player.income_rate(tiles, territory) == 0, "Ordinary and resource hexes generate no passive territory credits")
	var squad: UnitState = UnitState.new(city)
	var roster: Array[UnitState] = [squad]
	territory.advance(2.0, tiles, roster)
	_check(player.income_rate(tiles, territory) == 0, "Neutral city has no income before capture completes")
	territory.advance(1.0, tiles, roster)
	_check(player.income_rate(tiles, territory) == 0 and not territory.is_contested(city), "Captured city without HQ remains unsupplied")
	player.advance(0.5, tiles, territory)
	_check(player.credits == 0, "Unsupplied city credits no passive income")
	var enemy: UnitState = UnitState.new(city)
	enemy.faction = 2
	roster.append(enemy)
	territory.advance(0.1, tiles, roster)
	_check(territory.is_contested(city) and territory.captures.is_empty() and player.income_rate(tiles, territory) == 0, "Mixed-faction contest interrupts city income even before capture progress exists")
	player.advance(1.0, tiles, territory)
	rival.advance(1.0, tiles, territory)
	_check(player.credits == 0 and rival.credits == 0, "Neither faction earns from a contested city")
	roster.erase(enemy)
	territory.advance(0.1, tiles, roster)
	_check(not territory.is_contested(city) and player.income_rate(tiles, territory) == 0, "Removing occupants does not bypass HQ supply requirement")
	roster = [enemy]
	territory.advance(1.0, tiles, roster)
	_check(territory.owner_at(city) == 1 and player.income_rate(tiles, territory) == 0 and rival.income_rate(tiles, territory) == 0, "Enemy capture attempt suppresses old owner's income before ownership changes")
	roster.clear()
	territory.advance(0.1, tiles, roster)
	_check(player.income_rate(tiles, territory) == 0, "Abandoned capture leaves city owned but unsupplied")
	roster.append(enemy)
	territory.advance(3.0, tiles, roster)
	_check(player.income_rate(tiles, territory) == 0 and rival.income_rate(tiles, territory) == 0, "Captured city needs new owner's HQ supply")
	rival.advance(0.25, tiles, territory)
	_check(rival.credits == 0, "AI obeys identical HQ supply requirement")
	rival.add_building(city, "headquarters")
	_check(rival.income_rate(tiles, territory) == 6, "HQ bonus remains explicit building income separate from city income")
	roster.append(squad)
	territory.advance(0.1, tiles, roster)
	_check(rival.income_rate(tiles, territory) == 0, "Hostile occupation also interrupts the HQ bonus")
	squad.health = 0
	territory.advance(0.1, tiles, roster)
	_check(rival.income_rate(tiles, territory) == 6, "Dead hostile units cannot suppress city income")


func _test_economy() -> void:
	var home: Vector2i = Vector2i.ZERO
	var yard: Vector2i = Vector2i(1, 0)
	var goal: Vector2i = Vector2i(2, 0)
	var tiles: Dictionary = {home: {"is_land": true, "terrain": "city"}, yard: {"is_land": true, "terrain": "resource"}, goal: {"is_land": true}}
	var territory: TerritoryState = TerritoryState.new()
	territory.owners[home] = 1
	territory.owners[yard] = 1
	var economy: EconomyState = EconomyState.new()
	economy.add_building(home, "headquarters")
	_check(not economy.build(yard, "headquarters", tiles, territory) and economy.credits == 400.0, "Second HQ rejected without charge")
	territory.owners[home] = 2
	_check(not economy.build(yard, "headquarters", tiles, territory), "Lost HQ still counts toward one-HQ limit")
	territory.owners[home] = 1
	_check(economy.income_rate(tiles, territory) == 6.0, "HQ and city income only; resource tiles have no passive income")
	_check(economy.can_build(yard, "barracks", tiles, territory) and economy.credits == 400.0 and not economy.buildings.has(yard), "Placement preview validates without spending or constructing")
	_check(not economy.build(goal, "factory", tiles, territory), "Cannot build on neutral land")
	_check(economy.build(yard, "barracks", tiles, territory) and economy.credits == 300.0, "Construction charges credits")
	_check(not economy.build(yard, "factory", tiles, territory), "One building per hex")
	_check(not economy.train(yard, "tank", territory), "Barracks cannot train tanks")
	economy.advance(EconomyState.BUILD_SECONDS["barracks"], tiles, territory)
	economy.credits = 300.0
	_check(economy.train(yard, "rifle", territory) and economy.credits == 250.0, "Training charged up front")
	_check(economy.set_rally(yard, goal, tiles, territory), "Reachable rally accepted")
	_check(not economy.set_rally(yard, Vector2i(99, 99), tiles, territory) and economy.buildings[yard]["rally"] == goal, "Invalid rally preserves old target")
	_check(economy.advance(2.0, tiles, territory).is_empty(), "Training takes time")
	territory.owners[yard] = 2
	_check(economy.advance(10.0, tiles, territory).is_empty() and economy.buildings[yard]["elapsed"] == 2.0, "Lost production pauses")
	territory.owners[yard] = 1
	var recruits: Array[UnitState] = economy.advance(2.0, tiles, territory)
	_check(recruits.size() == 1 and recruits[0].kind == "rifle" and recruits[0].hex == yard and recruits[0].path[-1] == goal, "Reclaimed barracks resumes and recruits follow rally")
	territory.owners[goal] = 1
	_check(economy.build(goal, "factory", tiles, territory), "Factory construction")
	economy.credits = 1000.0
	economy.advance(EconomyState.BUILD_SECONDS["factory"], tiles, territory)
	_check(economy.train(goal, "tank", territory), "Factory queues tanks")
	recruits = economy.advance(8.0, tiles, territory)
	_check(recruits.size() == 1 and recruits[0].kind == "tank" and recruits[0].health == 250.0, "Factory produces configured tank")
	for index in range(5):
		economy.train(yard, "rifle", territory)
	_check(not economy.train(yard, "rifle", territory), "Training queue is bounded")
	_check(economy.advance(20.0, tiles, territory).size() == 5, "Large delta finishes multiple queued units")
	economy.credits = 0.0
	_check(not economy.train(yard, "rifle", territory), "Insufficient funds reject training")
	_check(economy.advance(-1.0, tiles, territory).is_empty() and economy.credits == 0.0, "Negative time does not change economy")


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
	rival.advance(1.0, tiles)
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
	unit.advance(unit.seconds_per_hex * 0.5, tiles)
	_check(unit.hex == start and is_equal_approx(unit.progress, 0.5), "Partial edge keeps logical occupancy")
	var prior: Array[Vector2i] = unit.path.duplicate()
	_check(not unit.order_move(tiles, Vector2i(2, 0)) and unit.path == prior, "Invalid order preserves active route")
	var next: Vector2i = unit.path[0]
	_check(unit.order_move(tiles, start) and unit.path[0] == next and is_equal_approx(unit.progress, 0.5), "Retarget preserves in-flight edge")
	unit.advance(20.0, tiles)
	_check(unit.hex == start and unit.path.is_empty() and unit.progress == 0.0, "Large tick reaches destination without overshoot")
	var a: UnitState = UnitState.new(start)
	var b: UnitState = UnitState.new(start)
	a.order_move(tiles, goal)
	b.order_move(tiles, goal)
	a.advance(0.9, tiles)
	for index in range(9):
		b.advance(0.1, tiles)
	_check(a.hex == b.hex and is_equal_approx(a.progress, b.progress), "Movement independent of tick partition")
	for r in range(3):
		tiles[Vector2i(2, r)]["is_land"] = false
	_check(HexPathfinding.find_path(tiles, start, goal).is_empty(), "Disconnected land rejected")
