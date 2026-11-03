extends RefCounted
class_name TerrainRules
## Costs multiply seconds per hex. No land terrain is a hard movement barrier.

const INFANTRY_COST: Dictionary = {"plains": 1.0, "forest": 1.35, "mountain": 1.8, "desert": 1.2, "city": 1.1, "snow": 1.6, "tundra": 1.25}
const ARMOR_COST: Dictionary = {"plains": 1.0, "forest": 2.0, "mountain": 4.0, "desert": 0.9, "city": 1.4, "snow": 2.0, "tundra": 1.4}

static func ground(tile: Dictionary) -> String:
	var terrain: String = tile.get("terrain", "plains")
	return tile.get("biome", "plains") if terrain == "resource" else terrain

static func movement_cost(tiles: Dictionary, from: Vector2i, to: Vector2i, kind: String = "rifle") -> float:
	if not HexPathfinding.is_walkable(tiles, from) or not HexPathfinding.is_walkable(tiles, to) or HexMath.distance(from, to) != 1:
		return INF
	var costs: Dictionary = ARMOR_COST if kind == "tank" else INFANTRY_COST
	var cost: float = costs.get(ground(tiles[to]), 1.0)
	if crosses_river(tiles, from, to):
		cost += 1.0 if kind == "tank" else 0.6
	if tiles[from].get("narrow_crossing", false) or tiles[to].get("narrow_crossing", false):
		cost += 0.75 if kind == "tank" else 0.4
	return cost

static func crosses_river(tiles: Dictionary, from: Vector2i, to: Vector2i) -> bool:
	return to in tiles.get(from, {}).get("river_neighbors", []) or from in tiles.get(to, {}).get("river_neighbors", [])

static func attack_multiplier(tile: Dictionary, kind: String) -> float:
	var terrain: String = ground(tile)
	if kind == "tank" and terrain == "desert":
		return 1.1
	return 1.0

static func defense_multiplier(tile: Dictionary, kind: String, stationary: bool) -> float:
	if not stationary:
		return 1.0
	var terrain: String = ground(tile)
	if terrain == "city":
		return 0.75 if kind == "rifle" else 0.85
	if terrain == "mountain":
		return 0.8 if kind == "rifle" else 0.9
	if terrain == "forest" and kind == "rifle":
		return 0.85
	return 1.0
