extends RefCounted
class_name FortificationRules
const CAPACITY: int = 2
const DAMAGE_MULTIPLIER: float = 0.6

static func occupants(hex: Vector2i, faction: int, units: Array[UnitState]) -> Array[UnitState]:
	var stationed: Array[UnitState] = []
	for unit in units:
		if unit.is_deployed() and UnitCatalog.is_infantry(unit.kind) and unit.faction == faction and unit.hex == hex and unit.path.is_empty() and unit.garrisoned and stationed.size() < CAPACITY:
			stationed.append(unit)
	return stationed

static func operational(hex: Vector2i, economy: EconomyState, territory: TerritoryState) -> bool:
	return territory.owner_at(hex) == economy.faction and economy.buildings.has(hex) and economy.buildings[hex]["kind"] == "bunker" and EconomyState.is_complete(economy.buildings[hex]) and economy.buildings[hex].get("health", 0) > 0

static func assign(unit: UnitState, economy: EconomyState, territory: TerritoryState, units: Array[UnitState]) -> bool:
	if not unit.is_deployed() or not UnitCatalog.is_infantry(unit.kind) or unit.faction != economy.faction or not unit.path.is_empty() or not operational(unit.hex, economy, territory):
		return false
	if not unit.garrisoned and occupants(unit.hex, unit.faction, units).size() >= CAPACITY:
		return false
	unit.garrisoned = true
	unit.order_hold()
	return occupants(unit.hex, unit.faction, units).has(unit)

static func protection(units: Array[UnitState], economies: Array[EconomyState], territory: TerritoryState) -> Dictionary:
	var protected: Dictionary = {}
	for economy in economies:
		for hex in economy.buildings:
			if operational(hex, economy, territory):
				for unit in occupants(hex, economy.faction, units):
					protected[unit] = DAMAGE_MULTIPLIER
	for unit in units:
		if unit.garrisoned and not protected.has(unit):
			unit.garrisoned = false
	return protected
