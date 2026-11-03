extends RefCounted
class_name EconomyState
## Faction economy and production. All money mutations use the shared account.
const BUILD_COSTS: Dictionary = {"headquarters": 300, "barracks": 100, "factory": 200}
const TRAIN_COSTS: Dictionary = {"rifle": 50, "tank": 150}
const TRAIN_SECONDS: Dictionary = {"rifle": 4.0, "tank": 8.0}
var account: CreditsAccount
var credits: float:
	get:
		return account.balance
	set(value):
		account.set_balance(value)
var buildings: Dictionary = {}
var faction: int = 1

func _init(starting_funds: float = CreditsAccount.DEFAULT_STARTING_FUNDS) -> void:
	account = CreditsAccount.new(starting_funds)

func add_building(hex: Vector2i, kind: String) -> void:
	buildings[hex] = {"kind": kind, "rally": hex, "queue": [], "elapsed": 0.0}

func build(hex: Vector2i, kind: String, tiles: Dictionary, territory: TerritoryState) -> bool:
	if not can_build(hex, kind, tiles, territory):
		return false
	if not account.try_spend(BUILD_COSTS[kind], "Build %s at %s" % [kind, hex]):
		return false
	add_building(hex, kind)
	return true

func can_build(hex: Vector2i, kind: String, tiles: Dictionary, territory: TerritoryState) -> bool:
	if kind == "headquarters":
		for building in buildings.values():
			if building["kind"] == "headquarters":
				return false
	if not BUILD_COSTS.has(kind) or buildings.has(hex) or territory.owner_at(hex) != faction or not HexPathfinding.is_walkable(tiles, hex):
		return false
	if not account.can_afford(BUILD_COSTS[kind]):
		return false
	return true

func train(hex: Vector2i, kind: String, territory: TerritoryState) -> bool:
	if not buildings.has(hex) or territory.owner_at(hex) != faction or not TRAIN_COSTS.has(kind):
		return false
	var building: Dictionary = buildings[hex]
	var required: String = "barracks" if kind == "rifle" else "factory"
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
	var rate: float = 0.0
	for hex in territory.owners:
		if territory.owner_at(hex) != faction or not tiles.has(hex):
			continue
		var terrain: String = tiles[hex].get("terrain", "")
		if terrain == "resource":
			rate += 2.0
		elif terrain == "city":
			rate += 1.0
	for hex in buildings:
		if territory.owner_at(hex) == faction and buildings[hex]["kind"] == "headquarters":
			rate += 5.0
	return rate

func advance(delta: float, tiles: Dictionary, territory: TerritoryState) -> Array[UnitState]:
	var recruits: Array[UnitState] = []
	if not is_finite(delta) or delta <= 0.0:
		return recruits
	account.add_income(income_rate(tiles, territory) * delta, "Territory and HQ income")
	for hex in buildings:
		var building: Dictionary = buildings[hex]
		if territory.owner_at(hex) != faction or building["queue"].is_empty():
			continue
		building["elapsed"] += delta
		while not building["queue"].is_empty():
			var kind: String = building["queue"][0]
			if building["elapsed"] < TRAIN_SECONDS[kind]:
				break
			building["elapsed"] -= TRAIN_SECONDS[kind]
			building["queue"].pop_front()
			var unit: UnitState = UnitState.new(hex, "Rifle squad" if kind == "rifle" else "Main battle tank")
			unit.configure_kind(kind)
			unit.faction = faction
			unit.order_move(tiles, building["rally"])
			recruits.append(unit)
		if building["queue"].is_empty():
			building["elapsed"] = 0.0
	return recruits
