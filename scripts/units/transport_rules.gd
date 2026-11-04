extends RefCounted
class_name TransportRules

const CAPACITY: int = 4

static func capacity(transport: UnitState) -> int:
	return UnitCatalog.TYPES[transport.kind].get("capacity", CAPACITY if transport.kind == "apc" else 0)

static func cargo_cost(unit: UnitState) -> int:
	return 1 if UnitCatalog.is_infantry(unit.kind) else 2

static func used(transport: UnitState, roster: Array[UnitState]) -> int:
	var slots: int = 0
	for unit in passengers(transport, roster):
		slots += cargo_cost(unit)
	return slots

static func permits(kind: String, cargo: String) -> bool:
	return UnitCatalog.is_infantry(cargo) if kind == "apc" else (kind == "landing_transport" and (UnitCatalog.is_infantry(cargo) or cargo in ["tank", "scout", "apc", "anti_air", "artillery"]))

static func passengers(apc: UnitState, roster: Array[UnitState]) -> Array[UnitState]:
	var result: Array[UnitState] = []
	for unit in roster:
		if unit.is_alive() and unit.is_embarked() and unit.carrier.get_ref() == apc:
			result.append(unit)
	return result

static func load(unit: UnitState, apc: UnitState, roster: Array[UnitState], tiles: Dictionary = {}) -> bool:
	if unit == apc or not roster.has(unit) or not roster.has(apc) or not unit.is_deployed() or not apc.is_deployed():
		return false
	if not permits(apc.kind, unit.kind) or unit.faction != apc.faction or not apc.path.is_empty() or not unit.path.is_empty() or used(apc, roster) + cargo_cost(unit) > capacity(apc) or not passengers(unit, roster).is_empty():
		return false
	if (apc.kind == "apc" and unit.hex != apc.hex) or (apc.kind == "landing_transport" and not NavalRules.can_land(tiles, apc, unit.hex, roster)):
		return false
	unit.order_hold()
	unit.garrisoned = false
	unit.carrier = weakref(apc)
	unit.hex = apc.hex
	return true

static func unload(apc: UnitState, goal: Vector2i, tiles: Dictionary, roster: Array[UnitState]) -> bool:
	if not apc.is_deployed() or capacity(apc) == 0 or not apc.path.is_empty() or HexMath.distance(apc.hex, goal) > 1 or not HexPathfinding.is_walkable(tiles, goal):
		return false
	if apc.kind == "landing_transport" and not NavalRules.can_land(tiles, apc, goal, roster):
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
