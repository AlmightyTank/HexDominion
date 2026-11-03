extends RefCounted
class_name TransportRules

const CAPACITY: int = 4

static func passengers(apc: UnitState, roster: Array[UnitState]) -> Array[UnitState]:
	var result: Array[UnitState] = []
	for unit in roster:
		if unit.is_alive() and unit.is_embarked() and unit.carrier.get_ref() == apc:
			result.append(unit)
	return result

static func load(unit: UnitState, apc: UnitState, roster: Array[UnitState]) -> bool:
	if unit == apc or not roster.has(unit) or not roster.has(apc) or not unit.is_deployed() or not apc.is_deployed():
		return false
	if apc.kind != "apc" or unit.faction != apc.faction or not UnitCatalog.is_infantry(unit.kind) or unit.hex != apc.hex or not apc.path.is_empty() or not unit.path.is_empty() or passengers(apc, roster).size() >= CAPACITY:
		return false
	unit.order_hold()
	unit.garrisoned = false
	unit.carrier = weakref(apc)
	return true

static func unload(apc: UnitState, goal: Vector2i, tiles: Dictionary, roster: Array[UnitState]) -> bool:
	if not apc.is_deployed() or apc.kind != "apc" or not apc.path.is_empty() or HexMath.distance(apc.hex, goal) > 1 or not HexPathfinding.is_walkable(tiles, goal):
		return false
	var aboard: Array[UnitState] = passengers(apc, roster)
	if aboard.is_empty():
		return false
	for unit in aboard:
		unit.carrier = null
		unit.hex = goal
		unit.order_hold()
	return true

static func synchronize(roster: Array[UnitState]) -> void:
	for unit in roster:
		if not unit.is_embarked():
			continue
		var apc: UnitState = unit.carrier.get_ref()
		if not roster.has(apc) or not apc.is_alive():
			unit.health = 0
		else:
			unit.hex = apc.hex
