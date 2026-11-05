extends RefCounted
class_name OilDerrickNetwork

signal command_event(message: String, hex: Vector2i)

const SITE_COUNT: int = 20
const CAPTURE_SECONDS: float = 5.0
const MAX_HEALTH: float = 300.0
const INCOME_PER_SECOND: float = 3.0
const PAYOUT_INTERVAL: float = 1.0
const REPAIR_HP_PER_SECOND: float = 20.0
const REPAIR_COST_PER_HP: float = 1.0

var sites: Dictionary = {}
var payout_elapsed: float = 0.0
var pending_income: Dictionary = {1: 0.0, 2: 0.0}


static func site_id(hex: Vector2i) -> String:
	return "oil_%d_%d" % [hex.x, hex.y]


static func valid_site_tile(tiles: Dictionary, hex: Vector2i) -> bool:
	if not HexPathfinding.is_walkable(tiles, hex):
		return false
	var tile: Dictionary = tiles[hex]
	return tile.get("terrain", "") not in ["city", "resource"] and String(tile.get("site_name", "")).is_empty() and not tile.has("supply_id")


static func default_site_hexes(tiles: Dictionary, player_hq: Vector2i, rival_hq: Vector2i, reserved: Dictionary = {}) -> Array[Vector2i]:
	var candidates: Array[Vector2i] = []
	for hex in tiles:
		if not reserved.has(hex) and valid_site_tile(tiles, hex) and HexMath.distance(hex, player_hq) >= 4 and HexMath.distance(hex, rival_hq) >= 4:
			candidates.append(hex)
	candidates.sort_custom(_hex_before)
	var selected: Array[Vector2i] = []
	var player_near: Variant = _fair_start_site(candidates, tiles, player_hq, rival_hq, true)
	var rival_near: Variant = _fair_start_site(candidates, tiles, player_hq, rival_hq, false)
	if player_near != null:
		selected.append(player_near)
	if rival_near != null and rival_near not in selected:
		selected.append(rival_near)
	while selected.size() < SITE_COUNT:
		var best: Variant = null
		var best_distance: int = -1
		for candidate in candidates:
			if candidate in selected:
				continue
			var separation: int = 1000000
			for existing in selected:
				separation = mini(separation, HexMath.distance(candidate, existing))
			if selected.is_empty():
				separation = mini(HexMath.distance(candidate, player_hq), HexMath.distance(candidate, rival_hq))
			if separation > best_distance:
				best_distance = separation
				best = candidate
		if best == null:
			break
		selected.append(best)
	selected.sort_custom(_hex_before)
	return selected


static func _fair_start_site(candidates: Array[Vector2i], tiles: Dictionary, player_hq: Vector2i, rival_hq: Vector2i, for_player: bool) -> Variant:
	var home: Vector2i = player_hq if for_player else rival_hq
	var other: Vector2i = rival_hq if for_player else player_hq
	var best: Variant = null
	var best_route: int = 1000000
	for candidate in candidates:
		var distance: int = HexMath.distance(home, candidate)
		if distance > 9 or HexMath.distance(other, candidate) <= distance:
			continue
		var route: Array[Vector2i] = HexPathfinding.find_path(tiles, home, candidate, "rifle")
		if route.size() > 1 and route.size() < best_route:
			best_route = route.size()
			best = candidate
	return best


static func _hex_before(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)


func configure_defaults(tiles: Dictionary, player_hq: Vector2i, rival_hq: Vector2i, reserved: Dictionary = {}) -> void:
	sites.clear()
	for hex in default_site_hexes(tiles, player_hq, rival_hq, reserved):
		sites[hex] = _new_site(hex)
	payout_elapsed = 0.0
	pending_income = {1: 0.0, 2: 0.0}


static func _new_site(hex: Vector2i) -> Dictionary:
	return {"id": site_id(hex), "owner": 0, "health": MAX_HEALTH, "capture_faction": 0,
		"capture_elapsed": 0.0, "contested": false, "repairing": false}


func site_at(hex: Vector2i) -> Dictionary:
	return sites.get(hex, {})


