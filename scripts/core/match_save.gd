extends RefCounted
class_name MatchSave
## Versioned plain-Variant snapshot. Object decoding is deliberately disabled.
const PATH: String = "user://quicksave.hds"
const SAVE_DIRECTORY: String = "user://saves"
const MAP_ID: String = "earth-120x70-v1"

static func capture(layer: UnitLayer, camera_position: Vector2, camera_zoom: Vector2, inspected: Vector2i) -> Dictionary:
	var roster: Array = []
	for unit in layer.units:
		roster.append({"hex": unit.hex, "path": unit.path.duplicate(), "progress": unit.progress,
			"kind": unit.kind, "health": unit.health, "faction": unit.faction,
			"garrisoned": unit.garrisoned, "holding": unit.holding, "title": unit.title,
			"weapon_elapsed": unit.weapon_elapsed, "facing": unit.facing, "turret_facing": unit.turret_facing,
			"carrier": layer.units.find(unit.carrier.get_ref()) if unit.is_embarked() else -1, "attack_order": unit.attack_order,
			"attack_hex": unit.attack_hex, "attack_target": layer.units.find(unit.attack_target.get_ref()) if unit.attack_target != null else -1})
	var match_state: MatchState = layer.match_state
	return {"version": 1, "map": MAP_ID, "units": roster,
		"owners": layer.territory.owners.duplicate(true), "captures": layer.territory.captures.duplicate(true),
		"contested": layer.territory.contested.duplicate(true),
		"roads": RoadRules.snapshot(layer.world_map.map_data["tiles"]),
		"economy": _economy_data(layer.economy), "rival_economy": _economy_data(match_state.rival_economy),
		"player_hq": match_state.player_hq, "rival_hq": match_state.rival_hq,
		"result": match_state.result, "ai_countdown": match_state.ai_countdown,
		"camera_position": camera_position, "camera_zoom": camera_zoom, "inspected": inspected}

static func _economy_data(economy: EconomyState) -> Dictionary:
	return {"credits": economy.credits, "account": economy.account.snapshot(), "buildings": economy.buildings.duplicate(true)}

static func _number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum

static func _land(value: Variant, tiles: Dictionary) -> bool:
	return value is Vector2i and HexPathfinding.is_walkable(tiles, value)

