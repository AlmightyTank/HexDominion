extends SceneTree

var passed: int = 0
var failed: int = 0

func check(value: bool, message: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error(message)

func unit(kind: String, hex: Vector2i, faction: int = 1) -> UnitState:
	var result: UnitState = UnitState.new(hex, UnitCatalog.TYPES[kind]["name"])
	result.configure_kind(kind)
	result.faction = faction
	return result

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var tiles: Dictionary = {}
	for x in range(7):
		tiles[Vector2i(x, 0)] = {"is_land": x not in [2, 3], "terrain": "ocean" if x in [2, 3] else "plains"}
	for faction in [1, 2]:
		var territory: TerritoryState = TerritoryState.new()
		for hex in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(4, 0), Vector2i(5, 0), Vector2i(6, 0)]:
			territory.set_owner(hex, faction)
		var economy: EconomyState = EconomyState.new(5000)
		economy.faction = faction
		economy.add_building(Vector2i.ZERO, "headquarters")
		check(economy.build(Vector2i(1, 0), "airfield", tiles, territory), "Paid airfield foundation")
		check(economy.credits == 4750 and not economy.train(Vector2i(1, 0), "fighter", territory), "Foundation costs 250 and cannot produce")
		economy.advance(12, tiles, territory)
		check(EconomyState.is_complete(economy.buildings[Vector2i(1, 0)]) and economy.power_balance(territory)["demand"] == 20, "Airfield completes with power demand")
		check(not economy.can_build(Vector2i(1, 0), "airfield", tiles, territory), "No overlap")
		check(not economy.can_build(Vector2i(2, 0), "airfield", tiles, territory), "No water construction")
		tiles[Vector2i(4, 0)]["terrain"] = "mountain"
		check(not economy.can_build(Vector2i(4, 0), "airfield", tiles, territory), "No mountain runway")
		tiles[Vector2i(4, 0)]["terrain"] = "plains"
		check(economy.set_rally(Vector2i(1, 0), Vector2i(3, 0), tiles, territory), "Airfield accepts water rally")
		check(economy.train(Vector2i(1, 0), "helicopter", territory) and economy.train(Vector2i(1, 0), "fighter", territory), "Airfield accepts both aircraft")
		economy.add_building(Vector2i(4, 0), "factory")
		check(not economy.train(Vector2i(4, 0), "fighter", territory) and not economy.train(Vector2i(1, 0), "tank", territory), "Factory and airfield roles restricted")
		check(economy.advance(30, tiles, territory).is_empty(), "Low power pauses existing aircraft queue")
		check(not economy.train(Vector2i(1, 0), "helicopter", territory), "Low power rejects new aircraft orders without debit")
		economy.add_building(Vector2i(5, 0), "power_plant")
		var recruits: Array[UnitState] = economy.advance(21, tiles, territory)
		check(recruits.size() == 2 and recruits[0].domain == "air" and recruits[1].airfield == Vector2i(1, 0), "Aircraft complete with assigned base")
		check(not recruits[0].path.is_empty() and recruits[1].path.is_empty(), "Helicopter rallies; fighter waits at base")
		var heli: UnitState = recruits[0]
		heli.advance(3, tiles)
		check(heli.hex == Vector2i(3, 0), "Helicopter crosses and hovers over water")
		check(not heli.order_move(tiles, Vector2i(99, 0)), "Off-map flight rejected")
		check(HexPathfinding.find_path(tiles, Vector2i.ZERO, Vector2i(6, 0), "tank").is_empty(), "Ground forces cannot cross water")
		territory.advance(5, tiles, recruits)
		check(territory.owner_at(Vector2i(3, 0)) == 0, "Aircraft cannot capture water or territory")
		var jet: UnitState = recruits[1]
		var target: UnitState = unit("tank", Vector2i(4, 0), 3 - faction)
		var roster: Array[UnitState] = [jet, target]
		var economies: Array[EconomyState] = [economy]
		check(UnitOrders.attack(jet, tiles, target.hex, target), "Ready fighter accepts strike")
		jet.advance(2, tiles)
		check(jet.path.is_empty() and HexMath.distance(jet.hex, target.hex) <= jet.attack_range, "Fighter flies into weapon range")
		CombatState.advance(20, roster, tiles)
		check(jet.shot_serial == 1 and target.health == 145 and jet.air_mission == "returning", "One strike only even with large delta")
		check(not UnitOrders.attack(jet, tiles, target.hex, target), "No repeated strike before rearming")
		AircraftRules.update(0, roster, tiles, economies, territory)
		jet.advance(3, tiles)
		AircraftRules.update(0, roster, tiles, economies, territory)
		check(jet.hex == jet.airfield and jet.air_mission == "rearming", "Return to assigned base then rearm")
		AircraftRules.update(7.9, roster, tiles, economies, territory)
		check(jet.air_mission == "rearming", "Mission cooldown not early")
		AircraftRules.update(0.1, roster, tiles, economies, territory)
		check(jet.air_mission == "ready", "Mission cooldown completes")
		check(UnitOrders.attack(jet, tiles, target.hex, target), "Rearmed jet can fly another strike")
		target.health = 0
		UnitOrders.update(roster, tiles, economies)
		AircraftRules.update(0, roster, tiles, economies, territory)
		check(not jet.attack_order and jet.air_mission in ["returning", "rearming"], "Lost target safely aborts to base")
		economy.damage_building(jet.airfield, 9999)
		AircraftRules.update(0, roster, tiles, economies, territory)
		check(jet.airfield == AircraftRules.NO_BASE and jet.air_mission == "orphaned", "Destroyed airfield leaves fighter airborne without invalid references")
		economy.add_building(Vector2i(6, 0), "airfield")
		AircraftRules.update(0, roster, tiles, economies, territory)
		AircraftRules.update(0, roster, tiles, economies, territory)
		check(jet.airfield == Vector2i(6, 0) and jet.air_mission == "returning", "Replacement base adopted and return routed")
		jet.advance(5, tiles)
		AircraftRules.update(0, roster, tiles, economies, territory)
		economy.buildings.erase(Vector2i(5, 0))
		var timer: float = jet.mission_remaining
		AircraftRules.update(20, roster, tiles, economies, territory)
		check(jet.air_mission == "rearming" and jet.mission_remaining == timer, "Low power pauses fighter rearming")
		economy.add_building(Vector2i(5, 0), "power_plant")
		territory.set_owner(jet.airfield, 3 - faction)
		AircraftRules.update(0, roster, tiles, economies, territory)
		check(jet.airfield == AircraftRules.NO_BASE and jet.air_mission == "orphaned", "Captured base is never used by its former faction")
		var aa: UnitState = unit("anti_air", Vector2i(1, 0), 3 - faction)
		heli.hex = Vector2i(3, 0)
		heli.path.clear()
		var air_roster: Array[UnitState] = [aa, heli]
		check(UnitOrders.attack(aa, tiles, heli.hex, heli), "AA explicitly targets aircraft over water")
		CombatState.advance(0.8, air_roster, tiles)
		check(heli.health == 110, "Anti-air volleys hit airborne targets without terrain cover")
		CombatState.advance(4, air_roster, tiles)
		check(not heli.is_alive(), "Aircraft can be destroyed")
		var tank: UnitState = unit("tank", Vector2i(3, 0), 3 - faction)
		check(not UnitCatalog.can_target(tank, jet), "Ground cannon cannot target aircraft")
		var independent: UnitState = unit("helicopter", Vector2i(4, 0), faction)
		var armor: UnitState = unit("tank", Vector2i(5, 0), 3 - faction)
		var helicopter_fight: Array[UnitState] = [independent, armor]
		CombatState.advance(0.8, helicopter_fight, tiles)
		check(armor.health == 226 and independent.health == 140, "Helicopter counters armor while ground cannon cannot return fire")
		var bombing: UnitState = unit("fighter", Vector2i(4, 0), faction)
		bombing.airfield = Vector2i(1, 0)
		var enemy_economy: EconomyState = EconomyState.new()
		enemy_economy.faction = 3 - faction
		enemy_economy.add_building(Vector2i(5, 0), "bunker")
		var strike_roster: Array[UnitState] = [bombing, armor]
		check(UnitOrders.attack(bombing, tiles, Vector2i(5, 0)), "Fighter accepts explicit structure strike")
		var unit_targets: Dictionary = CombatState.advance(0.5, strike_roster, tiles)
		var strike_economies: Array[EconomyState] = [enemy_economy]
		CombatState.attack_extractors(0.5, strike_roster, strike_economies, unit_targets, tiles)
		check(enemy_economy.buildings[Vector2i(5, 0)]["health"] == 295 and armor.health == 226, "Structure strike retains target despite nearby defender")
		var stationary: Array[UnitState] = [independent]
		territory.set_owner(independent.hex, 0)
		territory.advance(5, tiles, stationary)
		check(territory.owner_at(independent.hex) == 0, "Aircraft cannot capture neutral land")
		var mixed: Array[UnitState] = [independent, jet, tank]
		check(UnitVisuals.stacks(mixed).size() == 3, "Ground, helicopter and fighter stacks remain separate")
	await integration()
	print("Aircraft: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func integration() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.units.set_physics_process(false)
	var home: Vector2i = game.units.units[0].hex
	game.units.economy.add_building(home, "airfield")
	game.units.economy.credits = 1000
	game.units.units.clear()
	var jet: UnitState = unit("fighter", home)
	jet.airfield = home
	jet.air_mission = "rearming"
	jet.mission_remaining = 3.5
	var heli: UnitState = unit("helicopter", home)
	heli.airfield = home
	game.units.units.append(jet)
	game.units.units.append(heli)
	var water: Vector2i = home
	for hex in game.world_map.map_data["tiles"]:
		if not game.world_map.map_data["tiles"][hex]["is_land"]:
			water = hex
			break
	heli.order_move(game.world_map.map_data["tiles"], water)
	heli.advance(0.1, game.world_map.map_data["tiles"])
	var snapshot: Dictionary = MatchSave.capture(game.units, game.camera.position, game.camera.zoom, home)
	check(MatchSave.validate(snapshot, game.world_map.map_data["tiles"]), "Air path over water and mission snapshot validates")
	check(MatchSave.restore(game.units, snapshot), "Aircraft save restores")
	check(MatchSave.capture(game.units, game.camera.position, game.camera.zoom, home) == snapshot, "Aircraft exact save round trip")
	var broken: Dictionary = snapshot.duplicate(true)
	broken["units"][0]["mission_remaining"] = NAN
	check(not MatchSave.restore(game.units, broken), "Nonfinite mission timers rejected atomically")
	broken = snapshot.duplicate(true)
	broken["units"][0]["airfield"] = "invalid"
	check(not MatchSave.restore(game.units, broken), "Malformed base rejected")
	game.units.select_one(game.units.units[0])
	game._process(0)
	check(game.hud.build_buttons.has("airfield") and game.hud.train_buttons.has("fighter") and game.hud.train_buttons.has("helicopter"), "HUD exposes building and aircraft production")
	check(game.hud.stack_passengers.text.contains("rearming") and game.hud.stack_passengers.text.contains("3.5"), "Selected fighter status visible")
	for zoom in [0.45, 1.0, 2.3]:
		game.camera.zoom = Vector2.ONE * zoom
		var batches: Array[Dictionary] = game.units.visual_stacks()
		for batch in batches:
			var point: Vector2 = game.units.group_position(batch, batches, zoom)
			check(game.units.pick_faction(game.units.to_global(point), zoom, 1) != null, "Aircraft pickable at zoom %s" % zoom)
	game.free()
