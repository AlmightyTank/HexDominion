extends RefCounted
class_name UnitOrders
## Explicit attack pursuit; ordinary movement and Hold keep their existing rules.
static func attack(unit: UnitState, tiles: Dictionary, goal: Vector2i, target: UnitState = null) -> bool:
	if unit.kind == "landing_transport" or (unit.kind == "patrol_boat" and (target == null or target.domain != "naval")):
		return false
	if unit.kind == "fighter" and (unit.air_mission != "ready" or unit.airfield == AircraftRules.NO_BASE):
		return false
	if target != null and (not target.is_deployed() or target.faction == unit.faction or not UnitCatalog.can_target(unit, target)):
		return false
	if (unit.kind in ["artillery", "destroyer"] or (target != null and target.domain in ["air", "naval"])) and unit.is_deployed() and unit.path.is_empty() and HexMath.distance(unit.hex, goal) <= unit.attack_range and tiles.has(goal):
		unit.order_hold()
		unit.holding = false
	else:
		if not unit.order_move(tiles, goal):
			return false
	unit.attack_order = true
	unit.attack_hex = goal
	unit.attack_target = weakref(target) if target != null else null
	if unit.kind == "fighter":
		unit.air_mission = "striking"
	_trim_route(unit)
	return true

static func _trim_route(unit: UnitState) -> void:
	if unit.progress == 0 and HexMath.distance(unit.hex, unit.attack_hex) <= unit.attack_range:
		unit.path.clear()
	else:
		while unit.path.size() > 1 and HexMath.distance(unit.path[-2], unit.attack_hex) <= unit.attack_range:
			unit.path.pop_back()

static func update(units: Array[UnitState], tiles: Dictionary, economies: Array[EconomyState]) -> void:
	for unit in units:
		_update_tactical(unit, units, tiles, economies)
		if not unit.is_deployed() or not unit.attack_order:
			continue
		var target: UnitState = unit.attack_target.get_ref() if unit.attack_target != null else null
		var valid: bool = false
		if unit.attack_target != null:
			valid = target != null and target.is_deployed() and target.faction != unit.faction and units.has(target) and UnitCatalog.can_target(unit, target)
		else:
			for economy in economies:
				valid = valid or (economy.faction != unit.faction and economy.buildings.has(unit.attack_hex))
		if not valid:
			unit.order_hold()
			continue
		if target != null and target.hex != unit.attack_hex:
			if unit.kind == "fighter":
				unit.air_mission = "ready"
			attack(unit, tiles, target.hex, target)
		_trim_route(unit)

static func tactical(unit: UnitState, mode: String, goal: Vector2i, tiles: Dictionary, target: UnitState = null, waypoints: Array[Vector2i] = []) -> bool:
	if mode not in ["attack_move", "guard", "patrol"] or not unit.is_deployed():
		return false
	# Jets use explicit strike missions; a geographic order cannot bypass rearming.
	if unit.kind == "fighter":
		return false
	if target != null and (mode != "guard" or target.faction != unit.faction or not target.is_deployed() or target == unit):
		return false
	var points: Array[Vector2i] = waypoints.duplicate()
	if mode == "patrol":
		if points.is_empty():
			points.assign([unit.hex, goal])
		if points.size() < 2 or points.size() > 16:
			return false
		for index in points.size():
			if HexPathfinding.find_path(tiles, points[index], points[(index + 1) % points.size()], unit.kind).is_empty():
				return false
	if not unit.order_move(tiles, goal):
		return false
	unit.tactical_order = {"mode": mode, "goal": goal, "anchor": goal, "points": points, "index": 1 if mode == "patrol" else 0}
	unit.guard_target = weakref(target) if target != null else null
	return true

static func _route(unit: UnitState, goal: Vector2i, tiles: Dictionary) -> bool:
	var order: Dictionary = unit.tactical_order
	var guard: WeakRef = unit.guard_target
	var accepted: bool = unit.order_move(tiles, goal)
	unit.tactical_order = order
	unit.guard_target = guard
	return accepted

static func _update_tactical(unit: UnitState, units: Array[UnitState], tiles: Dictionary, economies: Array[EconomyState]) -> void:
	if not unit.is_deployed() or unit.tactical_order.is_empty():
		return
	var order: Dictionary = unit.tactical_order
	if unit.guard_target != null:
		var guarded: UnitState = unit.guard_target.get_ref()
		if guarded == null or not guarded.is_deployed() or not units.has(guarded) or guarded.faction != unit.faction:
			unit.order_hold()
			return
		order["goal"] = guarded.hex
	var in_leash: bool = order["mode"] != "guard" or HexMath.distance(unit.hex, order["goal"]) <= 2
	var threat: bool = false
	if in_leash:
		for enemy in units:
			if enemy.is_deployed() and enemy.faction != unit.faction and UnitCatalog.can_target(unit, enemy) and HexMath.distance(unit.hex, enemy.hex) <= unit.attack_range:
				threat = true
				break
		if unit.kind not in ["patrol_boat", "landing_transport"]:
			for economy in economies:
				if economy.faction != unit.faction:
					for hex in economy.buildings:
						threat = threat or HexMath.distance(unit.hex, hex) <= unit.attack_range
	# Finish the current edge before stopping. Neither combat nor resuming teleports.
	if threat:
		if unit.progress > 0 and not unit.path.is_empty():
			unit.path.resize(1)
		else:
			unit.path.clear()
		return
	if not unit.path.is_empty() and unit.path[-1] == order["goal"]:
		return
	if unit.hex == order["goal"]:
		if order["mode"] == "patrol":
			order["index"] = (order["index"] + 1) % order["points"].size()
			order["goal"] = order["points"][order["index"]]
		elif order["mode"] == "attack_move":
			unit.tactical_order = {}
			return
		else:
			return
	_route(unit, order["goal"], tiles)
