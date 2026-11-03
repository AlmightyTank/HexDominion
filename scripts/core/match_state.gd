extends RefCounted
class_name MatchState
## Small deterministic opponent: engage nearby enemies, otherwise capture toward HQ.
var player_hq: Vector2i
var rival_hq: Vector2i
var result: String = "playing"
var ai_countdown: float = 8.0
var rival_economy: EconomyState = EconomyState.new()

func _init() -> void:
	rival_economy.faction = 2

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

func advance_ai(delta: float, tiles: Dictionary, territory: TerritoryState, units: Array[UnitState]) -> void:
	if result != "playing" or delta <= 0.0:
		return
	ai_countdown -= delta
	if ai_countdown > 0.0:
		return
	ai_countdown = 1.0
	var roster_size: int = 0
	for unit in units:
		if unit.faction != 2 or not unit.is_alive():
			continue
		roster_size += 1
		if not unit.path.is_empty() or unit.garrisoned:
			continue
		var target: UnitState = null
		var nearest: int = 6
		for enemy in units:
			var distance: int = HexMath.distance(unit.hex, enemy.hex)
			if enemy.faction == 1 and enemy.is_alive() and distance < nearest:
				target = enemy
				nearest = distance
		if target != null and nearest <= unit.attack_range:
			continue # Hold position to fire; movement suppresses attacks.
		if target == null and territory.owner_at(unit.hex) != 2:
			continue # Finish the three-second capture before advancing.
		var goal: Vector2i = target.hex if target != null else player_hq
		var route: Array[Vector2i] = HexPathfinding.find_path(tiles, unit.hex, goal)
		if route.size() > 1:
			unit.order_move(tiles, route[1])
	var queued: int = 0
	for building in rival_economy.buildings.values():
		queued += building["queue"].size()
	if roster_size + queued < 8:
		for hex in rival_economy.buildings:
			if rival_economy.train(hex, "rifle", territory):
				break
