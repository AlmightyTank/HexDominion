extends RefCounted
class_name EconomyState
signal building_destroyed(hex: Vector2i, kind: String, rotation: int, owner: int)
## Faction economy and production. All money mutations use the shared account.
const BUILD_COSTS: Dictionary = {"headquarters": 300, "barracks": 100, "factory": 200, "extractor": 100, "power_plant": 150, "bunker": 100}
const EXTRACTOR_HEALTH: float = 200.0
const BUILD_SECONDS: Dictionary = {"headquarters": 12.0, "barracks": 6.0, "factory": 10.0, "extractor": 5.0, "power_plant": 8.0, "bunker": 8.0}
const BUILD_HEALTH: Dictionary = {"headquarters": 600.0, "barracks": 300.0, "factory": 450.0, "extractor": 200.0, "power_plant": 250.0, "bunker": 400.0}
const POWER_SUPPLY: Dictionary = {"headquarters": 20, "power_plant": 40}
const POWER_DEMAND: Dictionary = {"factory": 20, "extractor": 10}
const CANCEL_REFUND_FRACTION: float = 0.5
const SALVAGE_FRACTION: float = 0.5
const REPAIR_HP_PER_SECOND: float = 20.0
const REPAIR_COST_PER_HP: float = 1.0
const EXTRACTION_PER_SECOND: float = 2.0
const TRAIN_COSTS: Dictionary = UnitCatalog.COSTS
const TRAIN_SECONDS: Dictionary = UnitCatalog.TRAIN_SECONDS
const CITY_INCOME_PER_SECOND: float = 1.0
const HQ_INCOME_PER_SECOND: float = 5.0
var account: CreditsAccount
var credits: float:
	get:
		return account.balance
	set(value):
		account.set_balance(value)
var buildings: Dictionary = {}
var faction: int = 1
var supply: SupplyNetwork = SupplyNetwork.new()
const ROAD_INCOME_BONUS: float = 0.1

func _init(starting_funds: float = CreditsAccount.DEFAULT_STARTING_FUNDS) -> void:
	account = CreditsAccount.new(starting_funds)

func add_building(hex: Vector2i, kind: String) -> void:
	buildings[hex] = {"kind": kind, "rally": hex, "queue": [], "elapsed": 0.0, "construction": BUILD_SECONDS[kind], "health": BUILD_HEALTH[kind]}
	if kind == "extractor":
		buildings[hex]["health"] = EXTRACTOR_HEALTH

func build(hex: Vector2i, kind: String, tiles: Dictionary, territory: TerritoryState, rotation: int = 0, other_buildings: Dictionary = {}) -> bool:
	if rotation < 0 or rotation > 5 or not can_build(hex, kind, tiles, territory, other_buildings):
		return false
	if not account.try_spend(BUILD_COSTS[kind], "Build %s at %s" % [kind, hex]):
		return false
	add_building(hex, kind)
	buildings[hex]["rotation"] = rotation
	buildings[hex]["construction"] = 0.0
	return true

static func is_complete(building: Dictionary) -> bool:
	return building.get("construction", BUILD_SECONDS[building["kind"]]) >= BUILD_SECONDS[building["kind"]]

func cancel_construction(hex: Vector2i, territory: TerritoryState, expected_site: Dictionary) -> bool:
	if not buildings.has(hex) or not is_same(buildings[hex], expected_site):
		return false
	var site: Dictionary = buildings[hex]
	if is_complete(site) or territory.owner_at(hex) != faction:
		return false
	var refund: float = BUILD_COSTS[site["kind"]] * CANCEL_REFUND_FRACTION
	if not account.add_income(refund, "Cancel %s at %s" % [site["kind"], hex]):
		return false
	buildings.erase(hex)
	return true

func _controlled_completed(hex: Vector2i, territory: TerritoryState, expected_site: Dictionary) -> bool:
	return buildings.has(hex) and is_same(buildings[hex], expected_site) and territory.owner_at(hex) == faction and is_complete(buildings[hex])

func set_repair(hex: Vector2i, territory: TerritoryState, expected_site: Dictionary, enabled: bool) -> bool:
	if not _controlled_completed(hex, territory, expected_site):
		return false
	if enabled and expected_site.get("health", BUILD_HEALTH[expected_site["kind"]]) >= BUILD_HEALTH[expected_site["kind"]]:
		return false
	expected_site["repairing"] = enabled
	return true