static func validate(data: Variant, tiles: Dictionary) -> bool:
	if not data is Dictionary or data.get("version") != 1 or data.get("map") != MAP_ID:
		return false
	if data.has("save_name") and (not data["save_name"] is String or data["save_name"].strip_edges().is_empty() or data["save_name"].length() > 80):
		return false
	if data.has("saved_at") and (not data["saved_at"] is int or data["saved_at"] < 0 or data["saved_at"] > 253402300799):
		return false
	for key in ["player_hq", "rival_hq"]:
		if not _land(data.get(key), tiles):
			return false
	if data["player_hq"] == data["rival_hq"] or data.get("result") not in ["playing", "victory", "defeat", "draw"] or not _number(data.get("ai_countdown"), 0, 8):
		return false
	if not data.get("camera_position") is Vector2 or not data["camera_position"].is_finite() or not data.get("camera_zoom") is Vector2:
		return false
	var zoom: Vector2 = data["camera_zoom"]
	if not zoom.is_finite() or zoom.x <= 0 or zoom.y != zoom.x or zoom.x > 100 or not data.get("inspected") is Vector2i:
		return false
	if not data.get("owners") is Dictionary or not data.get("captures") is Dictionary or not data.get("units") is Array or data["units"].size() > 10000:
		return false
	for hex in data["owners"]:
		if not _land(hex, tiles) or data["owners"][hex] not in [1, 2]:
			return false
	if not data.get("roads", {}) is Dictionary:
		return false
	for hex in data.get("roads", {}):
		if not hex is Vector2i or not tiles.has(hex) or not RoadRules.supports(tiles[hex]) or data["roads"][hex] != true:
			return false
	if data.has("contested"):
		if not data["contested"] is Dictionary:
			return false
		for hex in data["contested"]:
			if not _land(hex, tiles) or data["contested"][hex] != true:
				return false
	for hex in data["captures"]:
		var entry: Variant = data["captures"][hex]
		if not _land(hex, tiles) or not entry is Dictionary:
			return false
		if entry.get("faction") not in [1, 2] or not _number(entry.get("elapsed"), 0, TerritoryState.CAPTURE_SECONDS):
			return false
	var passenger_counts: Dictionary = {}
	for unit in data["units"]:
		if not unit is Dictionary or not _land(unit.get("hex"), tiles) or not unit.get("path") is Array:
			return false
		if unit.get("kind") not in UnitCatalog.TYPES or unit.get("faction") not in [1, 2] or not unit.get("garrisoned") is bool or not unit.get("title") is String:
			return false
		if not _number(unit.get("health"), 0.001, UnitCatalog.TYPES[unit["kind"]]["health"]) or not _number(unit.get("progress"), 0, 0.999999999):
			return false
		if not _number(unit.get("weapon_elapsed", 0.0), 0, UnitCatalog.TYPES[unit["kind"]]["cooldown"]) or not _number(unit.get("facing", 0.0), -PI, PI):
			return false
		if not _number(unit.get("turret_facing", unit.get("facing", 0.0)), -PI, PI) or not unit.get("carrier", -1) is int:
			return false
		var carrier_index: int = unit.get("carrier", -1)
		if carrier_index < -1 or carrier_index >= data["units"].size():
			return false
		if carrier_index >= 0:
			var transport: Variant = data["units"][carrier_index]
			if not transport is Dictionary or transport.get("kind") != "apc" or transport.get("faction") != unit["faction"] or transport.get("hex") != unit["hex"] or not UnitCatalog.is_infantry(unit["kind"]) or not unit["path"].is_empty() or unit["garrisoned"] or unit.get("attack_order", false):
				return false
			passenger_counts[carrier_index] = passenger_counts.get(carrier_index, 0) + 1
			if passenger_counts[carrier_index] > TransportRules.CAPACITY:
				return false
		if not unit.get("attack_order", false) is bool or not unit.get("attack_target", -1) is int:
			return false
		var target_index: int = unit.get("attack_target", -1)
		if target_index < -1 or target_index >= data["units"].size():
			return false
		if unit.get("attack_order", false):
			if not _land(unit.get("attack_hex"), tiles) or unit.get("holding", false) or unit["garrisoned"]:
				return false
			if target_index >= 0:
				var target_entry: Variant = data["units"][target_index]
				if not target_entry is Dictionary or target_entry.get("faction") == unit["faction"]:
					return false
		elif target_index != -1:
			return false
		if (unit["path"].is_empty() and unit["progress"] != 0) or (unit["garrisoned"] and not unit["path"].is_empty()):
			return false
		if not unit.get("holding", false) is bool or (unit.get("holding", false) and not unit["path"].is_empty()):
			return false
		var previous: Vector2i = unit["hex"]
		for step in unit["path"]:
			if not _land(step, tiles) or HexMath.distance(previous, step) != 1:
				return false
			previous = step
	for key in ["economy", "rival_economy"]:
		if not _valid_economy(data.get(key), tiles):
			return false
	for hex in data["economy"]["buildings"]:
		if data["rival_economy"]["buildings"].has(hex):
			return false
	return true

