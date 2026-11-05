extends RefCounted
class_name SupplyLogistics

const CARGO_CAPACITY: float = 150.0
const LOAD_SECONDS: float = 3.0
const UNLOAD_SECONDS: float = 2.0
const NO_CENTER: Vector2i = Vector2i(-99999, -99999)
const TASKS: Array[String] = ["idle", "to_deposit", "loading", "to_center", "unloading", "waiting_deposit", "waiting_center"]
const DEPOSIT_CAPACITIES: Dictionary = {"small": 1500.0, "medium": 4500.0, "large": 9000.0}


static func deposit_id(hex: Vector2i) -> String:
	return "supply_%d_%d" % [hex.x, hex.y]


static func configure_deposit(tile: Dictionary, hex: Vector2i, size: String = "medium") -> void:
	var valid_size: String = size if DEPOSIT_CAPACITIES.has(size) else "medium"
	var capacity: float = DEPOSIT_CAPACITIES[valid_size]
	if not tile.has("supply_original_terrain"):
		tile["supply_original_terrain"] = tile.get("terrain", "plains")
	tile["terrain"] = "resource"
	tile["supply_id"] = deposit_id(hex)
	tile["supply_size"] = valid_size
	tile["supply_capacity"] = capacity
	tile["supply_remaining"] = clampf(float(tile.get("supply_remaining", capacity)), 0.0, capacity)


static func find_deposit(tiles: Dictionary, id: String) -> Variant:
	if id.is_empty():
		return null
	for hex in tiles:
		if tiles[hex].get("supply_id", "") == id:
			return hex
	return null


static func assign_deposit(truck: UnitState, deposit_hex: Vector2i, tiles: Dictionary) -> bool:
	if truck.kind != "supply_truck" or truck.supply_cargo >= CARGO_CAPACITY or not tiles.has(deposit_hex) or float(tiles[deposit_hex].get("supply_remaining", 0.0)) <= 0.0:
		return false
	var route: Array[Vector2i] = HexPathfinding.find_path(tiles, truck.hex, deposit_hex, truck.kind)
	if route.is_empty() or not truck.order_move(tiles, deposit_hex):
		return false
	truck.assigned_deposit_id = tiles[deposit_hex].get("supply_id", deposit_id(deposit_hex))
	truck.supply_task = "to_deposit" if truck.hex != deposit_hex else "loading"
	truck.supply_timer = 0.0
	truck.assigned_center = NO_CENTER
	truck.delivery_route.clear()
	return true


static func assign_center(truck: UnitState, center_hex: Vector2i, tiles: Dictionary, economy: EconomyState) -> bool:
	if truck.kind != "supply_truck" or truck.supply_cargo <= 0.0 or not economy.buildings.has(center_hex) or economy.buildings[center_hex].get("kind", "") != "supply_center":
		return false
	var route: Array[Vector2i] = HexPathfinding.find_path(tiles, truck.hex, center_hex, truck.kind)
	if route.is_empty() or not truck.order_move(tiles, center_hex):
		return false
	var traveled_prefix: Array[Vector2i] = []
	var current_index: int = truck.delivery_route.find(truck.hex)
	if current_index >= 0:
		traveled_prefix.assign(truck.delivery_route.slice(0, current_index + 1))
		if not traveled_prefix.is_empty() and not route.is_empty() and traveled_prefix.back() == route.front():
			route.remove_at(0)
	truck.assigned_center = center_hex
	truck.delivery_route = traveled_prefix
	truck.delivery_route.append_array(route)
	truck.supply_task = "to_center" if truck.hex != center_hex else "unloading"
	truck.supply_timer = 0.0
	return true


static func advance_all(delta: float, units: Array[UnitState], tiles: Dictionary, territory: TerritoryState, economies: Array[EconomyState]) -> void:
	if not is_finite(delta) or delta <= 0.0:
		return
	for truck in units:
		if truck.kind == "supply_truck" and truck.is_deployed() and truck.faction > 0 and truck.faction <= economies.size():
			advance_truck(delta, truck, tiles, territory, economies[truck.faction - 1])


static func advance_truck(delta: float, truck: UnitState, tiles: Dictionary, territory: TerritoryState, economy: EconomyState) -> void:
	if truck.supply_task not in TASKS:
		truck.supply_task = "idle"
		truck.supply_timer = 0.0
	if truck.supply_cargo > 0.0 and truck.supply_task in ["idle", "waiting_deposit", "to_deposit", "loading"]:
		_send_to_best_center(truck, tiles, territory, economy)
	if truck.supply_task == "idle":
		if not _send_to_best_deposit(truck, tiles, territory):
			truck.supply_task = "waiting_deposit"
		return
	if truck.supply_task == "waiting_deposit":
		_send_to_best_deposit(truck, tiles, territory)
		return
	if truck.supply_task == "waiting_center":
		_send_to_best_center(truck, tiles, territory, economy)
		return
	if truck.supply_task == "to_deposit" and truck.path.is_empty():
		truck.supply_task = "loading"
		truck.supply_timer = 0.0
	if truck.supply_task == "loading":
		_advance_loading(delta, truck, tiles, territory, economy)
		return
	if truck.supply_task == "to_center" and truck.path.is_empty():
		truck.supply_task = "unloading"
		truck.supply_timer = 0.0
	if truck.supply_task == "unloading":
		_advance_unloading(delta, truck, tiles, territory, economy)


