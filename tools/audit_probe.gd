extends SceneTree
## Temporary audit probe: measures order-update cost and the AI production policy.
## Not part of the shipped test suite.

func make(kind: String, hex: Vector2i, faction: int = 1) -> UnitState:
	var unit: UnitState = UnitState.new(hex)
	unit.configure_kind(kind)
	unit.faction = faction
	return unit

func land_map(width: int) -> Dictionary:
	var tiles: Dictionary = {}
	for q in width:
		for r in range(-2, 3):
			tiles[Vector2i(q, r)] = {"is_land": true, "terrain": "plains"}
	return tiles

func split_map() -> Dictionary:
	var tiles: Dictionary = {}
	for q in range(0, 30):
		for r in range(-2, 3):
			var land: bool = q <= 5 or q >= 20
			tiles[Vector2i(q, r)] = {"is_land": land, "terrain": "plains" if land else "ocean"}
	return tiles

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	_perf()
	_ai()
	quit(0)

func _perf() -> void:
	var tiles: Dictionary = land_map(60)
	var economy: EconomyState = EconomyState.new(0)
	var enemy: EconomyState = EconomyState.new(0)
	enemy.faction = 2
	var economies: Array[EconomyState] = [economy, enemy]
	for size in [50, 200, 520]:
		var roster: Array[UnitState] = []
		for index in size:
			var hex: Vector2i = Vector2i(index % 60, -2 + (index / 60) % 5)
			roster.append(make("rifle", hex, 1))
		for index in size:
			var unit: UnitState = roster[index]
			var goal: Vector2i = Vector2i((index + 30) % 60, -2 + (index / 60) % 5)
			UnitOrders.tactical(unit, "attack_move", goal, tiles)
		var start: int = Time.get_ticks_usec()
		var runs: int = 30
		for step in runs:
			UnitOrders.update(roster, tiles, economies)
		var elapsed: int = Time.get_ticks_usec() - start
		print("PERF orders_update n=%d total_us=%d per_call_us=%d" % [size, elapsed, elapsed / runs])
		for unit in roster:
			unit.tactical_order = {}
		start = Time.get_ticks_usec()
		for step in runs:
			UnitOrders.update(roster, tiles, economies)
		elapsed = Time.get_ticks_usec() - start
		print("PERF orders_update_no_orders n=%d total_us=%d per_call_us=%d" % [size, elapsed, elapsed / runs])
		var presentation: ArmyPresentation = ArmyPresentation.new()
		start = Time.get_ticks_usec()
		for step in runs:
			presentation.refresh(roster)
		elapsed = Time.get_ticks_usec() - start
		print("PERF army_refresh_cached n=%d total_us=%d per_call_us=%d" % [size, elapsed, elapsed / runs])
		start = Time.get_ticks_usec()
		for step in runs:
			var fresh: ArmyPresentation = ArmyPresentation.new()
			fresh.refresh(roster)
		elapsed = Time.get_ticks_usec() - start
		print("PERF army_refresh_rebuild n=%d total_us=%d per_call_us=%d" % [size, elapsed, elapsed / runs])
		start = Time.get_ticks_usec()
		for step in runs:
			var counts: Dictionary = {}
			for unit in roster:
				var order: String = unit.tactical_order.get("mode", "attack" if unit.attack_order else ("hold" if unit.holding else "move"))
				counts[order] = counts.get(order, 0) + 1
			var labels: PackedStringArray = []
			for order in counts:
				labels.append("%s: %d" % [order.replace("_", " "), counts[order]])
			var text: String = "Orders: " + ", ".join(labels)
		elapsed = Time.get_ticks_usec() - start
		print("PERF order_summary n=%d total_us=%d per_call_us=%d" % [size, elapsed, elapsed / runs])

func _ai() -> void:
	var tiles: Dictionary = split_map()
	var territory: TerritoryState = TerritoryState.new()
	for hex in tiles:
		territory.set_owner(hex, 2)
	var rival_hq: Vector2i = Vector2i(0, 0)
	var player_hq: Vector2i = Vector2i(24, 0)
	var near_hq: Vector2i = Vector2i(4, 0)
	for hex in [player_hq, near_hq]:
		territory.set_owner(hex, 1)
	_run_ai(tiles, territory, rival_hq, near_hq, "reachable_hook_off", false, 900)
	_run_ai(tiles, territory, rival_hq, near_hq, "reachable_hook_on", true, 900)
	_run_ai(tiles, territory, rival_hq, player_hq, "overseas_hook_on", true, 900)

func _run_ai(tiles: Dictionary, territory: TerritoryState, rival_hq: Vector2i, objective: Vector2i, label: String, use_hook: bool, ticks: int) -> void:
	var economy: EconomyState = EconomyState.new(800)
	economy.faction = 2
	economy.add_building(rival_hq, "headquarters")
	economy.add_building(Vector2i(1, 0), "barracks")
	economy.add_building(Vector2i(2, 0), "power_plant")
	economy.add_building(Vector2i(3, 0), "factory")
	var units: Array[UnitState] = []
	for index in 3:
		units.append(make("rifle", Vector2i(index, 1), 2))
	var other_buildings: Dictionary = {objective: {"kind": "headquarters"}}
	var produced: Dictionary = {}
	var idle_ticks: int = 0
	var capped_at: int = -1
	for tick in ticks:
		if use_hook:
			RivalEconomyAI.plan(economy, tiles, territory, units, other_buildings, rival_hq, objective)
		else:
			RivalEconomyAI.plan(economy, tiles, territory, units, other_buildings, rival_hq)
		var queued_before: int = 0
		for hex in economy.buildings:
			queued_before += economy.buildings[hex]["queue"].size()
		var recruits: Array[UnitState] = economy.advance(1.0, tiles, territory)
		for recruit in recruits:
			units.append(recruit)
			produced[recruit.kind] = produced.get(recruit.kind, 0) + 1
		var queued_after: int = 0
		for hex in economy.buildings:
			queued_after += economy.buildings[hex]["queue"].size()
		if units.size() + queued_after == units.size() + queued_before and recruits.is_empty():
			idle_ticks += 1
		if capped_at < 0 and units.size() >= 8:
			capped_at = tick
	print("AI case=%s produced=%s army=%d ticks_to_cap=%d idle_ticks=%d credits=%.0f buildings=%s" % [label, str(produced), units.size(), capped_at, idle_ticks, economy.credits, str(economy.buildings.keys())])
