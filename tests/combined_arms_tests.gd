extends SceneTree
var passed: int = 0
var failed: int = 0

func check(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error(label)

func make(kind: String, hex: Vector2i, faction: int = 1) -> UnitState:
	var unit: UnitState = UnitState.new(hex, kind)
	unit.configure_kind(kind)
	unit.faction = faction
	return unit

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var tiles: Dictionary = {}
	for q in range(9):
		for r in range(3):
			tiles[Vector2i(q, r)] = {"is_land": r != 2, "terrain": "plains" if r != 2 else "ocean"}
	var economy: EconomyState = EconomyState.new(10000)
	var enemy_economy: EconomyState = EconomyState.new()
	enemy_economy.faction = 2
	var territory: TerritoryState = TerritoryState.new()
	for hex in tiles:
		territory.set_owner(hex, 1)
	var economies: Array[EconomyState] = [economy, enemy_economy]
	check(UnitCatalog.COSTS.size() == 14, "Thirteen military roles plus one paid logistics role")
	check(UnitCatalog.COSTS.get("supply_truck") == 200 and UnitCatalog.TRAIN_SECONDS.get("supply_truck") == 6.0 and UnitCatalog.TYPES["supply_truck"]["health"] == 100.0, "Supply truck production and health match Slice B tuning")
	for kind in UnitCatalog.COSTS:
		var hex: Vector2i = Vector2i(0, 2 if UnitCatalog.is_naval(kind) else 0)
		var unit: UnitState = make(kind, hex)
		check(UnitCatalog.COSTS.has(kind) and UnitCatalog.TRAIN_SECONDS.has(kind), kind + " paid production configured")
		check(ResourceLoader.exists(UnitArt.asset_path(kind, 1, "base")) and ResourceLoader.exists(UnitArt.asset_path(kind, 2, "damaged")), kind + " distinct faction/state artwork")
		check(unit.order_move(tiles, Vector2i(4, hex.y)), kind + " correct-domain movement")
		if kind == "supply_truck":
			check(not UnitOrders.tactical(unit, "attack_move", Vector2i(5, hex.y), tiles), "Supply truck rejects combat orders")
			check(not UnitOrders.attack(unit, tiles, Vector2i(5, hex.y)), "Supply truck rejects explicit attack orders")
		elif kind != "fighter":
			check(UnitOrders.tactical(unit, "attack_move", Vector2i(5, hex.y), tiles), kind + " attack-move accepted")
			check(UnitOrders.tactical(unit, "patrol", Vector2i(3, hex.y), tiles), kind + " patrol accepted")
			check(UnitOrders.tactical(unit, "guard", Vector2i(1, hex.y), tiles), kind + " guard accepted")
		else:
			check(not UnitOrders.tactical(unit, "patrol", Vector2i(3, 0), tiles), "Fighter cannot bypass strike/rearm with patrol")
		unit.order_hold()
		check(unit.path.is_empty() and unit.holding and unit.tactical_order.is_empty(), kind + " Hold cancels persistent orders")
	var rifle: UnitState = make("rifle", Vector2i.ZERO)
	var enemy: UnitState = make("rifle", Vector2i(1, 0), 2)
	var roster: Array[UnitState] = [rifle, enemy]
	UnitOrders.tactical(rifle, "attack_move", Vector2i(6, 0), tiles)
	UnitOrders.update(roster, tiles, economies)
	check(rifle.path.is_empty() and rifle.tactical_order["mode"] == "attack_move", "Attack-move stops for a threat without losing destination")
	CombatState.advance(0.25, roster, tiles)
	check(enemy.health == 95, "Encountered threat receives real combat damage")
	enemy.health = 0
	UnitOrders.update(roster, tiles, economies)
	check(not rifle.path.is_empty() and rifle.path[-1] == Vector2i(6, 0), "Attack-move resumes after combat")
	rifle.advance(100, tiles)
	UnitOrders.update(roster, tiles, economies)
	check(rifle.tactical_order.is_empty(), "Arrived attack-move terminates")
	rifle.hex = Vector2i.ZERO
	UnitOrders.tactical(rifle, "patrol", Vector2i(4, 0), tiles)
	for cycle in range(4):
		rifle.advance(100, tiles)
		UnitOrders.update(roster, tiles, economies)
		check(rifle.path[-1] == (Vector2i.ZERO if cycle % 2 == 0 else Vector2i(4, 0)), "Patrol reverses repeatedly %d" % cycle)
	rifle.order_hold()
	var escorted: UnitState = make("tank", Vector2i(2, 0))
	roster.append(escorted)
	UnitOrders.tactical(rifle, "guard", escorted.hex, tiles, escorted)
	UnitOrders.update(roster, tiles, economies)
	rifle.advance(100, tiles)
	escorted.hex = Vector2i(4, 0)
	UnitOrders.update(roster, tiles, economies)
	check(rifle.path[-1] == escorted.hex, "Guard follows friendly unit")
	escorted.health = 0
	UnitOrders.update(roster, tiles, economies)
	check(rifle.holding and rifle.guard_target == null, "Lost guard target safely ends order")
	check(not UnitOrders.tactical(rifle, "patrol", Vector2i(2, 2), tiles), "Ground patrol cannot enter water")
	UnitOrders.tactical(rifle, "attack_move", Vector2i(6, 0), tiles)
	rifle.advance(0.1, tiles)
	var progress: float = rifle.progress
	enemy.health = 100
	enemy.hex = Vector2i(1, 0)
	UnitOrders.update(roster, tiles, economies)
	check(rifle.progress == progress and rifle.path.size() == 1, "Encounter commits in-flight edge without teleporting")
	var presentation: ArmyPresentation = ArmyPresentation.new()
	var army: Array[UnitState] = []
	for faction in [1, 2]:
		for kind in UnitCatalog.TYPES:
			for index in range(20):
				army.append(make(kind, Vector2i.ZERO, faction))
	var start: int = Time.get_ticks_usec()
	presentation.refresh(army)
	var elapsed: int = Time.get_ticks_usec() - start
	var expected_army_size: int = UnitCatalog.TYPES.size() * 40
	check(presentation.batches.size() == 2 and presentation.offsets.size() == expected_army_size, "Large army condenses to one marker per faction while retaining every independent unit")
	var total: int = 0
	for batch in presentation.batches:
		total += batch["members"].size()
	check(total == expected_army_size, "Presentation never changes actual counts")
	print("%d-unit grouping rebuild: %d microseconds (local measurement, not a frame-rate guarantee)" % [expected_army_size, elapsed])
	await process_frame
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.units.set_physics_process(false)
	var live_tiles: Dictionary = game.world_map.map_data["tiles"]
	var a: UnitState = game.units.units[0]
	var b: UnitState = game.units.units[1]
	UnitOrders.tactical(a, "guard", b.hex, live_tiles, b)
	var snapshot: Dictionary = MatchSave.capture(game.units, game.camera.position, game.camera.zoom, a.hex)
	check(MatchSave.validate(snapshot, live_tiles), "Guard snapshot validates")
	check(MatchSave.restore(game.units, snapshot), "Guard snapshot restores")
	check(game.units.units[0].guard_target.get_ref() == game.units.units[1], "Guard weak reference rebuilt against restored roster")
	check(MatchSave.capture(game.units, game.camera.position, game.camera.zoom, a.hex) == snapshot, "Persistent orders round-trip exactly")
	var bad: Dictionary = snapshot.duplicate(true)
	bad["units"][0]["tactical_order"]["mode"] = "teleport"
	check(not MatchSave.restore(game.units, bad), "Unknown saved order rejected atomically")
	bad = snapshot.duplicate(true)
	bad["units"][0]["guard_target"] = 9999
	check(not MatchSave.restore(game.units, bad), "Invalid guard index rejected")
	check(MatchSave.capture(game.units, game.camera.position, game.camera.zoom, a.hex) == snapshot, "Rejected load leaves live match unchanged")
	game.units.select_one(game.units.units[0])
	game._defensive_order("patrol")
	game._issue_tactical(game.world_map.hex_to_world(game.units.units[0].hex))
	check(game.units.units[0].tactical_order.get("mode") == "patrol", "HUD command destination dispatch works")
	for zoom in [0.45, 1.0, 2.3]:
		check(not game.units.individual_view(zoom, Vector2i.ZERO, 2), "Enemy stacks remain condensed at zoom %.2f" % zoom)
		check(not game.units.individual_view(zoom, Vector2i.ZERO, 1), "Friendly stacks remain condensed until expanded at zoom %.2f" % zoom)
	game.units.expanded_hex = Vector2i.ZERO
	check(game.units.individual_view(2.3, Vector2i.ZERO, 1), "Explicit expansion reveals friendly stack members")
	game.free()
	_test_ai(tiles)
	print("Combined arms: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func _test_ai(tiles: Dictionary) -> void:
	var territory: TerritoryState = TerritoryState.new()
	for hex in tiles:
		territory.set_owner(hex, 2)
	var economy: EconomyState = EconomyState.new(10000)
	economy.faction = 2
	economy.add_building(Vector2i(0, 0), "headquarters")
	economy.add_building(Vector2i(1, 0), "factory")
	economy.add_building(Vector2i(2, 0), "power_plant")
	economy.add_building(Vector2i(3, 0), "airfield")
	economy.add_building(Vector2i(4, 1), "shipyard")
	var roster: Array[UnitState] = [make("rifle", Vector2i.ZERO, 2), make("tank", Vector2i.ZERO, 2), make("gunner", Vector2i.ZERO, 2), make("rifle", Vector2i.ZERO, 2)]
	var enemy_air: UnitState = make("helicopter", Vector2i(8, 0), 1)
	roster.append(enemy_air)
	CombinedArmsAI.production(economy, tiles, territory, roster, {}, Vector2i.ZERO, Vector2i(8, 0))
	check(economy.buildings[Vector2i(1, 0)]["queue"] == ["anti_air"], "AI purchases anti-air against aircraft")
	var enemies: Dictionary = {Vector2i(8, 0): {"kind": "bunker"}}
	roster.pop_back()
	CombinedArmsAI.production(economy, tiles, territory, roster, enemies, Vector2i.ZERO, Vector2i(8, 0))
	check("artillery" in economy.buildings[Vector2i(1, 0)]["queue"], "AI purchases artillery for fortified targets")
	roster.append(make("artillery", Vector2i.ZERO, 2))
	CombinedArmsAI.production(economy, tiles, territory, roster, {}, Vector2i.ZERO, Vector2i(8, 0))
	check("helicopter" in economy.buildings[Vector2i(3, 0)]["queue"], "AI purchases limited aircraft")
	var planner: CombinedArmsAI = CombinedArmsAI.new()
	var jet: UnitState = make("fighter", Vector2i.ZERO, 2)
	jet.airfield = Vector2i(3, 0)
	var enemy: UnitState = make("tank", Vector2i(8, 0), 1)
	roster.assign([jet, enemy])
	planner.command(jet, roster, economy, territory, tiles, {}, enemy.hex)
	check(jet.attack_order and jet.air_mission == "striking", "AI launches explicit fighter strike")
	check(economy.account.balance >= 0 and CreditsAccount.valid_snapshot(economy.account.snapshot()), "AI pays normal costs without overdrafts")
