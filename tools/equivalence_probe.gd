extends SceneTree
## Proves that a shared per-frame roster scan gives the same decisions as today's per-unit scan.
## The production code is untouched: the shared scan lives only in this probe's mirror.

const GROUND := ["rifle", "rocket", "gunner", "tank", "scout", "apc", "anti_air", "artillery"]
const NAVAL := ["patrol_boat", "destroyer", "landing_transport"]
const AIR := ["helicopter", "fighter"]
const TICKS := 40
const SCENARIOS := 60

var mirror_mismatch: int = 0
var scan_mismatch: int = 0
var index_mismatch: int = 0
var key_mismatch: int = 0
var compared: int = 0
var orders_accepted: int = 0
var units_total: int = 0
var first_failure: String = ""


class Scan:
	extends RefCounted
	## Mirror of the committed order engine, faithful line for line except for the scan strategy.

	static func update_per_unit(units: Array[UnitState], tiles: Dictionary, economies: Array[EconomyState]) -> void:
		for unit in units:
			tactical_per_unit(unit, units, tiles, economies)
			attack_half(unit, units, tiles, economies)

	static func update_shared(units: Array[UnitState], tiles: Dictionary, economies: Array[EconomyState]) -> void:
		var candidates: Array[UnitState] = []
		var sites: Array = []
		var wanted: bool = false
		for unit in units:
			if unit.is_deployed() and not unit.tactical_order.is_empty():
				wanted = true
				break
		if wanted:
			for unit in units:
				if unit.is_deployed():
					candidates.append(unit)
			for economy in economies:
				for hex in economy.buildings:
					sites.append({"faction": economy.faction, "hex": hex})
		for unit in units:
			tactical_shared(unit, units, tiles, economies, candidates, sites)
			attack_half(unit, units, tiles, economies)

	static func update_index(units: Array[UnitState], tiles: Dictionary, economies: Array[EconomyState]) -> void:
		var wanted: bool = false
		for unit in units:
			if unit.is_deployed() and not unit.tactical_order.is_empty():
				wanted = true
				break
		var index: Dictionary = {}
		if wanted:
			index = build_index(units, economies)
		for unit in units:
			tactical_index(unit, units, tiles, economies, index)
			attack_half(unit, units, tiles, economies)

	static func build_index(units: Array[UnitState], economies: Array[EconomyState]) -> Dictionary:
		var by_hex: Dictionary = {}
		for unit in units:
			if unit.is_deployed():
				if not by_hex.has(unit.hex):
					by_hex[unit.hex] = []
				by_hex[unit.hex].append(unit)
		var sites: Dictionary = {}
		for economy in economies:
			for hex in economy.buildings:
				if not sites.has(hex):
					sites[hex] = []
				sites[hex].append(economy.faction)
		return {"by_hex": by_hex, "sites": sites}

	static var _balls: Dictionary = {}
	static var _key_balls: Dictionary = {}

	## Integer hex keys keep the range query on flat integer arithmetic.
	static func key_of(hex: Vector2i) -> int:
		return hex.x * 20001 + hex.y

	static func key_ball(radius: int) -> PackedInt64Array:
		if _key_balls.has(radius):
			return _key_balls[radius]
		var deltas: PackedInt64Array = PackedInt64Array()
		for dq in range(-radius, radius + 1):
			for dr in range(-radius, radius + 1):
				if HexMath.distance(Vector2i.ZERO, Vector2i(dq, dr)) <= radius:
					deltas.append(dq * 20001 + dr)
		_key_balls[radius] = deltas
		return deltas

	static func build_key_index(units: Array[UnitState], economies: Array[EconomyState]) -> Dictionary:
		var by_key: Dictionary = {}
		for unit in units:
			if unit.is_deployed():
				var key: int = key_of(unit.hex)
				if not by_key.has(key):
					by_key[key] = []
				by_key[key].append(unit)
		var sites: Dictionary = {}
		for economy in economies:
			for hex in economy.buildings:
				var key: int = key_of(hex)
				if not sites.has(key):
					sites[key] = []
				sites[key].append(economy.faction)
		return {"by_key": by_key, "sites": sites}

	static func update_key_index(units: Array[UnitState], tiles: Dictionary, economies: Array[EconomyState]) -> void:
		var wanted: bool = false
		for unit in units:
			if unit.is_deployed() and not unit.tactical_order.is_empty():
				wanted = true
				break
		var index: Dictionary = {}
		if wanted:
			index = build_key_index(units, economies)
		for unit in units:
			tactical_key_index(unit, units, tiles, economies, index)
			attack_half(unit, units, tiles, economies)

	static func tactical_key_index(unit: UnitState, units: Array[UnitState], tiles: Dictionary, economies: Array[EconomyState], index: Dictionary) -> void:
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
			var by_key: Dictionary = index.get("by_key", {})
			var sites: Dictionary = index.get("sites", {})
			var checks_sites: bool = unit.kind not in ["patrol_boat", "landing_transport"]
			var base: int = key_of(unit.hex)
			for delta in key_ball(unit.attack_range):
				var key: int = base + delta
				if by_key.has(key):
					for enemy in by_key[key]:
						if enemy.faction != unit.faction and UnitCatalog.can_target(unit, enemy):
							threat = true
							break
				if threat:
					break
				if checks_sites and sites.has(key):
					for faction in sites[key]:
						if faction != unit.faction:
							threat = true
							break
				if threat:
					break
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
		route(unit, order["goal"], tiles)

	static func ball(radius: int) -> Array:
		if _balls.has(radius):
			return _balls[radius]
		var offsets: Array = []
		for dq in range(-radius, radius + 1):
			for dr in range(-radius, radius + 1):
				if HexMath.distance(Vector2i.ZERO, Vector2i(dq, dr)) <= radius:
					offsets.append(Vector2i(dq, dr))
		_balls[radius] = offsets
		return offsets

	static func index_threat(unit: UnitState, index: Dictionary) -> bool:
		var radius: int = unit.attack_range
		var by_hex: Dictionary = index.get("by_hex", {})
		var sites: Dictionary = index.get("sites", {})
		var center: Vector2i = unit.hex
		var checks_sites: bool = unit.kind not in ["patrol_boat", "landing_transport"]
		for offset in ball(radius):
			var hex: Vector2i = center + offset
			if by_hex.has(hex):
				for enemy in by_hex[hex]:
					if enemy.faction != unit.faction and UnitCatalog.can_target(unit, enemy):
						return true
			if checks_sites and sites.has(hex):
				for faction in sites[hex]:
					if faction != unit.faction:
						return true
		return false

	static func tactical_index(unit: UnitState, units: Array[UnitState], tiles: Dictionary, economies: Array[EconomyState], index: Dictionary) -> void:
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
			threat = index_threat(unit, index)
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
		route(unit, order["goal"], tiles)

	static func tactical_per_unit(unit: UnitState, units: Array[UnitState], tiles: Dictionary, economies: Array[EconomyState]) -> void:
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
		route(unit, order["goal"], tiles)

	static func tactical_shared(unit: UnitState, units: Array[UnitState], tiles: Dictionary, economies: Array[EconomyState], candidates: Array[UnitState], sites: Array) -> void:
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
			for enemy in candidates:
				if enemy.faction != unit.faction and UnitCatalog.can_target(unit, enemy) and HexMath.distance(unit.hex, enemy.hex) <= unit.attack_range:
					threat = true
					break
			if unit.kind not in ["patrol_boat", "landing_transport"]:
				for site in sites:
					if site["faction"] != unit.faction and HexMath.distance(unit.hex, site["hex"]) <= unit.attack_range:
						threat = true
						break
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
		route(unit, order["goal"], tiles)

	static func route(unit: UnitState, goal: Vector2i, tiles: Dictionary) -> bool:
		var order: Dictionary = unit.tactical_order
		var guard: WeakRef = unit.guard_target
		var accepted: bool = unit.order_move(tiles, goal)
		unit.tactical_order = order
		unit.guard_target = guard
		return accepted

	static func attack_half(unit: UnitState, units: Array[UnitState], tiles: Dictionary, economies: Array[EconomyState]) -> void:
		if not unit.is_deployed() or not unit.attack_order:
			return
		var target: UnitState = unit.attack_target.get_ref() if unit.attack_target != null else null
		var valid: bool = false
		if unit.attack_target != null:
			valid = target != null and target.is_deployed() and target.faction != unit.faction and units.has(target) and UnitCatalog.can_target(unit, target)
		else:
			for economy in economies:
				valid = valid or (economy.faction != unit.faction and economy.buildings.has(unit.attack_hex))
		if not valid:
			unit.order_hold()
			return
		if target != null and target.hex != unit.attack_hex:
			if unit.kind == "fighter":
				unit.air_mission = "ready"
			UnitOrders.attack(unit, tiles, target.hex, target)
		UnitOrders._trim_route(unit)


