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
	_check(game.hud.build_buttons.size() == 3, "Construction menu exposes three building choices")
	game.hud.show_tile_actions(game.units.units[0].hex, game.units.economy, game.units.territory, tiles)
	_check(game.hud.build_panel.visible and game.hud.context_title.text == "TRAINING" and not game.hud.build_buttons["barracks"].visible, "Selected building shows training context rather than construction")
	game.hud.show_tile_actions(Vector2i(-9999, -9999), game.units.economy, game.units.territory, tiles)
	_check(not game.hud.build_panel.visible, "No action panel for invalid tile")
	game._begin_build("barracks")
	_check(game.units.build_kind.is_empty(), "Construction acts on selected tile without placement mode")
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
	print("Hex Dominion v0.2 Slice A: %d passed, %d failed" % [_successes, _failures])
	quit(1 if _failures > 0 else 0)


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
	match_state.advance_ai(1, tiles, territory, roster)
	_check(match_state.rival_economy.credits == credits, "AI roster cap bounds recruitment")
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
	moving.advance(0.1)
	moving.health = 67.0
	game.units.selected_units.append(moving)
	game.units.selected = moving
	game.units.territory.captures[rival_hq] = {"faction": 1, "elapsed": 1.25}
	var player_yard: Vector2i = game.units.units[1].hex
	game.units.economy.add_building(player_yard, "factory")
	game.units.economy.train(player_yard, "tank", game.units.territory)
	game.units.economy.buildings[player_yard]["elapsed"] = 2.5
	var snapshot: Dictionary = MatchSave.capture(game.units, Vector2(42, 78), Vector2(0.8, 0.8), rival_hq)
	_check(MatchSave.validate(snapshot, tiles), "Mid-edge, damage, capture and production snapshot validates")
	var invalid: Dictionary = snapshot.duplicate(true)
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
	_check(game.units.selected == null and game.units.selected_units.is_empty() and game.units.combat_targets.is_empty(), "Loading clears stale presentation references")
	_check(MatchSave.capture(game.units, Vector2(42, 78), Vector2(0.8, 0.8), rival_hq) == snapshot, "Restored simulation matches all saved fields")
	var other: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(other)
	MatchSave.restore(other.units, disk)
	for index in range(90):
		game.units._physics_process(1.0 / 60.0)
		other.units._physics_process(1.0 / 60.0)
	_check(MatchSave.capture(game.units, Vector2.ZERO, Vector2.ONE, rival_hq) == MatchSave.capture(other.units, Vector2.ZERO, Vector2.ONE, rival_hq), "Restored matches advance identically through movement and capture")
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
		_check(economy.train(home, "rifle", territory) and economy.credits == 0, "Faction %d unit training charges exact remaining funds" % faction)
		var before: Dictionary = economy.account.snapshot()
		_check(not economy.train(home, "rifle", territory) and not economy.build(yard, "barracks", tiles, territory) and economy.account.snapshot() == before, "Faction %d repeated purchases cannot overdraw or log rejected charges" % faction)
		var recruits: Array[UnitState] = economy.advance(4, tiles, territory)
		_check(recruits.size() == 1 and recruits[0].faction == faction and economy.credits == 4, "Faction %d production completion does not double-charge" % faction)
		economy.credits = -500
		_check(economy.credits == 4, "Faction %d legacy direct assignment cannot create negative credits" % faction)
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
	_check(economy.income_rate(tiles, territory) == 8.0, "HQ city and resource income")
	_check(economy.can_build(yard, "barracks", tiles, territory) and economy.credits == 400.0 and not economy.buildings.has(yard), "Placement preview validates without spending or constructing")
	_check(not economy.build(goal, "factory", tiles, territory), "Cannot build on neutral land")
	_check(economy.build(yard, "barracks", tiles, territory) and economy.credits == 300.0, "Construction charges credits")
	_check(not economy.build(yard, "factory", tiles, territory), "One building per hex")
	_check(not economy.train(yard, "tank", territory), "Barracks cannot train tanks")
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
	rival.advance(1.0)
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
	unit.advance(unit.seconds_per_hex * 0.5)
	_check(unit.hex == start and is_equal_approx(unit.progress, 0.5), "Partial edge keeps logical occupancy")
	var prior: Array[Vector2i] = unit.path.duplicate()
	_check(not unit.order_move(tiles, Vector2i(2, 0)) and unit.path == prior, "Invalid order preserves active route")
	var next: Vector2i = unit.path[0]
	_check(unit.order_move(tiles, start) and unit.path[0] == next and is_equal_approx(unit.progress, 0.5), "Retarget preserves in-flight edge")
	unit.advance(20.0)
	_check(unit.hex == start and unit.path.is_empty() and unit.progress == 0.0, "Large tick reaches destination without overshoot")
	var a: UnitState = UnitState.new(start)
	var b: UnitState = UnitState.new(start)
	a.order_move(tiles, goal)
	b.order_move(tiles, goal)
	a.advance(0.9)
	for index in range(9):
		b.advance(0.1)
	_check(a.hex == b.hex and is_equal_approx(a.progress, b.progress), "Movement independent of tick partition")
	for r in range(3):
		tiles[Vector2i(2, r)]["is_land"] = false
	_check(HexPathfinding.find_path(tiles, start, goal).is_empty(), "Disconnected land rejected")
