extends RefCounted
class_name RivalEconomyAI
## Stateless priorities are reconstructed from the saved economy and roster.

const ARMY_LIMIT: int = 8
const REPAIR_RESERVE: float = 200.0

static func plan(economy: EconomyState, tiles: Dictionary, territory: TerritoryState, units: Array[UnitState], other_buildings: Dictionary, home: Vector2i, objective: Vector2i = Vector2i(-99999, -99999), difficulty: String = AIDifficulty.HARD) -> void:
	var profile: Dictionary = AIDifficulty.profile(difficulty)
	var living: int = 0
	var tanks: int = 0
	var infantry: Dictionary = {"rifle": 0, "rocket": 0, "gunner": 0}
	var enemy_armor: bool = false
	for unit in units:
		if unit.faction != economy.faction and unit.is_alive() and unit.kind == "tank":
			enemy_armor = true
		if unit.faction == economy.faction and unit.is_alive():
			living += 1
			tanks += int(unit.kind == "tank")
			if UnitCatalog.is_infantry(unit.kind):
				infantry[unit.kind] += 1
	var queued: int = 0
	var counts: Dictionary = {}
	var supply: int = 0
	var demand: int = 0
	for hex in economy.buildings:
		if territory.owner_at(hex) != economy.faction:
			continue
		var site: Dictionary = economy.buildings[hex]
		var kind: String = site["kind"]
		counts[kind] = counts.get(kind, 0) + 1
		queued += site["queue"].size()
		for job in site["queue"]:
			tanks += int(job == "tank")
			if UnitCatalog.is_infantry(job):
				infantry[job] += 1
		if not territory.is_contested(hex):
			# Include paid foundations so a pending plant is not ordered repeatedly.
			supply += EconomyState.POWER_SUPPLY.get(kind, 0)
			demand += EconomyState.POWER_DEMAND.get(kind, 0)
		if EconomyState.is_complete(site):
			var repair: bool = economy.credits > REPAIR_RESERVE and site["health"] < EconomyState.BUILD_HEALTH[kind] and not territory.is_contested(hex)
			economy.set_repair(hex, territory, site, repair)
	# Re-establish command infrastructure first. Slice A provides no passive bailout.
	if counts.get("headquarters", 0) == 0 and _build(economy, "headquarters", tiles, territory, other_buildings, home):
		return
	# Recover recruitment using existing assets, never free credits or free buildings.
	if counts.get("barracks", 0) == 0 and _build(economy, "barracks", tiles, territory, other_buildings, home):
		return
	if living + queued == 0 and (economy.credits < EconomyState.TRAIN_COSTS["rifle"] or counts.get("barracks", 0) == 0):
		for hex in economy.buildings.keys():
			var site: Dictionary = economy.buildings[hex]
			if site["kind"] in ["factory", "extractor", "power_plant"] and economy.sell_building(hex, territory, site):
				return
	if counts.get("barracks", 0) == 0:
		return
	if counts.get("headquarters", 0) == 0 and economy.credits >= EconomyState.BUILD_COSTS["headquarters"]:
		if _build(economy, "headquarters", tiles, territory, other_buildings, home):
			return
	var needed_power: int = demand
	if needed_power > supply:
		# Power recovery has priority over optional spending, but not the last scout.
		if _build(economy, "power_plant", tiles, territory, other_buildings, home):
			return
	if living >= 3 and counts.get("factory", 0) == 0 and economy.credits >= EconomyState.BUILD_COSTS["factory"] + 50:
		if supply < demand + 20:
			if _build(economy, "power_plant", tiles, territory, other_buildings, home):
				return
		elif _build(economy, "factory", tiles, territory, other_buildings, home):
			return
	if living + queued >= int(profile["army_limit"]):
		return
	if objective != Vector2i(-99999, -99999) and CombinedArmsAI.production(economy, tiles, territory, units, other_buildings, home, objective, difficulty):
		return
	# Leave space in the roster for armor once a factory has been funded.
	var wants_tank: bool = counts.get("factory", 0) > 0 and tanks < 2 and living + queued >= 3
	var kind: String = "tank" if wants_tank else "rifle"
	if not wants_tank and living + queued >= 2:
		if enemy_armor and infantry["rocket"] == 0:
			kind = "rocket"
		elif infantry["rifle"] >= 2 and infantry["gunner"] == 0:
			kind = "gunner"
	var reserve: float = 150.0 if needed_power > supply and living + queued > 0 else 0.0
	if living + queued > 0:
		if counts.get("headquarters", 0) == 0:
			reserve = maxf(reserve, EconomyState.BUILD_COSTS["headquarters"])
		if living + queued >= 3 and counts.get("factory", 0) == 0:
			reserve = maxf(reserve, EconomyState.BUILD_COSTS["factory"] + 50)
	if economy.credits < EconomyState.TRAIN_COSTS[kind] + reserve:
		return
	for hex in economy.buildings:
		if economy.train(hex, kind, territory):
			break

static func _build(economy: EconomyState, kind: String, tiles: Dictionary, territory: TerritoryState, other_buildings: Dictionary, home: Vector2i) -> bool:
	var sites: Array[Vector2i] = []
	for hex in territory.owners:
		if economy.can_build(hex, kind, tiles, territory, other_buildings):
			sites.append(hex)
	sites.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		# Keep ordinary construction off valuable deposits while other sites exist.
		var a_resource: bool = tiles[a].get("terrain", "") == "resource"
		var b_resource: bool = tiles[b].get("terrain", "") == "resource"
		if kind != "extractor" and a_resource != b_resource:
			return not a_resource
		var da: int = HexMath.distance(a, home)
		var db: int = HexMath.distance(b, home)
		return da < db if da != db else (a.x < b.x if a.x != b.x else a.y < b.y))
	for hex in sites:
		if economy.build(hex, kind, tiles, territory, 0, other_buildings):
			return true
	return false

static func expansion_goal(start: Vector2i, home: Vector2i, tiles: Dictionary, territory: TerritoryState, economy: EconomyState) -> Vector2i:
	for hex in economy.buildings:
		if territory.owner_at(hex) != economy.faction and economy.buildings[hex]["kind"] in ["headquarters", "power_plant", "barracks"] and not HexPathfinding.find_path(tiles, start, hex).is_empty():
			return hex
	# One flood gives actual reachability and distances, including coast detours.
	var spare_sites: int = 0
	for hex in territory.owners:
		if territory.owner_at(hex) == economy.faction and HexPathfinding.is_walkable(tiles, hex) and not economy.buildings.has(hex) and tiles[hex].get("terrain", "") != "resource":
			spare_sites += 1
	var frontier: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var index: int = 0
	while index < frontier.size():
		var hex: Vector2i = frontier[index]
		index += 1
		var terrain: String = tiles[hex].get("terrain", "")
		if territory.owner_at(hex) != economy.faction and (terrain in ["city", "resource"] or economy.buildings.has(hex)):
			return hex
		# A small base needs spare construction sites even without nearby deposits.
		if spare_sites < 2 and territory.owner_at(hex) == 0 and HexMath.distance(hex, home) <= 3:
			return hex
		for neighbor in HexMath.neighbors(hex):
			if not visited.has(neighbor) and HexPathfinding.is_walkable(tiles, neighbor):
				visited[neighbor] = true
				frontier.append(neighbor)
	return start
