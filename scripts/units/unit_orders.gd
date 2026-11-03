extends RefCounted
class_name UnitOrders
## Explicit attack pursuit; ordinary movement and Hold keep their existing rules.
static func attack(unit: UnitState, tiles: Dictionary, goal: Vector2i, target: UnitState = null) -> bool:
	if target != null and (not target.is_deployed() or target.faction == unit.faction or not UnitCatalog.can_target(unit, target)):
		return false
	if not unit.order_move(tiles, goal):
		return false
	unit.attack_order = true
	unit.attack_hex = goal
	unit.attack_target = weakref(target) if target != null else null
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
			attack(unit, tiles, target.hex, target)
		_trim_route(unit)
