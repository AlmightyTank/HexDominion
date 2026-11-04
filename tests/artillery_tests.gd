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
		tiles[Vector2i(x, 0)] = {"is_land": true, "terrain": "plains"}
	for faction in [1, 2]:
		var territory: TerritoryState = TerritoryState.new()
		territory.set_owner(Vector2i.ZERO, faction)
		var economy: EconomyState = EconomyState.new(1000)
		economy.faction = faction
		economy.add_building(Vector2i.ZERO, "factory")
		check(economy.train(Vector2i.ZERO, "artillery", territory), "Factory accepts artillery")
		check(economy.credits == 800, "Artillery exact configurable cost")
		economy.add_building(Vector2i(1, 0), "barracks")
		territory.set_owner(Vector2i(1, 0), faction)
		check(not economy.train(Vector2i(1, 0), "artillery", territory), "Infantry barracks rejects artillery")
		check(economy.advance(9, tiles, territory).is_empty(), "No early production")
		var recruits: Array[UnitState] = economy.advance(11, tiles, territory)
		check(recruits.size() == 1 and recruits[0].kind == "artillery" and recruits[0].faction == faction, "Low-power factory completes artillery after twenty seconds")
		var gun: UnitState = make_unit("artillery", Vector2i.ZERO, faction)
		var enemy: UnitState = make_unit("tank", Vector2i(3, 0), 3 - faction)
		var roster: Array[UnitState] = [gun, enemy]
		check(gun.attack_range == 3 and gun.seconds_per_hex > enemy.seconds_per_hex and gun.max_health < enemy.max_health, "Long range, slow and vulnerable")
		CombatState.advance(2.9, roster, tiles)
		check(enemy.health == 250, "Cooldown enforced before first shell")
		CombatState.advance(0.1, roster, tiles)
		check(enemy.health == 227.5 and gun.shot_serial == 1, "One volley exactly at cooldown")
		enemy.hex = Vector2i(4, 0)
		CombatState.advance(9, roster, tiles)
		check(enemy.health == 227.5 and gun.shot_serial == 1, "Out of range cannot fire or bank time")
		enemy.hex = Vector2i(3, 0)
		tiles[enemy.hex]["terrain"] = "mountain"
		CombatState.advance(3, roster, tiles, {enemy: 0.6})
		check(is_equal_approx(enemy.health, 217.375), "Armor, terrain and bunker protection preserved")
		tiles[enemy.hex]["terrain"] = "plains"
		var friendly: UnitState = make_unit("rifle", Vector2i(1, 0), faction)
		check(not UnitOrders.attack(gun, tiles, friendly.hex, friendly), "Friendly explicit target rejected")
		var friends: Array[UnitState] = [gun, friendly]
		CombatState.advance(30, friends, tiles)
		check(friendly.health == 100, "No automatic friendly fire")
		var target_economy: EconomyState = EconomyState.new()
		target_economy.faction = 3 - faction
		target_economy.add_building(Vector2i(3, 0), "bunker")
		var economies: Array[EconomyState] = [target_economy]
		var guns: Array[UnitState] = [gun]
		gun.weapon_elapsed = 0
		UnitOrders.attack(gun, tiles, Vector2i(3, 0))
		var priorities: Dictionary = CombatState.advance(3, roster, tiles)
		check(not priorities.has(gun), "Explicit structure bombardment is not diverted by defending units")
		CombatState.attack_extractors(3, guns, economies, priorities, tiles)
		check(target_economy.buildings[Vector2i(3, 0)]["health"] == 265, "Bunker takes enhanced structure damage")
		CombatState.attack_extractors(6, guns, economies, {}, tiles)
		check(target_economy.buildings.is_empty(), "Fortification destroyed by three shells")
		check(UnitOrders.attack(gun, tiles, Vector2i(3, 0)), "Existing attack order accepts building hex")
		UnitOrders.update(guns, tiles, economies)
		check(not gun.attack_order and gun.holding, "Destroyed building releases pursuit")
		check(UnitOrders.attack(gun, tiles, enemy.hex, enemy), "Attack a deployed unit")
		enemy.health = 0
		UnitOrders.update(roster, tiles, economies)
		check(not gun.attack_order, "Destroyed unit releases pursuit")
		gun.hex = Vector2i(2, 0)
		territory.advance(10, tiles, guns)
		check(territory.owner_at(gun.hex) == 0 and territory.captures.is_empty(), "Artillery cannot capture its occupied hex")
		check(gun.order_move(tiles, Vector2i(4, 0)), "Move uses existing terrain pathfinder")
		gun.advance(0.475, tiles)
		check(gun.hex == Vector2i(2, 0) and is_equal_approx(gun.progress, 0.5), "Slow movement interpolates normally")
		gun.order_hold()
		check(gun.holding and gun.path.is_empty(), "Hold stops artillery")
		gun.hex = Vector2i.ZERO
		var island: Dictionary = {Vector2i.ZERO: tiles[Vector2i.ZERO], Vector2i(3, 0): tiles[Vector2i(3, 0)]}
		check(UnitOrders.attack(gun, island, Vector2i(3, 0)), "Indirect order does not require a traversable direct-fire corridor")
		check(gun.path.is_empty(), "In-range bombardment does not drive onto target")
		for distance in range(5):
			var ranged_gun: UnitState = make_unit("artillery", Vector2i.ZERO, faction)
			var ranged_target: UnitState = make_unit("tank", Vector2i(distance, 0), 3 - faction)
			var ranged_roster: Array[UnitState] = [ranged_gun, ranged_target]
			CombatState.advance(3, ranged_roster, tiles)
			check((ranged_target.health < 250) == (distance <= 3), "Exact hex range boundary %d" % distance)
		var stepped: UnitState = make_unit("artillery", Vector2i.ZERO, faction)
		var single: UnitState = make_unit("artillery", Vector2i.ZERO, faction)
		var stepped_target: UnitState = make_unit("tank", Vector2i(3, 0), 3 - faction)
		var single_target: UnitState = make_unit("tank", Vector2i(3, 0), 3 - faction)
		var stepped_roster: Array[UnitState] = [stepped, stepped_target]
		var single_roster: Array[UnitState] = [single, single_target]
		for tick in range(60):
			CombatState.advance(0.1, stepped_roster, tiles)
		CombatState.advance(6, single_roster, tiles)
		check(stepped_target.health == single_target.health and stepped.shot_serial == single.shot_serial, "Cooldown partition does not change shell damage")
		stepped.order_move(tiles, Vector2i(1, 0))
		var before_shots: int = stepped.shot_serial
		CombatState.advance(3, stepped_roster, tiles)
		check(stepped.shot_serial == before_shots, "Moving artillery cannot fire")
		for kind in ["rifle", "tank"]:
			var close_gun: UnitState = make_unit("artillery", Vector2i.ZERO, faction)
			var assault: UnitState = make_unit(kind, Vector2i(1, 0), 3 - faction)
			var melee: Array[UnitState] = [close_gun, assault]
			CombatState.advance(1, melee, tiles)
			check(close_gun.health < close_gun.max_health and assault.health == assault.max_health, "Nearby %s damages slow-firing artillery" % kind)
	await integration()
	print("Artillery: %d passed, %d failed" % [passed, failed])
	quit(1 if failed else 0)