func sell_building(hex: Vector2i, territory: TerritoryState, expected_site: Dictionary) -> bool:
	if not _controlled_completed(hex, territory, expected_site):
		return false
	if not account.add_income(BUILD_COSTS[expected_site["kind"]] * SALVAGE_FRACTION, "Sell %s at %s" % [expected_site["kind"], hex]):
		return false
	buildings.erase(hex)
	return true

func can_build(hex: Vector2i, kind: String, tiles: Dictionary, territory: TerritoryState, other_buildings: Dictionary = {}) -> bool:
	if kind == "headquarters":
		for building in buildings.values():
			if building["kind"] == "headquarters":
				return false
	if not BUILD_COSTS.has(kind) or buildings.has(hex) or other_buildings.has(hex) or territory.owner_at(hex) != faction or territory.is_contested(hex) or not HexPathfinding.is_walkable(tiles, hex):
		return false
	if kind == "extractor" and tiles[hex].get("terrain", "") != "resource":
		return false
	if not account.can_afford(BUILD_COSTS[kind]):
		return false
	return true

func production_site(kind: String, territory: TerritoryState) -> Variant:
	var candidates: Array = buildings.keys()
	candidates.reverse()
	var newest: Variant = null
	for hex in candidates:
		var site: Dictionary = buildings[hex]
		if site["kind"] != UnitCatalog.producer(kind) or not is_complete(site) or territory.owner_at(hex) != faction:
			continue
		if site.get("primary", false):
			return hex
		if newest == null:
			newest = hex
	return newest


func set_primary(hex: Vector2i, territory: TerritoryState) -> bool:
	if not buildings.has(hex) or territory.owner_at(hex) != faction or not is_complete(buildings[hex]) or not buildings[hex]["kind"] in ["barracks", "factory"]:
		return false
	for site in buildings.values():
		if site["kind"] == buildings[hex]["kind"]:
			site["primary"] = is_same(site, buildings[hex])
	return true


func train(hex: Vector2i, kind: String, territory: TerritoryState) -> bool:
	if not buildings.has(hex) or not is_complete(buildings[hex]) or territory.owner_at(hex) != faction or not TRAIN_COSTS.has(kind):
		return false
	var building: Dictionary = buildings[hex]
	var required: String = UnitCatalog.producer(kind)
	if building["kind"] != required or building["queue"].size() >= 5:
		return false
	if not account.try_spend(TRAIN_COSTS[kind], "Train %s at %s" % [kind, hex]):
		return false
	building["queue"].append(kind)
	return true

func set_rally(hex: Vector2i, goal: Vector2i, tiles: Dictionary, territory: TerritoryState) -> bool:
	if not buildings.has(hex) or territory.owner_at(hex) != faction or HexPathfinding.find_path(tiles, hex, goal).is_empty():
		return false
	buildings[hex]["rally"] = goal
	return true

func income_rate(tiles: Dictionary, territory: TerritoryState) -> float:
	supply.refresh(tiles, territory, self)
	var rate: float = 0.0
	var powered: bool = not low_power(territory)
	var continent_bonus: float = territory.continents.bonus(faction)
	for hex in territory.owners:
		rate += _location_income(hex, tiles, powered, continent_bonus)
	return rate

func _location_income(hex: Vector2i, tiles: Dictionary, powered: bool, continent_bonus: float = 0.0) -> float:
	if not supply.supplied.has(hex):
		return 0.0
	var base: float = CITY_INCOME_PER_SECOND if tiles[hex].get("terrain", "") == "city" else 0.0
	var hq_income: float = 0.0
	if buildings.has(hex) and is_complete(buildings[hex]):
		var site: Dictionary = buildings[hex]
		if site["kind"] == "headquarters":
			hq_income = HQ_INCOME_PER_SECOND
		elif site["kind"] == "extractor" and powered and site.get("health", 0.0) > 0 and tiles[hex].get("terrain", "") == "resource":
			base += EXTRACTION_PER_SECOND
	var road_bonus: float = ROAD_INCOME_BONUS if supply.road_supplied.has(hex) else 0.0
	return hq_income * (1.0 + continent_bonus) + base * (1.0 + road_bonus + continent_bonus)