func operational(hex: Vector2i, territory: TerritoryState) -> bool:
	if not sites.has(hex):
		return false
	var site: Dictionary = sites[hex]
	var owner: int = site.get("owner", 0)
	return owner > 0 and site.get("health", 0.0) > 0.0 and not site.get("contested", false) and site.get("capture_faction", 0) == 0 and territory.owner_at(hex) == owner and not territory.is_contested(hex)


func operational_count(faction: int, territory: TerritoryState) -> int:
	var count: int = 0
	for hex in sites:
		count += int(sites[hex].get("owner", 0) == faction and operational(hex, territory))
	return count


func income_per_minute(faction: int, territory: TerritoryState) -> float:
	return operational_count(faction, territory) * INCOME_PER_SECOND * 60.0 * (1.0 + territory.continents.bonus(faction))


func advance_capture(delta: float, units: Array[UnitState], territory: TerritoryState) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var occupants: Dictionary = {}
	var infantry: Dictionary = {}
	for unit in units:
		if not unit.is_deployed() or not unit.path.is_empty() or unit.domain != "ground" or not sites.has(unit.hex):
			continue
		if not occupants.has(unit.hex):
			occupants[unit.hex] = {}
		occupants[unit.hex][unit.faction] = true
		if UnitCatalog.is_infantry(unit.kind):
			if not infantry.has(unit.hex):
				infantry[unit.hex] = {}
			infantry[unit.hex][unit.faction] = true
	for hex in sites:
		var site: Dictionary = sites[hex]
		var factions: Dictionary = occupants.get(hex, {})
		site["contested"] = factions.size() > 1
		var capturing: int = 0
		if factions.size() == 1:
			var present: int = factions.keys()[0]
			if present != site.get("owner", 0) and infantry.get(hex, {}).has(present):
				capturing = present
		if capturing == 0:
			_interrupt_capture(site, hex)
			continue
		if site.get("capture_faction", 0) != capturing:
			_interrupt_capture(site, hex)
			site["capture_faction"] = capturing
			site["capture_elapsed"] = 0.0
		site["capture_elapsed"] += delta
		if site["capture_elapsed"] < CAPTURE_SECONDS:
			continue
		var previous: int = site.get("owner", 0)
		site["owner"] = capturing
		site["capture_faction"] = 0
		site["capture_elapsed"] = 0.0
		site["contested"] = false
		site["repairing"] = false
		territory.set_owner(hex, capturing)
		if previous == 1 and capturing != 1:
			command_event.emit("Oil derrick lost to Rival", hex)
		elif capturing == 1:
			command_event.emit("Oil derrick captured", hex)
		else:
			command_event.emit("Rival captured an oil derrick", hex)


func _interrupt_capture(site: Dictionary, hex: Vector2i) -> void:
	if site.get("capture_faction", 0) != 0:
		command_event.emit("Oil capture interrupted", hex)
	site["capture_faction"] = 0
	site["capture_elapsed"] = 0.0


func advance_economy(delta: float, territory: TerritoryState, economies: Array[EconomyState]) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	var by_faction: Dictionary = {}
	for economy in economies:
		by_faction[economy.faction] = economy
	var remaining: float = delta
	while remaining > 0.0000001:
		var step: float = minf(remaining, PAYOUT_INTERVAL - payout_elapsed)
		for faction in [1, 2]:
			pending_income[faction] = float(pending_income.get(faction, 0.0)) + operational_count(faction, territory) * INCOME_PER_SECOND * step
		_advance_repairs(step, territory, by_faction)
		payout_elapsed += step
		remaining -= step
		if payout_elapsed + 0.0000001 >= PAYOUT_INTERVAL:
			for faction in [1, 2]:
				var amount: float = float(pending_income.get(faction, 0.0))
				if amount > 0.0 and by_faction.has(faction):
					by_faction[faction].credit_approved_income(amount, EconomyState.SOURCE_OIL_DERRICK, territory)
				pending_income[faction] = 0.0
			payout_elapsed = 0.0
	for faction in [1, 2]:
		if by_faction.has(faction):
			by_faction[faction].oil_derrick_count = operational_count(faction, territory)


