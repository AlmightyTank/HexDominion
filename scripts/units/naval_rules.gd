extends RefCounted
class_name NavalRules

static func water(tiles: Dictionary, hex: Vector2i) -> bool:
	return tiles.has(hex) and not bool(tiles[hex].get("is_land", false)) and tiles[hex].get("terrain", "ocean") == "ocean" and bool(tiles[hex].get("navigable", true))

static func deployment(tiles: Dictionary, coast: Vector2i) -> Variant:
	if not HexPathfinding.is_walkable(tiles, coast):
		return null
	for neighbor in HexMath.neighbors(coast):
		if water(tiles, neighbor):
			return neighbor
	return null

static func can_land(tiles: Dictionary, ship: UnitState, goal: Vector2i, roster: Array[UnitState]) -> bool:
	if not water(tiles, ship.hex) or HexMath.distance(ship.hex, goal) != 1 or not HexPathfinding.is_walkable(tiles, goal) or not bool(tiles[goal].get("landable", true)):
		return false
	for unit in roster:
		if unit.is_deployed() and unit.faction != ship.faction and unit.domain == "ground" and unit.hex == goal:
			return false
	return true
