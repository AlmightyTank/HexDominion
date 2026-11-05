extends RefCounted
class_name CombinedArmsAI
## Strategic decisions run on the existing one-second AI clock, not render frames.
var _shore_goal: Variant = null
var _shore_key: Array = []

static func production(economy: EconomyState, tiles: Dictionary, territory: TerritoryState, units: Array[UnitState], enemy_buildings: Dictionary, home: Vector2i, objective: Vector2i, difficulty: String = AIDifficulty.HARD) -> bool:
	var profile: Dictionary = AIDifficulty.profile(difficulty)
	if not profile["combined_arms"]:
		return false
	var counts: Dictionary = {}
	var total: int = 0
	var enemy_air: bool = false
	for unit in units:
		if unit.is_alive() and unit.faction == economy.faction:
			counts[unit.kind] = counts.get(unit.kind, 0) + 1
			total += 1
		elif unit.is_deployed() and unit.domain == "air":
			enemy_air = true
	for site in economy.buildings.values():
		for kind in site["queue"]:
			counts[kind] = counts.get(kind, 0) + 1
			total += 1
	if total >= int(profile["army_limit"]):
		return false
	var desired: String = ""
	if enemy_air and counts.get("anti_air", 0) == 0:
		desired = "anti_air"
	elif not enemy_buildings.is_empty() and counts.get("tank", 0) >= 1 and total >= 4 and counts.get("artillery", 0) == 0:
		desired = "artillery"
	elif profile["air_and_naval"] and total >= 5 and counts.get("helicopter", 0) == 0:
		desired = "helicopter"
	elif profile["air_and_naval"] and total >= 5 and counts.get("fighter", 0) == 0:
		desired = "fighter"
	var overseas: bool = HexPathfinding.find_path(tiles, home, objective).is_empty()
	if profile["air_and_naval"] and overseas and total >= 2:
		if counts.get("landing_transport", 0) == 0:
			desired = "landing_transport"
		elif counts.get("destroyer", 0) == 0:
			desired = "destroyer"
		elif counts.get("patrol_boat", 0) == 0:
			desired = "patrol_boat"
	if desired.is_empty():
		return false
	if UnitCatalog.is_air(desired) and economy.low_power(territory):
		RivalEconomyAI._build(economy, "power_plant", tiles, territory, enemy_buildings, home)
		return true
	var producer: String = UnitCatalog.producer(desired)
	var has_producer: bool = false
	for hex in economy.buildings:
		if economy.buildings[hex]["kind"] == producer and territory.owner_at(hex) == economy.faction:
			has_producer = true
			if economy.train(hex, desired, territory):
				return true
	if not has_producer:
		if producer == "airfield" and economy.low_power(territory):
			RivalEconomyAI._build(economy, "power_plant", tiles, territory, enemy_buildings, home)
		else:
			RivalEconomyAI._build(economy, producer, tiles, territory, enemy_buildings, home)
	# Save toward the chosen counter instead of spending the same credits on rifles.
	return true

func shoreline(tiles: Dictionary, start: Vector2i, objective: Vector2i) -> Variant:
	var key: Array = [start, objective, tiles.size()]
	if key == _shore_key:
		return _shore_goal
	_shore_key = key
	_shore_goal = null
	var land: Dictionary = {objective: true}
	var frontier: Array[Vector2i] = [objective]
	var index: int = 0
	while index < frontier.size():
		var hex: Vector2i = frontier[index]
		index += 1
		for neighbor in HexMath.neighbors(hex):
			if not land.has(neighbor) and HexPathfinding.is_walkable(tiles, neighbor):
				land[neighbor] = true
				frontier.append(neighbor)
	frontier.assign([start])
	var water: Dictionary = {start: true}
	index = 0
	while index < frontier.size():
		var hex: Vector2i = frontier[index]
		index += 1
		for neighbor in HexMath.neighbors(hex):
			if land.has(neighbor):
				_shore_goal = {"water": hex, "land": neighbor}
				return _shore_goal
			if not water.has(neighbor) and NavalRules.water(tiles, neighbor):
				water[neighbor] = true
				frontier.append(neighbor)
	return null

func command(unit: UnitState, roster: Array[UnitState], economy: EconomyState, territory: TerritoryState, tiles: Dictionary, enemy_buildings: Dictionary, objective: Vector2i) -> bool:
	if unit.domain == "air":
		if unit.kind == "fighter" and unit.air_mission != "ready":
			return true
		for enemy in roster:
			if enemy.faction != unit.faction and enemy.is_deployed() and UnitCatalog.can_target(unit, enemy):
				UnitOrders.attack(unit, tiles, enemy.hex, enemy)
				return true
		for hex in enemy_buildings:
			if UnitOrders.attack(unit, tiles, hex):
				return true
		return true
	if unit.domain == "naval":
		if not unit.path.is_empty():
			return true
		for enemy in roster:
			if enemy.faction != unit.faction and enemy.is_deployed() and UnitCatalog.can_target(unit, enemy) and HexMath.distance(unit.hex, enemy.hex) <= unit.attack_range:
				UnitOrders.attack(unit, tiles, enemy.hex, enemy)
				return true
		var shore: Variant = shoreline(tiles, unit.hex, objective)
		if shore == null:
			return true
		if unit.kind == "landing_transport":
			if TransportRules.used(unit, roster) == 0:
				for infantry in roster:
					if infantry.faction == unit.faction and infantry.is_deployed() and UnitCatalog.is_infantry(infantry.kind):
						if TransportRules.load(infantry, unit, roster, tiles):
							break
						for coast in HexMath.neighbors(unit.hex):
							if HexPathfinding.is_walkable(tiles, coast) and infantry.order_move(tiles, coast):
								return true
				return true
			if unit.hex == shore["water"]:
				TransportRules.unload(unit, shore["land"], tiles, roster)
			else:
				unit.order_move(tiles, shore["water"])
		elif unit.kind == "destroyer":
			for hex in enemy_buildings:
				if HexMath.distance(unit.hex, hex) <= unit.attack_range and UnitOrders.attack(unit, tiles, hex):
					return true
			UnitOrders.tactical(unit, "attack_move", shore["water"], tiles)
		else:
			UnitOrders.tactical(unit, "patrol", shore["water"], tiles)
		return true
	if unit.kind == "artillery":
		for hex in enemy_buildings:
			if enemy_buildings[hex]["kind"] in ["bunker", "headquarters"] and UnitOrders.attack(unit, tiles, hex):
				return true
	return false
