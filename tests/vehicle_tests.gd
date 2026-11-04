extends SceneTree

var passed: int = 0
var failed: int = 0

func check(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error(message)

func make_unit(kind: String, hex: Vector2i, faction: int = 1) -> UnitState:
	var unit: UnitState = UnitState.new(hex, kind)
	unit.configure_kind(kind)
	unit.faction = faction
	return unit

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var tiles: Dictionary = {}
	for x in range(6):
		tiles[Vector2i(x, 0)] = {"is_land": true, "terrain": "plains", "road": true}
	tiles[Vector2i(0, 1)] = {"is_land": false, "terrain": "ocean"}
	for faction in [1, 2]:
		var territory: TerritoryState = TerritoryState.new()
		for hex in tiles:
			if tiles[hex]["is_land"]:
				territory.set_owner(hex, faction)
		var economy: EconomyState = EconomyState.new(2000)
		economy.faction = faction
		economy.add_building(Vector2i.ZERO, "factory")
		for kind in ["tank", "scout", "apc", "anti_air"]:
			var before: float = economy.credits
			check(economy.train(Vector2i.ZERO, kind, territory), "%s factory production accepted" % kind)
			check(economy.credits == before - UnitCatalog.COSTS[kind], "Exact vehicle production cost")
			var recruits: Array[UnitState] = economy.advance(UnitCatalog.TRAIN_SECONDS[kind] * 2, tiles, territory)
			check(recruits.size() == 1 and recruits[0].kind == kind and recruits[0].faction == faction, "Timed vehicle production and faction")
			var unit: UnitState = make_unit(kind, Vector2i.ZERO, faction)
			check(unit.order_move(tiles, Vector2i(2, 0)), "Vehicle path uses existing road graph")
			unit.advance(unit.seconds_per_hex / RoadRules.SPEED, tiles)
			check(unit.hex == Vector2i(1, 0), "Each vehicle gets road speed bonus")
			check(not unit.order_move(tiles, Vector2i(0, 1)), "Vehicles reject ocean movement")
		var apc: UnitState = make_unit("apc", Vector2i.ZERO, faction)
		var roster: Array[UnitState] = [apc]
		for index in range(5):
			roster.append(make_unit(UnitCatalog.INFANTRY[index % 3], Vector2i.ZERO, faction))
		for index in range(1, 5):
			check(TransportRules.load(roster[index], apc, roster), "All infantry roles can board")
		check(not TransportRules.load(roster[5], apc, roster), "APC capacity four enforced")
		check(not TransportRules.load(roster[1], apc, roster), "Duplicate boarding rejected")
		check(not roster[1].order_move(tiles, Vector2i(1, 0)), "Passenger cannot move independently")
		check(UnitVisuals.groups(roster).size() == 2, "Passengers absent from presentation groups")
		var enemy: UnitState = make_unit("tank", Vector2i(1, 0), 3 - faction)
		roster.append(enemy)
		var hp: float = roster[1].health
		var targets: Dictionary = CombatState.advance(0.5, roster, tiles)
		check(not targets.has(roster[1]) and roster[1].health == hp, "Passengers neither fire nor take independent damage")
		var only_passengers: Array[UnitState] = [roster[1], roster[2], roster[3], roster[4]]
		var empty_territory: TerritoryState = TerritoryState.new()
		empty_territory.advance(10, tiles, only_passengers)
		check(empty_territory.owners.is_empty(), "Passengers cannot capture or contest")
		check(not TransportRules.unload(apc, Vector2i(0, 1), tiles, roster), "Ocean unloading rejected atomically")
		check(not TransportRules.unload(apc, Vector2i(3, 0), tiles, roster), "Distant unloading rejected")
		apc.order_move(tiles, Vector2i(1, 0))
		check(not TransportRules.unload(apc, Vector2i.ZERO, tiles, roster), "Moving carrier cannot unload")
		apc.advance(2, tiles)
		TransportRules.synchronize(roster)
		check(roster[1].hex == apc.hex, "Passenger position follows carrier")
		check(TransportRules.unload(apc, Vector2i(2, 0), tiles, roster), "Adjacent land unload succeeds")
		check(TransportRules.passengers(apc, roster).is_empty() and roster[1].hex == Vector2i(2, 0) and roster[1].holding, "Unload restores independent held infantry")
		check(not TransportRules.unload(apc, Vector2i(2, 0), tiles, roster), "Empty unload rejected")
		check(not TransportRules.load(enemy, apc, roster), "Enemy and vehicle boarding rejected")
		roster[1].hex = apc.hex
		check(TransportRules.load(roster[1], apc, roster), "Reboarding works")
		apc.health = 0
		TransportRules.synchronize(roster)
		check(not roster[1].is_alive(), "Carrier destruction kills passengers without duplicating units")
	var tank: UnitState = make_unit("tank", Vector2i.ZERO)
	var target: UnitState = make_unit("apc", Vector2i(0, 1), 2)
	target.damage = 0
	var fight: Array[UnitState] = [tank, target]
	CombatState.advance(0.5, fight)
	check(is_equal_approx(target.health, 166.25), "Tank anti-armor counter is stronger than anti-infantry")
	check(tank.facing == 0 and not is_zero_approx(tank.turret_facing), "Turret rotates independently from chassis")
	var aa: UnitState = make_unit("anti_air", Vector2i.ZERO)
	var ground: UnitState = make_unit("tank", Vector2i(1, 0), 2)
	var air: UnitState = make_unit("scout", Vector2i(2, 0), 2)
	air.domain = "air"
	ground.damage = 0
	air.damage = 0
	fight.assign([aa, ground, air])
	var targets: Dictionary = CombatState.advance(0.8, fight)
	check(targets.get(aa) == air and air.health == 70, "Anti-air automatically prioritizes valid aircraft with missile damage")
	check(not UnitOrders.attack(tank, tiles, air.hex, air), "Ground-only weapon rejects aircraft attack order")
	air.health = 0
	CombatState.advance(0.8, fight)
	check(is_equal_approx(ground.health, 248.5), "Anti-air is weak against heavy armor")
	await integration()
	print("Vehicle expansion: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func integration() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.units.set_physics_process(false)
	var home: Vector2i = game.units.units[0].hex
	var apc: UnitState = make_unit("apc", home)
	game.units.units.append(apc)
	var passenger: UnitState = game.units.units[0]
	game.units.select_one(passenger)
	game.hud.defensive_order_requested.emit("load")
	game.camera.restore_view(game.world_map.hex_to_world(home), Vector2.ONE * 2)
	# Use the shared map command handler used by mouse and touch.
	var stacks: Array[Dictionary] = UnitVisuals.stacks(game.units.units)
	game._transport_at(game.units.to_global(game.units.group_position(stacks[0], stacks, game.camera.zoom.x)))
	check(passenger.is_embarked() and game.units.selected == apc, "HUD load command boards infantry and selects APC")
	game._process(0)
	check(game.hud.selection_info.text.contains("Passengers: 1/4"), "APC selection reports actual passenger count")
	var snapshot: Dictionary = MatchSave.capture(game.units, game.camera.position, game.camera.zoom, home)
	check(MatchSave.validate(snapshot, game.world_map.map_data["tiles"]), "Transport snapshot validates")
	check(MatchSave.restore(game.units, snapshot), "Transport snapshot restores")
	check(game.units.units[0].is_embarked() and game.units.units[0].carrier.get_ref() == game.units.units[-1], "Restore reconnects carrier identity")
	check(MatchSave.capture(game.units, game.camera.position, game.camera.zoom, home) == snapshot, "Passenger and turret state roundtrip exactly")
	var bad: Dictionary = snapshot.duplicate(true)
	bad["units"][0]["carrier"] = 0
	check(not MatchSave.restore(game.units, bad), "Self or non-APC carrier rejected before mutation")
	bad = snapshot.duplicate(true)
	bad["units"][0]["carrier"] = 9999
	check(not MatchSave.restore(game.units, bad), "Out-of-range carrier index rejected")
	bad = snapshot.duplicate(true)
	bad["units"][0]["turret_facing"] = NAN
	check(not MatchSave.restore(game.units, bad), "Nonfinite turret rejected")
	bad = snapshot.duplicate(true)
	bad["units"][0]["path"] = [HexMath.neighbors(home)[0]]
	check(not MatchSave.restore(game.units, bad), "Passenger movement path rejected atomically")
	bad = snapshot.duplicate(true)
	bad["units"][0]["faction"] = 2
	check(not MatchSave.restore(game.units, bad), "Foreign passenger carrier rejected atomically")
	bad = snapshot.duplicate(true)
	for index in range(4):
		bad["units"].append(snapshot["units"][0].duplicate(true))
	check(not MatchSave.restore(game.units, bad), "Overcapacity snapshot rejected atomically")
	check(MatchSave.capture(game.units, game.camera.position, game.camera.zoom, home) == snapshot, "Malformed transport loads leave match untouched")
	game.units.select_one(game.units.units[-1])
	game.hud.defensive_order_requested.emit("unload")
	game._transport_at(game.world_map.hex_to_world(home))
	check(not game.units.units[0].is_embarked(), "HUD unload command restores deployed infantry")
	for kind in ["tank", "scout", "apc", "anti_air"]:
		for faction in [1, 2]:
			var unit: UnitState = make_unit(kind, home, faction)
			unit.turret_facing = 0.7
			game.units.units.append(unit)
	for unit in game.units.units:
		unit.hex = home
	var mixed: Array[Dictionary] = UnitVisuals.stacks(game.units.units)
	check(mixed.size() == 2 and mixed[0]["members"].size() > 1, "Mixed roles merge into one marker per faction and hex")
	var representative: String = mixed[0]["kind"]
	check(representative == "rifle", "Equal role counts resolve in stable catalog order")
	var majority: Array[UnitState] = [make_unit("rifle", home), make_unit("tank", home), make_unit("tank", home)]
	check(UnitVisuals.stacks(majority)[0]["kind"] == "tank", "Most numerous role supplies the shared stack icon")
	var reversed: Array[UnitState] = game.units.units.duplicate()
	reversed.reverse()
	for stack in UnitVisuals.stacks(reversed):
		if stack["faction"] == 1:
			check(stack["kind"] == representative, "Representative ties do not depend on roster order")
	game._select_at(game.units.to_global(game.units.group_position(mixed[0], mixed, game.camera.zoom.x)))
	game._process(0)
	check(game.hud.stack_panel.visible and game.hud.stack_rows["scout"].visible, "Stack click exposes mixed-role breakdown in existing panel")
	game.hud.stack_rows["scout"].pressed.emit()
	check(game.units.selected_units.size() == 1 and game.units.selected.kind == "scout", "Breakdown row selects that vehicle role only")
	game._process(0)
	check(game.hud.stack_rows["tank"].visible and game.hud.stack_rows["tank"].text.contains("x2"), "Filtering selection retains full hex composition and exact type counts")
	game.hud.stack_all.pressed.emit()
	check(game.units.selected_units.size() == mixed[0]["members"].size(), "Select all restores whole friendly hex stack")
	game.hud.stack_expand.pressed.emit()
	check(game.units.expanded_hex == home, "Expand reveals individual units only on request")
	game.hud.stack_expand.pressed.emit()
	check(game.units.expanded_hex != home, "Collapse returns to one marker")
	for zoom in [0.45, 1.0, 2.3]:
		game.camera.restore_view(game.world_map.hex_to_world(home), Vector2.ONE * zoom)
		var deployed: int = 0
		var batches: Array[Dictionary] = game.units.military_batches()
		for batch in batches:
			deployed += batch["members"].size()
			var point: Vector2 = game.units.group_position(batch, batches, zoom)
			var picked: UnitState = game.units.pick_faction(game.units.to_global(point), zoom, batch["faction"])
			check(picked != null and picked.faction == batch["faction"] and picked.hex == batch["hex"], "Mixed faction stacks pick at rendered zoom anchors")
		check(deployed == game.units.units.size(), "Zoom grouping preserves all independent vehicle and infantry states")
		game.units.select_box(Rect2(-100000, -100000, 200000, 200000), game.units.get_canvas_transform())
		var friendly: int = 0
		for unit in game.units.units:
			friendly += int(unit.faction == 1)
		check(game.units.selected_units.size() == friendly, "Mixed vehicle box selection excludes enemies at all zooms")
	snapshot = MatchSave.capture(game.units, game.camera.position, game.camera.zoom, home)
	check(MatchSave.restore(game.units, snapshot) and MatchSave.capture(game.units, game.camera.position, game.camera.zoom, home) == snapshot, "All vehicle IDs and independent turret states save and restore")
	for entry in snapshot["units"]:
		entry.erase("carrier")
		entry.erase("turret_facing")
	check(MatchSave.restore(game.units, snapshot), "Legacy snapshots without transport or turret fields remain compatible")
	var loaded: UnitState = game.units.units[0]
	var doomed: UnitState = game.units.units[-3]
	# Locate a player APC without depending on the expansion roster's insertion order.
	for candidate in game.units.units:
		if candidate.kind == "apc" and candidate.faction == 1:
			doomed = candidate
			break
	loaded.hex = doomed.hex
	check(TransportRules.load(loaded, doomed, game.units.units), "Cleanup fixture boards live infantry")
	doomed.health = 0
	game.units._physics_process(0.01)
	check(not game.units.units.has(loaded) and not game.units.units.has(doomed), "Live simulation removes destroyed carrier and cargo in one tick")
	check(MatchSave.validate(MatchSave.capture(game.units, game.camera.position, game.camera.zoom, home), game.world_map.map_data["tiles"]), "Post-destruction snapshot has no dangling cargo links")
	game.free()