func income_status(hex: Vector2i, tiles: Dictionary, territory: TerritoryState) -> Dictionary:
	supply.refresh(tiles, territory, self)
	var connected: bool = supply.supplied.has(hex)
	var road: bool = connected and supply.road_supplied.has(hex)
	return {"supplied": connected, "road_bonus": road, "income": _location_income(hex, tiles, not low_power(territory), territory.continents.bonus(faction))}

func power_balance(territory: TerritoryState) -> Dictionary:
	var supply: int = 0
	var demand: int = 0
	for hex in buildings:
		var building: Dictionary = buildings[hex]
		if territory.owner_at(hex) != faction or territory.is_contested(hex) or not is_complete(building):
			continue
		supply += POWER_SUPPLY.get(building["kind"], 0)
		demand += POWER_DEMAND.get(building["kind"], 0)
	return {"supply": supply, "demand": demand}

func low_power(territory: TerritoryState) -> bool:
	var power: Dictionary = power_balance(territory)
	return power["demand"] > power["supply"]

func damage_extractor(hex: Vector2i, amount: float) -> bool:
	if not is_finite(amount) or amount <= 0 or not buildings.has(hex) or buildings[hex]["kind"] != "extractor":
		return false
	return damage_building(hex, amount)

func damage_building(hex: Vector2i, amount: float) -> bool:
	if not is_finite(amount) or amount <= 0 or not buildings.has(hex):
		return false
	buildings[hex]["health"] = maxf(0.0, buildings[hex].get("health", BUILD_HEALTH[buildings[hex]["kind"]]) - amount)
	if buildings[hex]["health"] <= 0:
		var lost: Dictionary = buildings[hex]
		buildings.erase(hex)
		building_destroyed.emit(hex, lost["kind"], lost.get("rotation", 0), faction)
	return true

func advance(delta: float, tiles: Dictionary, territory: TerritoryState) -> Array[UnitState]:
	var recruits: Array[UnitState] = []
	if not is_finite(delta) or delta <= 0.0:
		return recruits
	var remaining: float = delta
	while remaining > 0.0:
		var step: float = remaining
		for hex in buildings:
			var site: Dictionary = buildings[hex]
			if not is_complete(site) and territory.owner_at(hex) == faction and not territory.is_contested(hex):
				step = minf(step, BUILD_SECONDS[site["kind"]] - site["construction"])
		recruits.append_array(_advance_interval(step, tiles, territory))
		remaining = maxf(0.0, remaining - step)
	return recruits

func _advance_interval(delta: float, tiles: Dictionary, territory: TerritoryState) -> Array[UnitState]:
	var recruits: Array[UnitState] = []
	var factory_speed: float = 0.5 if low_power(territory) else 1.0
	account.add_income(income_rate(tiles, territory) * delta, "Territory and HQ income")
	for hex in buildings:
		var building: Dictionary = buildings[hex]
		if not is_complete(building):
			continue
		if territory.owner_at(hex) != faction or building["queue"].is_empty():
			continue
		building["elapsed"] += delta * (factory_speed if building["kind"] == "factory" else 1.0)
		while not building["queue"].is_empty():
			var kind: String = building["queue"][0]
			if building["elapsed"] < TRAIN_SECONDS[kind]:
				break
			building["elapsed"] -= TRAIN_SECONDS[kind]
			building["queue"].pop_front()
			var unit: UnitState = UnitState.new(hex, UnitCatalog.TYPES[kind]["name"])
			unit.configure_kind(kind)
			unit.faction = faction
			unit.order_move(tiles, building["rally"])
			recruits.append(unit)
		if building["queue"].is_empty():
			building["elapsed"] = 0.0
	for hex in buildings:
		var building: Dictionary = buildings[hex]
		if building.get("repairing", false) and is_complete(building) and territory.owner_at(hex) == faction and not territory.is_contested(hex):
			var maximum: float = BUILD_HEALTH[building["kind"]]
			var restored: float = minf(maximum - building.get("health", maximum), minf(REPAIR_HP_PER_SECOND * delta, credits / REPAIR_COST_PER_HP))
			if restored > 0 and account.try_spend(restored * REPAIR_COST_PER_HP, "Repair %s at %s" % [building["kind"], hex]):
				building["health"] = minf(maximum, building["health"] + restored)
			if building.get("health", maximum) >= maximum:
				building["repairing"] = false
		if not is_complete(building) and territory.owner_at(hex) == faction and not territory.is_contested(hex):
			building["construction"] = minf(BUILD_SECONDS[building["kind"]], building["construction"] + delta)
	return recruits
