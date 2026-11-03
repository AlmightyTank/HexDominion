extends RefCounted
class_name TerrainRules
## Costs multiply seconds per hex. No land terrain is a hard movement barrier.

const INFANTRY_COST: Dictionary = {"mountain": 1.0 / 0.8}
const ARMOR_COST: Dictionary = {"mountain": 1.0 / 0.8, "desert": 1.0 / 1.1}
const DEFENSE: Dictionary = {"mountain": 0.75, "city": 0.8}

static func ground(tile: Dictionary) -> String:
	var terrain: String = tile.get("terrain", "plains")
	return tile.get("biome", "plains") if terrain == "resource" else terrain

static func movement_cost(tiles: Dictionary, from: Vector2i, to: Vector2i, kind: String = "rifle") -> float:
	if not HexPathfinding.is_walkable(tiles, from) or not HexPathfinding.is_walkable(tiles, to) or HexMath.distance(from, to) != 1:
		return INF
	var costs: Dictionary = INFANTRY_COST if UnitCatalog.is_infantry(kind) else ARMOR_COST
	var cost: float = costs.get(ground(tiles[to]), 1.0)
	if crosses_river(tiles, from, to):
		cost += 0.6 if UnitCatalog.is_infantry(kind) else 1.0
	if tiles[from].get("narrow_crossing", false) or tiles[to].get("narrow_crossing", false):
		cost += 0.4 if UnitCatalog.is_infantry(kind) else 0.75
	return cost / RoadRules.SPEED if RoadRules.has_road(tiles, from) and RoadRules.has_road(tiles, to) else cost

static func crosses_river(tiles: Dictionary, from: Vector2i, to: Vector2i) -> bool:
	return to in tiles.get(from, {}).get("river_neighbors", []) or from in tiles.get(to, {}).get("river_neighbors", [])

static func attack_multiplier(_tile: Dictionary, _kind: String) -> float:
	return 1.0

static func defense_multiplier(tile: Dictionary, kind: String, stationary: bool) -> float:
	if not stationary:
		return 1.0
	var terrain: String = ground(tile)
	if terrain == "forest" and UnitCatalog.is_infantry(kind):
		return 0.85
	return DEFENSE.get(terrain, 1.0)

static func description(tile: Dictionary) -> String:
	var text: String = ground(tile).capitalize() + ": "
	match ground(tile):
		"forest": text += "stationary infantry take 15% less damage"
		"mountain": text += "ground speed -20%; stationary defenders take 25% less damage"
		"desert": text += "vehicle speed +10%"
		"city": text += "stationary ground defenders take 20% less damage"
		_: text += "normal movement and defense"
	if tile.get("road", false):
		text += "; connected roads: speed +30%"
	else:
		text += "; no road"
	return text
