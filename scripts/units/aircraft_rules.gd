extends RefCounted
class_name AircraftRules
## Bases are coordinates, not references to structures that can be sold or destroyed.
const NO_BASE: Vector2i = Vector2i(-99999, -99999)

static func valid_base(hex: Vector2i, economy: EconomyState, territory: TerritoryState, powered: bool = false) -> bool:
	return economy.buildings.has(hex) and economy.buildings[hex]["kind"] == "airfield" and EconomyState.is_complete(economy.buildings[hex]) and territory.owner_at(hex) == economy.faction and not territory.is_contested(hex) and (not powered or not economy.low_power(territory))

static func update(delta: float, units: Array[UnitState], tiles: Dictionary, economies: Array[EconomyState], territory: TerritoryState) -> void:
	if not is_finite(delta) or delta < 0:
		return
	for unit in units:
		if not unit.is_deployed() or not UnitCatalog.is_air(unit.kind):
			continue
		var economy: EconomyState = null
		for candidate in economies:
			if candidate.faction == unit.faction:
				economy = candidate
		if economy == null:
			continue
		if not valid_base(unit.airfield, economy, territory):
			unit.airfield = NO_BASE
			var distance: int = 2147483647
			for hex in economy.buildings:
				if valid_base(hex, economy, territory) and HexMath.distance(unit.hex, hex) < distance:
					unit.airfield = hex
					distance = HexMath.distance(unit.hex, hex)
			if unit.kind == "fighter" and unit.air_mission != "ready":
				unit.order_hold()
				unit.air_mission = "returning"
		if unit.kind != "fighter":
			continue
		if unit.airfield == NO_BASE and unit.air_mission == "ready":
			unit.air_mission = "orphaned"
		if unit.air_mission == "striking" and not unit.attack_order:
			unit.air_mission = "returning"
		if unit.air_mission == "returning":
			if unit.airfield == NO_BASE:
				unit.air_mission = "orphaned"
			elif unit.hex != unit.airfield:
				if unit.path.is_empty() or unit.path[-1] != unit.airfield:
					unit.order_move(tiles, unit.airfield)
			else:
				unit.order_hold()
				unit.air_mission = "rearming"
				unit.mission_remaining = UnitCatalog.TYPES["fighter"]["mission_cooldown"]
		elif unit.air_mission == "rearming" and valid_base(unit.airfield, economy, territory, true):
			unit.mission_remaining = maxf(0, unit.mission_remaining - delta)
			if unit.mission_remaining == 0:
				unit.air_mission = "ready"
		elif unit.air_mission == "orphaned" and unit.airfield != NO_BASE:
			unit.air_mission = "returning"

static func fired(unit: UnitState) -> void:
	if unit.kind == "fighter":
		unit.attack_order = false
		unit.attack_target = null
		unit.air_mission = "returning"
