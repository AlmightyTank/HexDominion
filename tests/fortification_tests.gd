extends RefCounted

static func run(check: Callable) -> void:
	for faction in [1, 2]:
		var tiles: Dictionary = {}
		var territory: TerritoryState = TerritoryState.new()
		for x in range(5):
			var hex: Vector2i = Vector2i(x, 0)
			tiles[hex] = {"is_land": true, "terrain": "mountain" if x == 1 else "plains", "continent": "Test", "road": x != 1}
			territory.set_owner(hex, faction)
		territory.continents.configure(tiles, [Vector2i.ZERO], territory.owners)
		var economy: EconomyState = EconomyState.new(1000)
		economy.faction = faction
		economy.add_building(Vector2i.ZERO, "headquarters")
		var home: Vector2i = Vector2i(1, 0)
		check.call(economy.build(home, "bunker", tiles, territory), "Bunker builds on controlled mountain pass")
		check.call(not economy.build(home, "bunker", tiles, territory), "Bunker footprint cannot overlap")
		var squad: UnitState = UnitState.new(home)
		squad.faction = faction
		var units: Array[UnitState] = [squad]
		check.call(not FortificationRules.assign(squad, economy, territory, units), "Foundation cannot protect infantry")
		economy.advance(8, tiles, territory)
		check.call(FortificationRules.assign(squad, economy, territory, units) and squad.holding, "Completed bunker stations infantry and holds")
		var second: UnitState = UnitState.new(home)
		second.faction = faction
		var third: UnitState = UnitState.new(home)
		third.faction = faction
		units.append(second)
		units.append(third)
		check.call(FortificationRules.assign(second, economy, territory, units) and not FortificationRules.assign(third, economy, territory, units), "Two infantry maximum; third assignment rejected")
		third.garrisoned = true
		check.call(FortificationRules.protection(units, [economy], territory).size() == 2 and not third.garrisoned, "Injected excess garrison flags cannot bypass capacity")
		third.configure_kind("tank")
		check.call(not FortificationRules.assign(third, economy, territory, units), "Tanks cannot enter bunker garrison")
		var enemy: UnitState = UnitState.new(Vector2i(2, 0))
		enemy.faction = 3 - faction
		units.append(enemy)
		CombatState.advance(1, units, tiles, FortificationRules.protection(units, [economy], territory))
		check.call(is_equal_approx(squad.health, 91.0), "Mountain cover and bunker protection combine: 20 * .75 * .6")
		enemy.hex = Vector2i(4, 0)
		CombatState.advance(1, units, tiles)
		check.call(squad.hex == home and squad.path.is_empty() and squad.holding, "Holding unit does not pursue retreat beyond weapon range")
		check.call(squad.order_move(tiles, Vector2i.ZERO) and not squad.holding and not squad.garrisoned, "Valid movement cancels hold and leaves bunker")
		check.call(FortificationRules.assign(third, economy, territory, units) == false, "Armor remains ineligible after slot frees")
		squad.advance(3, tiles)
		squad.order_move(tiles, home)
		squad.advance(3, tiles)
		check.call(FortificationRules.assign(squad, economy, territory, units), "Infantry can return and re-enter freed slot")
		var site: Dictionary = economy.buildings[home]
		economy.damage_building(home, 100)
		check.call(economy.set_repair(home, territory, site, true), "Bunker uses paid repair system")
		economy.advance(1, tiles, territory)
		check.call(site["health"] == 320, "Bunker repairs restore health without exceeding maximum")
		check.call(economy.sell_building(home, territory, site), "Completed damaged bunker can be sold")
		check.call(FortificationRules.protection(units, [economy], territory).is_empty() and not squad.garrisoned and squad.holding, "Selling removes shelter and assignments but preserves hold order")
		economy.add_building(home, "bunker")
		FortificationRules.assign(squad, economy, territory, units)
		economy.damage_building(home, 10000)
		check.call(FortificationRules.protection(units, [economy], territory).is_empty(), "Destroyed bunker cannot protect occupants")
		economy.add_building(home, "bunker")
		FortificationRules.assign(squad, economy, territory, units)
		territory.set_owner(home, 3 - faction)
		check.call(FortificationRules.protection(units, [economy], territory).is_empty(), "Captured bunker stops protecting previous faction")
		territory.set_owner(home, faction)
		check.call(not HexPathfinding.find_path(tiles, Vector2i.ZERO, Vector2i(4, 0), "tank").is_empty(), "Bunker does not block terrain pathfinding")
		check.call(RoadRules.has_road(tiles, Vector2i(2, 0)) and is_equal_approx(territory.continents.bonus(faction), 0.1), "Fortification lifecycle preserves roads and continent ownership")
		economy.add_building(Vector2i(2, 0), "bunker")
		var army: Array[UnitState] = []
		for index in range(4):
			var unit: UnitState = UnitState.new(Vector2i.ZERO)
			unit.faction = faction
			army.append(unit)
		var reserved: Dictionary = DefenseAI.plan(economy, tiles, territory, army, {}, Vector2i.ZERO)
		check.call(reserved.size() == 2, "Defense AI reserves no more than half its army")
		var home_guard: bool = false
		for unit in reserved:
			home_guard = home_guard or (unit.hex == Vector2i.ZERO and unit.holding)
		check.call(home_guard, "AI retains a holding HQ guard instead of abandoning its whole base")
		for index in range(20):
			DefenseAI.plan(economy, tiles, territory, army, {}, Vector2i.ZERO)
		var bunker_count: int = 0
		for building in economy.buildings.values():
			bunker_count += int(building["kind"] == "bunker")
		check.call(bunker_count == 2, "AI does not build unlimited bunkers")
		var lone: Array[UnitState] = [army[0]]
		check.call(DefenseAI.plan(economy, tiles, territory, lone, {}, Vector2i.ZERO).is_empty(), "Last unit is free to expand rather than permanently defend")
		economy.buildings.erase(home)
		economy.buildings.erase(Vector2i(2, 0))
		economy.credits = 1000
		DefenseAI.plan(economy, tiles, territory, army, {}, Vector2i.ZERO)
		var founded: int = 0
		for building in economy.buildings.values():
			founded += int(building["kind"] == "bunker" and not EconomyState.is_complete(building))
		check.call(founded == 1 and economy.credits == 900, "AI constructs a paid timed bunker at a valuable defensive site")
		var weak: Dictionary = {Vector2i(4, 0): {}, Vector2i.ZERO: {}}
		check.call(DefenseAI.weak_target(Vector2i(3, 0), Vector2i.ZERO, weak, army, 3 - faction) == Vector2i(4, 0), "Raiding chooses a nearby lightly defended enemy site")
