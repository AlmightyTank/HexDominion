extends RefCounted
class_name MatchState
## Deterministic opponent with separate economic and military priorities.
var player_hq: Vector2i
var rival_hq: Vector2i
var result: String = "playing"
var difficulty: String = AIDifficulty.EASY
var ai_countdown: float = AIDifficulty.opening_delay(AIDifficulty.EASY)
var rival_economy: EconomyState = EconomyState.new()
var combined_arms: CombinedArmsAI = CombinedArmsAI.new()

func _init() -> void:
	rival_economy.faction = 2


func set_difficulty(value: String, restart_grace: bool = true) -> bool:
	if not AIDifficulty.is_valid(value):
		return false
	if difficulty == value:
		return true
	difficulty = value
	if restart_grace:
		ai_countdown = AIDifficulty.opening_delay(value)
	return true

func evaluate(territory: TerritoryState) -> void:
	if result != "playing":
		return
	# Simultaneous HQ loss is a draw, not dependent on roster iteration order.
	var lost: bool = territory.owner_at(player_hq) == 2
	var won: bool = territory.owner_at(rival_hq) == 1
	if lost and won:
		result = "draw"
	elif lost:
		result = "defeat"
	elif won:
		result = "victory"

func advance_ai(delta: float, tiles: Dictionary, territory: TerritoryState, units: Array[UnitState], other_buildings: Dictionary = {}, oil: OilDerrickNetwork = null) -> void:
	if result != "playing" or not is_finite(delta) or delta <= 0.0:
		return
	ai_countdown -= delta
	if ai_countdown > 0.0:
		return
	ai_countdown = AIDifficulty.think_interval(difficulty)
	RivalEconomyAI.plan(rival_economy, tiles, territory, units, other_buildings, rival_hq, player_hq, difficulty)
	var defenders: Dictionary = DefenseAI.plan(rival_economy, tiles, territory, units, other_buildings, rival_hq, difficulty)
	var profile: Dictionary = AIDifficulty.profile(difficulty)
	var roster_size: int = 0
	for unit in units:
		if unit.faction != 2 or not unit.is_deployed():
			continue
		roster_size += 1
		if combined_arms.command(unit, units, rival_economy, territory, tiles, other_buildings, player_hq):
			continue
		if defenders.has(unit) or not unit.path.is_empty():
			continue
		if unit.holding or unit.garrisoned:
			unit.holding = false
			unit.garrisoned = false
		var target: UnitState = null
		var nearest: int = int(profile["target_search_radius"])
		for enemy in units:
			var distance: int = HexMath.distance(unit.hex, enemy.hex)
			if enemy.faction == 1 and enemy.is_deployed() and distance < nearest:
				target = enemy
				nearest = distance
		if target != null and nearest <= unit.attack_range:
			continue # Hold position to fire; movement suppresses attacks.
		var attacking_structure: bool = false
		if target == null:
			for hex in other_buildings:
				if HexMath.distance(unit.hex, hex) <= unit.attack_range:
					attacking_structure = true
					break
		if attacking_structure:
			continue
		if target == null and oil != null and UnitCatalog.is_infantry(unit.kind):
			var oil_goal: Variant = oil.capture_goal(unit.hex, unit.faction, tiles)
			if oil_goal != null:
				if oil_goal == unit.hex:
					continue
				var oil_route: Array[Vector2i] = HexPathfinding.find_path(tiles, unit.hex, oil_goal, unit.kind)
				if oil_route.size() > 1:
					unit.order_move(tiles, oil_route[1])
					continue
		if target == null and territory.owner_at(unit.hex) != 2:
			continue # Finish the three-second capture before advancing.
		var goal: Vector2i = target.hex if target != null else DefenseAI.weak_target(unit.hex, player_hq, other_buildings, units, 2)
		if target == null and roster_size == 1:
			goal = RivalEconomyAI.expansion_goal(unit.hex, rival_hq, tiles, territory, rival_economy)
			if goal == unit.hex:
				goal = player_hq
		var route: Array[Vector2i] = HexPathfinding.find_path(tiles, unit.hex, goal, unit.kind)
		if route.size() > 1:
			unit.order_move(tiles, route[1])