func _advance_repairs(delta: float, territory: TerritoryState, by_faction: Dictionary) -> void:
	for hex in sites:
		var site: Dictionary = sites[hex]
		var owner: int = site.get("owner", 0)
		if not site.get("repairing", false) or owner == 0 or not by_faction.has(owner) or territory.owner_at(hex) != owner or territory.is_contested(hex) or site.get("contested", false):
			continue
		var economy: EconomyState = by_faction[owner]
		var restored: float = minf(MAX_HEALTH - float(site.get("health", 0.0)), minf(REPAIR_HP_PER_SECOND * delta, economy.credits / REPAIR_COST_PER_HP))
		if restored > 0.0 and economy.account.try_spend(restored * REPAIR_COST_PER_HP, "Repair oil derrick at %s" % hex):
			var was_destroyed: bool = site.get("health", 0.0) <= 0.0
			site["health"] = minf(MAX_HEALTH, float(site.get("health", 0.0)) + restored)
			if was_destroyed and site["health"] > 0.0:
				command_event.emit("Oil derrick restored", hex)
		if site.get("health", 0.0) >= MAX_HEALTH:
			site["repairing"] = false


func set_repair(hex: Vector2i, faction: int, territory: TerritoryState, expected_site: Dictionary, enabled: bool) -> bool:
	if not sites.has(hex) or not is_same(sites[hex], expected_site) or expected_site.get("owner", 0) != faction or territory.owner_at(hex) != faction or territory.is_contested(hex):
		return false
	if enabled and expected_site.get("health", MAX_HEALTH) >= MAX_HEALTH:
		return false
	expected_site["repairing"] = enabled
	return true


func damage(hex: Vector2i, amount: float) -> bool:
	if not sites.has(hex) or not is_finite(amount) or amount <= 0.0 or sites[hex].get("health", 0.0) <= 0.0:
		return false
	var site: Dictionary = sites[hex]
	site["health"] = maxf(0.0, float(site.get("health", MAX_HEALTH)) - amount)
	if site["health"] <= 0.0:
		site["repairing"] = false
		_interrupt_capture(site, hex)
		command_event.emit("Oil derrick destroyed", hex)
	return true


func capture_goal(start: Vector2i, faction: int, tiles: Dictionary) -> Variant:
	var best: Variant = null
	var best_length: int = 1000000
	var ordered: Array[Vector2i] = []
	ordered.assign(sites.keys())
	ordered.sort_custom(_hex_before)
	for hex in ordered:
		if sites[hex].get("owner", 0) == faction:
			continue
		var route: Array[Vector2i] = HexPathfinding.find_path(tiles, start, hex, "rifle")
		if not route.is_empty() and route.size() < best_length:
			best = hex
			best_length = route.size()
	return best


func snapshot() -> Dictionary:
	var entries: Array[Dictionary] = []
	var ordered: Array[Vector2i] = []
	ordered.assign(sites.keys())
	ordered.sort_custom(_hex_before)
	for hex in ordered:
		var entry: Dictionary = sites[hex].duplicate(true)
		entry["hex"] = hex
		entries.append(entry)
	return {"sites": entries, "payout_elapsed": payout_elapsed, "pending_income": pending_income.duplicate(true)}


static func default_snapshot(tiles: Dictionary, player_hq: Vector2i, rival_hq: Vector2i, reserved: Dictionary = {}) -> Dictionary:
	var network: OilDerrickNetwork = OilDerrickNetwork.new()
	network.configure_defaults(tiles, player_hq, rival_hq, reserved)
	return network.snapshot()


func restore(data: Dictionary) -> void:
	sites.clear()
	for entry in data.get("sites", []):
		var site: Dictionary = entry.duplicate(true)
		var hex: Vector2i = site["hex"]
		site.erase("hex")
		sites[hex] = site
	payout_elapsed = float(data.get("payout_elapsed", 0.0))
	pending_income = data.get("pending_income", {1: 0.0, 2: 0.0}).duplicate(true)