func _initialize() -> void:
	call_deferred("run")


func build_tiles() -> Dictionary:
	var tiles: Dictionary = {}
	for q in range(16):
		for r in range(9):
			tiles[Vector2i(q, r)] = {"is_land": r < 6, "terrain": "plains" if r < 6 else "ocean"}
	return tiles


func make_unit(kind: String, hex: Vector2i, faction: int) -> UnitState:
	var unit: UnitState = UnitState.new(hex, kind)
	unit.configure_kind(kind)
	unit.faction = faction
	return unit


func land_hex(rng: RandomNumberGenerator) -> Vector2i:
	return Vector2i(rng.randi_range(0, 15), rng.randi_range(0, 5))


func water_hex(rng: RandomNumberGenerator) -> Vector2i:
	return Vector2i(rng.randi_range(0, 15), rng.randi_range(6, 8))


func build_copy(specs: Array, tiles: Dictionary) -> Array[UnitState]:
	var units: Array[UnitState] = []
	for spec in specs:
		units.append(make_unit(spec["kind"], spec["hex"], spec["faction"]))
	for index in specs.size():
		var spec: Dictionary = specs[index]
		var mode: String = spec["mode"]
		if mode == "none":
			continue
		var target: UnitState = null
		if mode == "guard":
			target = units[spec["guard"]]
		if mode == "patrol":
			var points: Array[Vector2i] = []
			for point in spec["points"]:
				points.append(point)
			if UnitOrders.tactical(units[index], mode, spec["goal"], tiles, target, points):
				orders_accepted += 1
		elif UnitOrders.tactical(units[index], mode, spec["goal"], tiles, target):
			orders_accepted += 1
	return units