static func _advance_loading(delta: float, truck: UnitState, tiles: Dictionary, territory: TerritoryState, economy: EconomyState) -> void:
	var deposit_hex: Variant = find_deposit(tiles, truck.assigned_deposit_id)
	if deposit_hex == null or truck.hex != deposit_hex or territory.owner_at(deposit_hex) != truck.faction or territory.is_contested(deposit_hex):
		truck.supply_timer = 0.0
		truck.supply_task = "waiting_deposit"
		return
	var tile: Dictionary = tiles[deposit_hex]
	if float(tile.get("supply_remaining", 0.0)) <= 0.0:
		truck.assigned_deposit_id = ""
		truck.supply_task = "waiting_deposit"
		truck.supply_timer = 0.0
		return
	truck.supply_timer += delta
	if truck.supply_timer + 0.000001 < LOAD_SECONDS:
		return
	var withdrawn: float = minf(CARGO_CAPACITY - truck.supply_cargo, float(tile["supply_remaining"]))
	tile["supply_remaining"] = maxf(0.0, float(tile["supply_remaining"]) - withdrawn)
	truck.supply_cargo += withdrawn
	truck.supply_timer = 0.0
	if truck.supply_cargo <= 0.0 or not _send_to_best_center(truck, tiles, territory, economy):
		truck.supply_task = "waiting_center" if truck.supply_cargo > 0.0 else "waiting_deposit"


static func _advance_unloading(delta: float, truck: UnitState, tiles: Dictionary, territory: TerritoryState, economy: EconomyState) -> void:
	if truck.hex != truck.assigned_center or not economy.operational_supply_center(truck.assigned_center, territory):
		truck.supply_timer = 0.0
		truck.supply_task = "waiting_center"
		return
	truck.supply_timer += delta
	if truck.supply_timer + 0.000001 < UNLOAD_SECONDS:
		return
	var cargo: float = truck.supply_cargo
	var road_qualified: bool = SupplyNetwork.qualifies_delivery_route(truck.delivery_route, tiles, territory, truck.faction)
	var payout: float = economy.credit_approved_income(cargo, EconomyState.SOURCE_DELIVERY, territory, road_qualified)
	if payout <= 0.0:
		truck.supply_timer = 0.0
		truck.supply_task = "waiting_center"
		return
	truck.supply_cargo = 0.0
	truck.supply_timer = 0.0
	truck.assigned_center = NO_CENTER
	truck.delivery_route.clear()
	truck.supply_task = "idle"
	economy.command_event.emit("Delivered %.0f supply for %.0f CR%s" % [cargo, payout, " (+10% road)" if road_qualified else ""], truck.hex)


static func _send_to_best_deposit(truck: UnitState, tiles: Dictionary, territory: TerritoryState) -> bool:
	var best_hex: Variant = null
	var best_route: Array[Vector2i] = []
	var candidates: Array[Vector2i] = []
	for hex in tiles:
		if float(tiles[hex].get("supply_remaining", 0.0)) > 0.0 and territory.owner_at(hex) == truck.faction and not territory.is_contested(hex):
			candidates.append(hex)
	candidates.sort_custom(_hex_before)
	for hex in candidates:
		var route: Array[Vector2i] = HexPathfinding.find_path(tiles, truck.hex, hex, truck.kind)
		if not route.is_empty() and (best_route.is_empty() or route.size() < best_route.size()):
			best_hex = hex
			best_route = route
	if best_hex == null:
		return false
	return assign_deposit(truck, best_hex, tiles)


static func _send_to_best_center(truck: UnitState, tiles: Dictionary, territory: TerritoryState, economy: EconomyState) -> bool:
	var best_hex: Variant = null
	var best_route: Array[Vector2i] = []
	var candidates: Array[Vector2i] = []
	for hex in economy.buildings:
		if economy.operational_supply_center(hex, territory):
			candidates.append(hex)
	candidates.sort_custom(_hex_before)
	for hex in candidates:
		var route: Array[Vector2i] = HexPathfinding.find_path(tiles, truck.hex, hex, truck.kind)
		if not route.is_empty() and (best_route.is_empty() or route.size() < best_route.size()):
			best_hex = hex
			best_route = route
	if best_hex == null:
		return false
	return assign_center(truck, best_hex, tiles, economy)


static func _hex_before(a: Vector2i, b: Vector2i) -> bool:
	return a.x < b.x or (a.x == b.x and a.y < b.y)