static func _valid_economy(data: Variant, tiles: Dictionary) -> bool:
	if not data is Dictionary or not _number(data.get("credits"), 0, 1.0e15) or not data.get("buildings") is Dictionary:
		return false
	if data.has("account"):
		if not CreditsAccount.valid_snapshot(data["account"]) or data["account"]["balance"] != data["credits"]:
			return false
	var headquarters: int = 0
	for hex in data["buildings"]:
		var building: Variant = data["buildings"][hex]
		if not _land(hex, tiles) or not building is Dictionary:
			return false
		if building.get("kind") not in EconomyState.BUILD_COSTS or not _land(building.get("rally"), tiles) or not building.get("queue") is Array:
			return false
		if not building.get("rotation", 0) is int or building.get("rotation", 0) < 0 or building.get("rotation", 0) > 5:
			return false
		if not _number(building.get("construction", EconomyState.BUILD_SECONDS[building["kind"]]), 0, EconomyState.BUILD_SECONDS[building["kind"]]):
			return false
		if building.has("construction") and not building.has("health"):
			return false
		if not _number(building.get("health", EconomyState.BUILD_HEALTH[building["kind"]]), 0.001, EconomyState.BUILD_HEALTH[building["kind"]]):
			return false
		if not building.get("repairing", false) is bool:
			return false
		if building.get("repairing", false) and not EconomyState.is_complete(building):
			return false
		if not EconomyState.is_complete(building) and (not building["queue"].is_empty() or building.get("elapsed", 0.0) != 0.0):
			return false
		if building["kind"] == "extractor":
			if tiles[hex].get("terrain", "") != "resource" or not _number(building.get("health"), 0.001, EconomyState.EXTRACTOR_HEALTH):
				return false
		headquarters += 1 if building["kind"] == "headquarters" else 0
		if building["queue"].size() > 5 or not _number(building.get("elapsed"), 0, 8):
			return false
		for kind in building["queue"]:
			if kind not in EconomyState.TRAIN_SECONDS or building["kind"] != UnitCatalog.producer(kind):
				return false
		if building["queue"].is_empty():
			if building["elapsed"] != 0:
				return false
		elif building["elapsed"] >= EconomyState.TRAIN_SECONDS[building["queue"][0]]:
			return false
	return headquarters <= 1

static func restore(layer: UnitLayer, data: Dictionary) -> bool:
	if not validate(data, layer.world_map.map_data["tiles"]):
		return false # Never mutate the live match before the entire snapshot validates.
	var roster: Array[UnitState] = []
	for entry in data["units"]:
		var unit: UnitState = UnitState.new(entry["hex"], entry["title"])
		unit.configure_kind(entry["kind"])
		unit.faction = entry["faction"]
		unit.health = entry["health"]
		unit.garrisoned = entry["garrisoned"]
		unit.holding = entry.get("holding", false)
		unit.path.assign(entry["path"])
		unit.progress = entry["progress"]
		unit.weapon_elapsed = entry.get("weapon_elapsed", 0.0)
		unit.facing = entry.get("facing", 0.0)
		unit.turret_facing = entry.get("turret_facing", unit.facing)
		unit.attack_order = entry.get("attack_order", false)
		unit.attack_hex = entry.get("attack_hex", Vector2i.ZERO)
		roster.append(unit)
	for index in range(roster.size()):
		var carrier_index: int = data["units"][index].get("carrier", -1)
		if carrier_index >= 0:
			roster[index].carrier = weakref(roster[carrier_index])
		var target_index: int = data["units"][index].get("attack_target", -1)
		if target_index >= 0:
			roster[index].attack_target = weakref(roster[target_index])
	layer.units = roster
	layer.wrecks.clear()
	for hex in layer.world_map.map_data["tiles"]:
		layer.world_map.map_data["tiles"][hex].erase("road")
	for hex in data.get("roads", {}):
		layer.world_map.map_data["tiles"][hex]["road"] = true
	layer.select_one(null)
	layer.expanded_hex = Vector2i(-99999, -99999)
	layer.build_kind = ""
	layer.build_rotation = 0
	layer.combat_targets.clear()
	layer.territory.owners = data["owners"].duplicate(true)
	layer.territory.captures = data["captures"].duplicate(true)
	layer.territory.contested = data.get("contested", {}).duplicate(true)
	layer.economy = _restore_economy(data["economy"], 1)
	var match_state: MatchState = MatchState.new()
	match_state.player_hq = data["player_hq"]
	match_state.rival_hq = data["rival_hq"]
	match_state.result = data["result"]
	match_state.ai_countdown = data["ai_countdown"]
	match_state.rival_economy = _restore_economy(data["rival_economy"], 2)
	layer.match_state = match_state
	layer.queue_redraw()
	return true

