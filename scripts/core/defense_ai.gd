extends RefCounted
class_name DefenseAI
## At most half the army (and two infantry) defend; the remainder keep expanding.
static func plan(economy: EconomyState, tiles: Dictionary, territory: TerritoryState, units: Array[UnitState], other: Dictionary, home: Vector2i) -> Dictionary:
	var army: Array[UnitState] = []
	for unit in units:
		if unit.faction == economy.faction and unit.is_alive():
			army.append(unit)
	var sites: Array[Vector2i] = []
	if territory.owner_at(home) == economy.faction:
		sites.append(home)
	for hex in economy.buildings:
		if territory.owner_at(hex) == economy.faction and economy.buildings[hex]["kind"] in ["bunker", "extractor"] and not sites.has(hex):
			if economy.buildings[hex]["kind"] == "bunker":
				sites.push_front(hex)
			else:
				sites.append(hex)
	for hex in territory.owners:
		if territory.owner_at(hex) == economy.faction and (tiles.get(hex, {}).get("terrain", "") == "city" or RoadRules.has_road(tiles, hex)) and not sites.has(hex):
			sites.append(hex)
	var priorities: Dictionary = {}
	for hex in sites:
		var kind: String = economy.buildings.get(hex, {}).get("kind", "")
		var score: int = 1000 if hex == home else (100 if kind == "bunker" else (80 if kind == "extractor" else (60 if tiles[hex].get("terrain", "") == "city" else 40)))
		for enemy in units:
			if enemy.is_alive() and enemy.faction != economy.faction and HexMath.distance(enemy.hex, hex) <= 3:
				score += 200
		priorities[hex] = score
	sites.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a == home or b == home:
			return a == home and b != home
		return priorities[a] > priorities[b])
	var bunkers: int = 0
	for site in economy.buildings.values():
		bunkers += int(site["kind"] == "bunker")
	if army.size() >= 3 and bunkers < 2 and economy.credits >= 350:
		var candidates: Array[Vector2i] = sites.duplicate()
		for neighbor in HexMath.neighbors(home):
			if not candidates.has(neighbor):
				candidates.append(neighbor)
		for hex in candidates:
			if economy.build(hex, "bunker", tiles, territory, 0, other):
				break
	var reserved: Dictionary = {}
	var limit: int = mini(2, army.size() / 2)
	for hex in sites:
		if reserved.size() >= limit:
			break
		var defender: UnitState = null
		var distance: int = 2147483647
		for unit in army:
			if UnitCatalog.is_infantry(unit.kind) and not reserved.has(unit) and HexMath.distance(unit.hex, hex) < distance and not HexPathfinding.find_path(tiles, unit.hex, hex).is_empty():
				defender = unit
				distance = HexMath.distance(unit.hex, hex)
		if defender == null:
			continue
		reserved[defender] = true
		if defender.hex == hex and defender.path.is_empty():
			defender.order_hold()
			FortificationRules.assign(defender, economy, territory, units)
		elif defender.path.is_empty() or defender.path[-1] != hex:
			defender.order_move(tiles, hex)
	return reserved

static func weak_target(start: Vector2i, fallback: Vector2i, buildings: Dictionary, units: Array[UnitState], faction: int) -> Vector2i:
	var goal: Vector2i = fallback
	var best: int = 2147483647
	for hex in buildings:
		var guards: int = 0
		for unit in units:
			if unit.is_alive() and unit.faction != faction and HexMath.distance(unit.hex, hex) <= 1:
				guards += 1
		var distance: int = HexMath.distance(start, hex)
		if guards <= 1 and distance < best:
			best = distance
			goal = hex
	return goal