func fingerprint(units: Array[UnitState]) -> String:
	var parts: PackedStringArray = []
	for unit in units:
		var guard: String = "-"
		if unit.guard_target != null:
			var guarded: UnitState = unit.guard_target.get_ref()
			guard = "-" if guarded == null else "%s@%s" % [guarded.kind, str(guarded.hex)]
		parts.append("%s|%s|%s|%s|%s|%s|%s|%.4f|%s" % [unit.kind, str(unit.hex), str(unit.path), str(unit.tactical_order), unit.holding, unit.attack_order, str(unit.attack_hex), unit.progress, guard])
	return "\n".join(parts)


func build_specs(rng: RandomNumberGenerator) -> Array:
	var specs: Array = []
	var kinds: Array = []
	for kind in GROUND:
		kinds.append(kind)
	for kind in NAVAL:
		kinds.append(kind)
	for kind in AIR:
		kinds.append(kind)
	var count: int = rng.randi_range(14, 26)
	for index in count:
		var kind: String = kinds[rng.randi_range(0, kinds.size() - 1)]
		var hex: Vector2i = land_hex(rng)
		if UnitCatalog.is_naval(kind):
			hex = water_hex(rng)
		specs.append({"kind": kind, "hex": hex, "faction": 1 if index % 2 == 0 else 2, "mode": "none", "goal": hex, "points": [], "guard": 0})
	for index in specs.size():
		var spec: Dictionary = specs[index]
		var mode: String = ["attack_move", "guard", "patrol", "none"][rng.randi_range(0, 3)]
		var hex: Vector2i = spec["hex"]
		var goal: Vector2i = hex
		if UnitCatalog.is_naval(spec["kind"]):
			goal = water_hex(rng)
		else:
			goal = land_hex(rng)
		var points: Array[Vector2i] = []
		if mode == "patrol":
			points.append(hex)
			points.append(Vector2i(clampi(hex.x + rng.randi_range(-2, 2), 0, 15), clampi(hex.y + rng.randi_range(-1, 1), 0, 5)))
			points.append(Vector2i(clampi(hex.x + rng.randi_range(-2, 2), 0, 15), clampi(hex.y + rng.randi_range(-1, 1), 0, 5)))
		var guard_index: int = 0
		if mode == "guard":
			guard_index = rng.randi_range(0, specs.size() - 1)
			while specs[guard_index]["faction"] != spec["faction"] or guard_index == index:
				guard_index = (guard_index + 1) % specs.size()
			goal = specs[guard_index]["hex"]
		spec["mode"] = mode
		spec["goal"] = goal
		spec["points"] = points
		spec["guard"] = guard_index
	return specs