func integration() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.units.set_physics_process(false)
	var home: Vector2i = game.units.units[0].hex
	var gun: UnitState = make_unit("artillery", home)
	gun.weapon_elapsed = 2.4
	gun.turret_facing = 1.1
	game.units.units.append(gun)
	game.units.select_one(gun)
	game._process(0)
	check(game.hud.train_buttons.has("artillery"), "Artillery factory control exists")
	game.units.economy.add_building(game.units.units[1].hex, "factory")
	game.units.economy.buildings[game.units.units[1].hex]["queue"] = ["artillery"]
	game.units.economy.buildings[game.units.units[1].hex]["elapsed"] = 9.0
	var snapshot: Dictionary = MatchSave.capture(game.units, game.camera.position, game.camera.zoom, home)
	var tiles: Dictionary = game.world_map.map_data["tiles"]
	check(MatchSave.validate(snapshot, tiles), "Ten-second production queue can save after eight seconds")
	check(MatchSave.restore(game.units, snapshot), "Artillery roster and production restore")
	check(MatchSave.capture(game.units, game.camera.position, game.camera.zoom, home) == snapshot, "Exact simulation snapshot roundtrip")
	game.units.shell_effects.append({"from": Vector2.ZERO, "to": Vector2.ONE, "age": 0.3})
	MatchSave.restore(game.units, snapshot)
	check(game.units.shell_effects.is_empty(), "Loading clears transient shells without applying damage twice")
	game.free()
