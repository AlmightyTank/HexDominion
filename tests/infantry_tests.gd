extends RefCounted

static func _unit(kind: String, hex: Vector2i = Vector2i.ZERO, faction: int = 1) -> UnitState:
	var unit: UnitState = UnitState.new(hex, kind)
	unit.configure_kind(kind)
	unit.faction = faction
	return unit

static func run(check: Callable) -> void:
	var tiles: Dictionary = {}
	for x in range(7):
		tiles[Vector2i(x, 0)] = {"is_land": true, "terrain": "plains"}
	for faction in [1, 2]:
		for kind in UnitCatalog.INFANTRY:
			var unit: UnitState = _unit(kind, Vector2i.ZERO, faction)
			var config: Dictionary = UnitCatalog.TYPES[kind]
			check.call(unit.health == config["health"] and unit.seconds_per_hex == config["speed"] and unit.damage == config["damage"] and unit.cooldown == config["cooldown"] and unit.attack_range == config["range"], "%s faction %d uses configured stats" % [kind, faction])
			var economy: EconomyState = EconomyState.new(1000)
			economy.faction = faction
			var territory: TerritoryState = TerritoryState.new()
			territory.set_owner(Vector2i.ZERO, faction)
			economy.add_building(Vector2i.ZERO, "barracks")
			check.call(economy.train(Vector2i.ZERO, kind, territory) and economy.credits == 1000 - UnitCatalog.COSTS[kind], "%s charges normal barracks price" % kind)
			var early: Array[UnitState] = economy.advance(UnitCatalog.TRAIN_SECONDS[kind] - 0.01, tiles, territory)
			var recruits: Array[UnitState] = economy.advance(0.02, tiles, territory)
			check.call(early.is_empty() and recruits.size() == 1 and recruits[0].kind == kind and recruits[0].faction == faction and recruits[0].health == config["health"], "%s completes exactly one configured recruit" % kind)
			economy.add_building(Vector2i(1, 0), "factory")
			territory.set_owner(Vector2i(1, 0), faction)
			check.call(not economy.train(Vector2i(1, 0), kind, territory), "Factory cannot produce %s" % kind)
			unit.order_move(tiles, Vector2i(1, 0))
			unit.advance(unit.seconds_per_hex * 0.5, tiles)
			check.call(unit.hex == Vector2i.ZERO and is_equal_approx(unit.progress, 0.5), "%s moves at configured speed" % kind)
			unit.advance(unit.seconds_per_hex, tiles)
			check.call(unit.hex == Vector2i(1, 0) and unit.path.is_empty(), "%s arrives normally" % kind)
			check.call(TerrainRules.defense_multiplier({"terrain": "forest"}, kind, true) == 0.85 and TerrainRules.defense_multiplier({"terrain": "mountain"}, kind, true) == 0.75, "%s receives infantry terrain cover" % kind)
			tiles[Vector2i(1, 0)]["road"] = true
			tiles[Vector2i.ZERO]["road"] = true
			check.call(is_equal_approx(TerrainRules.movement_cost(tiles, Vector2i.ZERO, Vector2i(1, 0), kind), 1 / RoadRules.SPEED), "%s uses shared road movement" % kind)
			tiles[Vector2i(1, 0)].erase("road")
			tiles[Vector2i.ZERO].erase("road")
			economy.add_building(Vector2i(1, 0), "bunker")
			check.call(FortificationRules.assign(unit, economy, territory, [unit]) and unit.garrisoned and unit.holding, "%s can defend a bunker" % kind)
			check.call(unit.order_move(tiles, Vector2i(2, 0)) and not unit.garrisoned and not unit.holding, "%s movement releases bunker and hold" % kind)
			unit.advance(10, tiles)
			territory.advance(TerritoryState.CAPTURE_SECONDS, tiles, [unit])
			check.call(territory.owner_at(Vector2i(2, 0)) == faction, "%s captures territory for its faction" % kind)
		for kind in UnitCatalog.INFANTRY:
			for target_kind in ["rifle", "tank"]:
				var attacker: UnitState = _unit(kind, Vector2i.ZERO, faction)
				var target: UnitState = _unit(target_kind, Vector2i(1, 0), 3 - faction)
				target.damage = 0
				var roster: Array[UnitState] = [attacker, target]
				CombatState.advance(attacker.cooldown - 0.01, roster, tiles)
				check.call(target.health == target.max_health, "%s cannot fire early" % kind)
				CombatState.advance(0.01, roster, tiles)
				var expected: float = attacker.damage * UnitCatalog.counter(kind, target_kind)
				check.call(is_equal_approx(target.health, target.max_health - expected) and attacker.shot_serial == 1, "%s counter against %s fires once per cooldown" % [kind, target_kind])
				check.call(attacker.attack_flash > 0 and target.damage_flash > 0, "Attack and damage feedback receives combat events")
				attacker.order_move(tiles, Vector2i(2, 0))
				var before: float = target.health
				CombatState.advance(3, roster, tiles)
				check.call(target.health == before, "%s cannot fire while moving" % kind)
	var rocket: UnitState = _unit("rocket")
	var rifle: UnitState = _unit("rifle")
	var gunner: UnitState = _unit("gunner")
	check.call(rocket.damage_per_second * UnitCatalog.counter("rocket", "tank") > rifle.damage_per_second and rocket.damage_per_second * UnitCatalog.counter("rocket", "rifle") < rifle.damage_per_second, "Rocket is strong against armor and poor against infantry")
	check.call(gunner.damage_per_second > rifle.damage_per_second and gunner.damage_per_second * UnitCatalog.counter("gunner", "tank") < rifle.damage_per_second and rocket.cooldown > gunner.cooldown and rocket.cooldown > rifle.cooldown, "Gunner counters infantry; rockets have slowest firing cycle")
	var enemy: UnitState = _unit("tank", Vector2i(5, 0), 2)
	var roster: Array[UnitState] = [rocket, rifle, gunner, enemy]
	check.call(UnitOrders.attack(rocket, tiles, enemy.hex, enemy) and rocket.path[-1] == Vector2i(3, 0), "Attack pursuit stops at role weapon range")
	UnitOrders.update(roster, tiles, [])
	rocket.advance(10, tiles)
	UnitOrders.update(roster, tiles, [])
	check.call(rocket.path.is_empty() and rocket.hex == Vector2i(3, 0), "Attack pursues without overlapping the target")
	enemy.hex = Vector2i(6, 0)
	UnitOrders.update(roster, tiles, [])
	check.call(not rocket.path.is_empty(), "Attack follows a moving target")
	rocket.order_hold()
	UnitOrders.update(roster, tiles, [])
	check.call(rocket.holding and not rocket.attack_order and rocket.path.is_empty(), "Hold cancels pursuit without disabling automatic fire")
	check.call(not UnitOrders.attack(rocket, tiles, rifle.hex, rifle), "Friendly attack order rejected")
	UnitOrders.attack(rocket, tiles, enemy.hex, enemy)
	enemy.health = 0
	UnitOrders.update(roster, tiles, [])
	check.call(not rocket.attack_order and rocket.holding, "Dead target safely ends pursuit")
	for kind in UnitCatalog.INFANTRY:
		var whole: UnitState = _unit(kind)
		var split: UnitState = _unit(kind)
		var a: UnitState = _unit("tank", Vector2i(1, 0), 2)
		var b: UnitState = _unit("tank", Vector2i(1, 0), 2)
		a.damage = 0
		b.damage = 0
		CombatState.advance(2, [whole, a], tiles)
		for tick in range(200):
			CombatState.advance(0.01, [split, b], tiles)
		check.call(is_equal_approx(a.health, b.health) and is_equal_approx(whole.weapon_elapsed, split.weapon_elapsed), "%s cooldown damage is tick partition independent" % kind)
	_visual_groups(check)

static func _visual_groups(check: Callable) -> void:
	var roster: Array[UnitState] = []
	for faction in [1, 2]:
		for kind in UnitCatalog.INFANTRY:
			for index in range(3):
				roster.append(_unit(kind, Vector2i.ZERO, faction))
	var before: Array = []
	for unit in roster:
		before.append([unit.kind, unit.hex, unit.health, unit.faction])
	for zoom_factor in [0.3, 1.0, 2.3]:
		var batches: Array[Dictionary] = UnitVisuals.groups(roster)
		var count: int = 0
		for batch in batches:
			count += batch["members"].size()
			check.call(batch["members"].size() == 3, "Same-hex groups remain type- and faction-specific at zoom %.1f" % zoom_factor)
		check.call(batches.size() == 6 and count == 18 and UnitVisuals.tier(zoom_factor) in ["far", "medium", "close"], "Zoom presentation never changes actual roster counts")
	var after: Array = []
	for unit in roster:
		after.append([unit.kind, unit.hex, unit.health, unit.faction])
	check.call(before == after, "Visual batching cannot mutate simulation state")
	check.call(UnitVisuals.offset(roster[0], roster) != UnitVisuals.offset(roster[1], roster), "Close soldiers sharing a hex have separate pickable positions")