func run() -> void:
	var tiles: Dictionary = build_tiles()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 20261104
	for scenario in SCENARIOS:
		var specs: Array = build_specs(rng)
		units_total += specs.size()
		var economy: EconomyState = EconomyState.new(1000)
		economy.faction = 1
		economy.add_building(Vector2i(0, 0), "headquarters")
		economy.add_building(Vector2i(15, 5), "headquarters")
		var rival: EconomyState = EconomyState.new(1000)
		rival.faction = 2
		rival.add_building(Vector2i(8, 2), "bunker")
		rival.add_building(Vector2i(2, 4), "bunker")
		var economies: Array[EconomyState] = [economy, rival]
		var production: Array[UnitState] = build_copy(specs, tiles)
		var mirror: Array[UnitState] = build_copy(specs, tiles)
		var shared: Array[UnitState] = build_copy(specs, tiles)
		var indexed: Array[UnitState] = build_copy(specs, tiles)
		var keyed: Array[UnitState] = build_copy(specs, tiles)
		for tick in TICKS:
			for unit in production:
				unit.advance(0.05, tiles)
			for unit in mirror:
				unit.advance(0.05, tiles)
			for unit in shared:
				unit.advance(0.05, tiles)
			for unit in indexed:
				unit.advance(0.05, tiles)
			for unit in keyed:
				unit.advance(0.05, tiles)
			if tick % 7 == 3 and production.size() > 2:
				var doomed: int = rng.randi_range(0, production.size() - 1)
				production[doomed].health = 0.0
				mirror[doomed].health = 0.0
				shared[doomed].health = 0.0
				indexed[doomed].health = 0.0
				keyed[doomed].health = 0.0
			UnitOrders.update(production, tiles, economies)
			Scan.update_per_unit(mirror, tiles, economies)
			Scan.update_shared(shared, tiles, economies)
			Scan.update_index(indexed, tiles, economies)
			Scan.update_key_index(keyed, tiles, economies)
			compared += 1
			var left: String = fingerprint(production)
			var middle: String = fingerprint(mirror)
			var right: String = fingerprint(shared)
			var last: String = fingerprint(indexed)
			var final: String = fingerprint(keyed)
			if left != middle:
				mirror_mismatch += 1
				if first_failure.is_empty():
					first_failure = "scenario %d tick %d: mirror copy diverged from production" % [scenario, tick]
			elif middle != right:
				scan_mismatch += 1
				if first_failure.is_empty():
					first_failure = "scenario %d tick %d: shared scan diverged from per-unit scan" % [scenario, tick]
			elif right != last:
				index_mismatch += 1
				if first_failure.is_empty():
					first_failure = "scenario %d tick %d: spatial index diverged from per-unit scan" % [scenario, tick]
			elif last != final:
				key_mismatch += 1
				if first_failure.is_empty():
					first_failure = "scenario %d tick %d: integer key index diverged from per-unit scan" % [scenario, tick]
	_report()
	benchmark()
	quit(1 if mirror_mismatch > 0 or scan_mismatch > 0 or index_mismatch > 0 or key_mismatch > 0 else 0)


func _report() -> void:
	print("Equivalence probe: %d scenarios x %d ticks = %d compared frames" % [SCENARIOS, TICKS, compared])
	print("Units generated: %d, tactical orders accepted: %d" % [units_total, orders_accepted])
	print("Mirror vs production mismatches: %d" % mirror_mismatch)
	print("Shared scan vs per-unit scan mismatches: %d" % scan_mismatch)
	print("Spatial index vs per-unit scan mismatches: %d" % index_mismatch)
	print("Integer key index vs per-unit scan mismatches: %d" % key_mismatch)
	if not first_failure.is_empty():
		print("First failure: %s" % first_failure)


func benchmark() -> void:
	## Times each scan strategy on a full army so the fix's benefit is measured, not assumed.
	var tiles: Dictionary = build_tiles()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 99
	var specs: Array = build_specs(rng)
	while specs.size() < 520:
		var index: int = specs.size()
		specs.append({"kind": GROUND[index % GROUND.size()], "hex": land_hex(rng), "faction": 1 if index % 2 == 0 else 2, "mode": "attack_move", "goal": land_hex(rng), "points": [], "guard": 0})
	_run_benchmark("mixed_factions", specs, tiles, true)
	var solo: Array = specs.duplicate(true)
	for spec in solo:
		spec["faction"] = 1
	_run_benchmark("no_enemy", solo, tiles, false)


func _run_benchmark(label: String, specs: Array, tiles: Dictionary, with_buildings: bool) -> void:
	var economy: EconomyState = EconomyState.new(1000)
	economy.faction = 1
	var rival: EconomyState = EconomyState.new(1000)
	rival.faction = 2
	if with_buildings:
		economy.add_building(Vector2i(0, 0), "headquarters")
		rival.add_building(Vector2i(8, 2), "bunker")
	var economies: Array[EconomyState] = [economy, rival]
	for strategy in ["per_unit", "shared", "index", "key_index"]:
		var roster: Array[UnitState] = build_copy(specs, tiles)
		var start: int = Time.get_ticks_usec()
		for iteration in 20:
			if strategy == "per_unit":
				Scan.update_per_unit(roster, tiles, economies)
			elif strategy == "shared":
				Scan.update_shared(roster, tiles, economies)
			elif strategy == "index":
				Scan.update_index(roster, tiles, economies)
			else:
				Scan.update_key_index(roster, tiles, economies)
		var elapsed: int = (Time.get_ticks_usec() - start) / 20
		print("condition=%s scan=%s units=%d per_frame=%d us" % [label, strategy, roster.size(), elapsed])
		if strategy == "index":
			var build_start: int = Time.get_ticks_usec()
			for iteration in 20:
				Scan.build_index(roster, economies)
			print("condition=%s index_build_only=%d us" % [label, (Time.get_ticks_usec() - build_start) / 20])
