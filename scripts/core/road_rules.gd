extends RefCounted
class_name RoadRules

const COST: float = 100.0
const SPEED: float = 1.3

static func has_road(tiles: Dictionary, hex: Vector2i) -> bool:
	return tiles.has(hex) and supports(tiles[hex]) and tiles[hex].get("road", false) == true

static func neighbors(tiles: Dictionary, hex: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not has_road(tiles, hex):
		return result
	for neighbor in HexMath.neighbors(hex):
		if has_road(tiles, neighbor):
			result.append(neighbor)
	return result

static func connected(tiles: Dictionary, start: Vector2i, goal: Vector2i, territory: TerritoryState = null, faction: int = 0) -> bool:
	# Optional faction filtering is for supply networks, not road movement rights.
	if not has_road(tiles, start) or not has_road(tiles, goal):
		return false
	if faction != 0 and (territory == null or territory.owner_at(start) != faction or territory.is_contested(start)):
		return false
	var frontier: Array[Vector2i] = [start]
	var visited: Dictionary = {start: true}
	var index: int = 0
	while index < frontier.size():
		var current: Vector2i = frontier[index]
		index += 1
		if current == goal:
			return true
		for neighbor in neighbors(tiles, current):
			if visited.has(neighbor) or (faction != 0 and (territory.owner_at(neighbor) != faction or territory.is_contested(neighbor))):
				continue
			visited[neighbor] = true
			frontier.append(neighbor)
	return false

static func supports(tile: Dictionary) -> bool:
	return tile.get("is_land", false) and TerrainRules.ground(tile) in ["plains", "forest", "desert", "city"]

static func can_build(hex: Vector2i, tiles: Dictionary, territory: TerritoryState, economy: EconomyState) -> bool:
	return tiles.has(hex) and supports(tiles[hex]) and not tiles[hex].get("road", false) and territory.owner_at(hex) == economy.faction and not territory.is_contested(hex) and economy.account.can_afford(COST)

static func build(hex: Vector2i, tiles: Dictionary, territory: TerritoryState, economy: EconomyState) -> bool:
	if not can_build(hex, tiles, territory, economy) or not economy.account.try_spend(COST, "Road at %s" % hex):
		return false
	tiles[hex]["road"] = true
	return true

static func snapshot(tiles: Dictionary) -> Dictionary:
	var roads: Dictionary = {}
	for hex in tiles:
		if tiles[hex].get("road", false):
			roads[hex] = true
	return roads