static func _restore_economy(data: Dictionary, faction: int) -> EconomyState:
	# Older saves have only a balance: import it as the account's opening funds.
	var economy: EconomyState = EconomyState.new(data["credits"])
	economy.faction = faction
	if data.has("account"):
		economy.account.restore(data["account"])
	economy.buildings = data["buildings"].duplicate(true)
	return economy

static func write(data: Dictionary, tiles: Dictionary, path: String = PATH) -> Error:
	if not validate(data, tiles):
		return ERR_INVALID_DATA
	var file: FileAccess = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_var(data, false)
	file.flush()
	var error: Error = file.get_error()
	file.close()
	if error != OK:
		return error
	# A corrupt primary must not overwrite the last known-good backup.
	if not _read_candidate(tiles, path).is_empty():
		error = DirAccess.copy_absolute(path, path + ".bak")
		if error != OK:
			return error
	return DirAccess.rename_absolute(path + ".tmp", path)

static func read_valid(tiles: Dictionary, path: String = PATH) -> Dictionary:
	for candidate in [path, path + ".bak"]:
		var data: Dictionary = _read_candidate(tiles, candidate)
		if not data.is_empty():
			return data
	return {}

static func list_slots(tiles: Dictionary, directory: String = SAVE_DIRECTORY, include_quicksave: bool = true) -> Array[Dictionary]:
	var paths: Dictionary = {}
	var dir: DirAccess = DirAccess.open(directory)
	if dir != null:
		for filename in dir.get_files():
			if filename.ends_with(".hds"):
				paths[directory.path_join(filename)] = true
			elif filename.ends_with(".hds.bak"):
				paths[directory.path_join(filename.trim_suffix(".bak"))] = true
	if include_quicksave and (FileAccess.file_exists(PATH) or FileAccess.file_exists(PATH + ".bak")):
		paths[PATH] = true
	var slots: Array[Dictionary] = []
	for path in paths:
		var data: Dictionary = read_valid(tiles, path)
		var stamp: int = int(data.get("saved_at", FileAccess.get_modified_time(path)))
		slots.append({"path": path, "name": String(data.get("save_name", "Legacy quicksave" if path == PATH else String(path).get_file().get_basename())),
			"saved_at": stamp, "valid": not data.is_empty(), "result": data.get("result", "unavailable")})
	slots.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["saved_at"] > b["saved_at"])
	return slots

static func write_slot(data: Dictionary, tiles: Dictionary, title: String, overwrite_path: String = "", directory: String = SAVE_DIRECTORY) -> Dictionary:
	var clean_title: String = title.strip_edges()
	if clean_title.is_empty() or clean_title.length() > 80:
		return {"error": ERR_INVALID_PARAMETER, "path": ""}
	var error: Error = DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return {"error": error, "path": ""}
	var path: String = overwrite_path
	if path.is_empty():
		# Names are metadata, never paths. Duplicate names are allowed as separate saves.
		path = directory.path_join("save_%d_%d.hds" % [int(Time.get_unix_time_from_system()), Time.get_ticks_usec()])
	elif path != PATH and (path.get_base_dir() != directory or not path.ends_with(".hds")):
		return {"error": ERR_INVALID_PARAMETER, "path": ""}
	var snapshot: Dictionary = data.duplicate(true)
	snapshot["save_name"] = clean_title
	snapshot["saved_at"] = int(Time.get_unix_time_from_system())
	error = write(snapshot, tiles, path)
	return {"error": error, "path": path}

static func _read_candidate(tiles: Dictionary, path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() < 4 or file.get_length() > 16000000:
		return {}
	# Check the Variant packet length before decoding a potentially truncated file.
	var packet_length: int = file.get_32()
	if packet_length != file.get_length() - 4:
		return {}
	file.seek(0)
	var data: Variant = file.get_var(false)
	file.close()
	return data if validate(data, tiles) else {}
