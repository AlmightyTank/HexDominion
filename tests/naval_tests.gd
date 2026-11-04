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
	for x in range(8):
		tiles[Vector2i(x, 0)] = {"is_land": x in [0, 1, 6, 7], "terrain": "plains" if x in [0, 1, 6, 7] else "ocean"}
	for faction in [1, 2]:
		var territory: TerritoryState = TerritoryState.new()
		territory.set_owner(Vector2i.ZERO, faction)
		territory.set_owner(Vector2i(1, 0), faction)
		var economy: EconomyState = EconomyState.new(5000)
		economy.faction = faction
		check(not economy.can_build(Vector2i.ZERO, "shipyard", tiles, territory), "Inland shipyard rejected")
		check(not economy.can_build(Vector2i(2, 0), "shipyard", tiles, territory), "Water construction rejected")
		var before: float = economy.credits
		check(economy.build(Vector2i(1, 0), "shipyard", tiles, territory), "Owned coastal shipyard paid")
		check(economy.credits == before - 220 and not economy.train(Vector2i(1, 0), "patrol_boat", territory), "Foundation cannot train")
		economy.advance(10, tiles, territory)
		check(EconomyState.is_complete(economy.buildings[Vector2i(1, 0)]), "Shipyard construction completes")
		check(not economy.build(Vector2i(1, 0), "shipyard", tiles, territory), "Overlap rejected")
		for kind in ["patrol_boat", "destroyer", "landing_transport"]:
			before = economy.credits
			check(economy.train(Vector2i(1, 0), kind, territory), "Ship queue %s" % kind)
			check(economy.credits == before - UnitCatalog.COSTS[kind], "Ship costs exact")
			var recruits: Array[UnitState] = economy.advance(UnitCatalog.TRAIN_SECONDS[kind], tiles, territory)
			check(recruits.size() == 1 and recruits[0].kind == kind and recruits[0].hex == Vector2i(2, 0), "Ship deploys only in adjoining water")
			var ship: UnitState = recruits[0]
			check(ship.order_move(tiles, Vector2i(5, 0)) and not ship.order_move(tiles, Vector2i(6, 0)), "Ocean route and land rejection")
			ship.advance(100, tiles)
			check(ship.hex == Vector2i(5, 0), "Ship travels full ocean route")
		check(economy.set_rally(Vector2i(1, 0), Vector2i(5, 0), tiles, territory), "Reachable ocean rally accepted")
		check(not economy.set_rally(Vector2i(1, 0), Vector2i(6, 0), tiles, territory), "Land rally rejected")
		check(economy.train(Vector2i(1, 0), "patrol_boat", territory), "Paid queue before interruption")
		territory.set_owner(Vector2i(1, 0), 3 - faction)
		check(economy.advance(20, tiles, territory).is_empty(), "Captured shipyard pauses production")
		territory.set_owner(Vector2i(1, 0), faction)
		tiles[Vector2i(2, 0)]["navigable"] = false
		check(economy.advance(20, tiles, territory).is_empty(), "Blocked deployment pauses without losing queued ship")
		tiles[Vector2i(2, 0)].erase("navigable")
		check(economy.advance(5, tiles, territory).size() == 1, "Restored port produces once, no accumulated blocked time")
		check(HexPathfinding.find_path(tiles, Vector2i(1, 0), Vector2i(6, 0), "tank").is_empty(), "Ground cannot cross ocean")
		var ship: UnitState = unit("landing_transport", Vector2i(2, 0), faction)
		var infantry: UnitState = unit("rifle", Vector2i(1, 0), faction)
		var tank: UnitState = unit("tank", infantry.hex, faction)
		var apc: UnitState = unit("apc", infantry.hex, faction)
		var roster: Array[UnitState] = [ship, infantry, tank, apc]
		check(TransportRules.load(infantry, ship, roster, tiles) and TransportRules.load(tank, ship, roster, tiles), "Coastal infantry and vehicle boarding")
		check(infantry.hex == ship.hex and TransportRules.used(ship, roster) == 3, "Passengers synchronized and weighted capacity")
		var cargo_targets: Dictionary = CombatState.advance(10, roster, tiles)
		check(not cargo_targets.has(infantry) and not cargo_targets.has(tank), "Loaded army cannot fire")
		territory.advance(10, tiles, roster)
		check(territory.owner_at(ship.hex) == 0, "Ships and hidden cargo cannot capture ocean")
		check(not TransportRules.load(infantry, ship, roster, tiles), "No duplicate boarding")
		for i in range(5):
			var cargo: UnitState = unit("rifle", Vector2i(1, 0), faction)
			roster.append(cargo)
			check(TransportRules.load(cargo, ship, roster, tiles), "Remaining cargo slot accepted")
		check(TransportRules.used(ship, roster) == 8 and not TransportRules.load(apc, ship, roster, tiles), "Capacity enforced")
		check(not TransportRules.unload(ship, ship.hex, tiles, roster), "Cannot unload into water")
		check(not TransportRules.unload(ship, Vector2i(6, 0), tiles, roster), "Distant coast rejected")
		ship.order_move(tiles, Vector2i(5, 0))
		check(not TransportRules.unload(ship, Vector2i(1, 0), tiles, roster), "Moving ship cannot unload")
		ship.advance(10, tiles)
		TransportRules.synchronize(roster)
		check(infantry.hex == Vector2i(5, 0) and not infantry.order_move(tiles, Vector2i(6, 0)), "Cargo follows carrier and cannot act")
		var defender: UnitState = unit("rifle", Vector2i(6, 0), 3 - faction)
		roster.append(defender)
		check(not TransportRules.unload(ship, defender.hex, tiles, roster), "Defended landing rejected")
		defender.health = 0
		check(TransportRules.unload(ship, Vector2i(6, 0), tiles, roster), "Amphibious landing on other continent")
		check(infantry.is_deployed() and tank.is_deployed() and TransportRules.passengers(ship, roster).is_empty(), "All cargo released exactly once")
		check(not TransportRules.unload(ship, Vector2i(6, 0), tiles, roster), "Repeated unload does not duplicate")
		territory.advance(3, tiles, roster)
		check(territory.owner_at(Vector2i(6, 0)) == faction, "Deployed ground army captures beachhead")
		check(TransportRules.load(tank, ship, roster, tiles), "Vehicle reboards at new coast")
		ship.health = 0
		TransportRules.synchronize(roster)
		check(tank.health == 0, "Destroyed loaded carrier loses cargo consistently")
	var patrol: UnitState = unit("patrol_boat", Vector2i(2, 0))
	var target: UnitState = unit("landing_transport", Vector2i(3, 0), 2)
	var combat: Array[UnitState] = [patrol, target]
	CombatState.advance(0.5, combat, tiles)
	check(target.health == 262, "Patrol effective against light ships")
	var destroyer: UnitState = unit("destroyer", Vector2i(3, 0))
	var ground: UnitState = unit("tank", Vector2i(6, 0), 2)
	combat = [destroyer, ground]
	check(UnitOrders.attack(destroyer, tiles, ground.hex, ground), "Destroyer coastal bombardment order")
	CombatState.advance(1.5, combat, tiles)
	check(ground.health == 190, "Destroyer damages ground in range")
	check(not UnitOrders.attack(target, tiles, ground.hex, ground) and not UnitCatalog.can_target(patrol, ground), "Transport unarmed and patrol naval-only")
	var enemy: EconomyState = EconomyState.new()
	enemy.faction = 2
	enemy.add_building(Vector2i(6, 0), "bunker")
	check(UnitOrders.attack(destroyer, tiles, Vector2i(6, 0)), "Destroyer building bombardment")
	CombatState.attack_extractors(1.5, [destroyer], [enemy], {}, tiles)
	check(enemy.buildings[Vector2i(6, 0)]["health"] == 360, "Building bombardment damage")
	await integration()
	print("Naval regressions: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)

func integration() -> void:
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	scene.units.set_physics_process(false)
	var tiles: Dictionary = scene.world_map.map_data["tiles"]
	var coast: Vector2i
	var sea: Vector2i
	for hex in tiles:
		var port: Variant = NavalRules.deployment(tiles, hex)
		if port != null and not scene.units.economy.buildings.has(hex) and not scene.units.match_state.rival_economy.buildings.has(hex):
			coast = hex
			sea = port
			break
	scene.units.territory.set_owner(coast, 1)
	scene.units.economy.add_building(coast, "shipyard")
	var ship: UnitState = unit("landing_transport", sea)
	var cargo: UnitState = unit("tank", coast)
	scene.units.units.append_array([ship, cargo])
	check(TransportRules.load(cargo, ship, scene.units.units, tiles), "Real map transport loading")
	var snapshot: Dictionary = MatchSave.capture(scene.units, scene.camera.position, scene.camera.zoom, coast)
	check(MatchSave.validate(snapshot, tiles), "Naval snapshot validates loaded ground over ocean")
	check(MatchSave.restore(scene.units, snapshot), "Naval state restores")
	check(MatchSave.capture(scene.units, scene.camera.position, scene.camera.zoom, coast) == snapshot, "Exact snapshot round trip")
	var malformed: Dictionary = snapshot.duplicate(true)
	malformed["units"][-2]["hex"] = coast
	check(not MatchSave.validate(malformed, tiles), "Ship on land rejected")
	malformed = snapshot.duplicate(true)
	malformed["units"][-1]["carrier"] = malformed["units"].size() - 1
	check(not MatchSave.validate(malformed, tiles), "Self carrier rejected atomically")
	malformed = snapshot.duplicate(true)
	malformed["units"][-1]["faction"] = 2
	check(not MatchSave.validate(malformed, tiles), "Foreign passenger rejected")
	malformed = snapshot.duplicate(true)
	for i in range(4):
		malformed["units"].append(snapshot["units"][-1].duplicate(true))
	check(not MatchSave.validate(malformed, tiles), "Over-capacity loaded vehicle save rejected")
	check(MatchSave.capture(scene.units, scene.camera.position, scene.camera.zoom, coast) == snapshot, "Invalid snapshots leave simulation untouched")
	check(scene.hud.build_buttons.has("shipyard") and scene.hud.train_buttons.has("destroyer"), "Shipyard and roster production controls wired")
	scene.queue_free()
	await process_frame
