extends RefCounted
class_name UnitState
## Simulation only; presentation interpolates between the current and next hex.

var hex: Vector2i
var path: Array[Vector2i] = []
var progress: float = 0.0
var seconds_per_hex: float = 0.45
var title: String
var faction: int = 1
var garrisoned: bool = false
var holding: bool = false
var kind: String = "rifle"
var max_health: float = 100.0
var health: float = 100.0
var damage_per_second: float = 20.0
var attack_range: int = 1


func configure_kind(unit_kind: String) -> void:
	kind = unit_kind
	max_health = 250.0 if kind == "tank" else 100.0
	health = max_health
	damage_per_second = 45.0 if kind == "tank" else 20.0
	seconds_per_hex = 0.65 if kind == "tank" else 0.45


func is_alive() -> bool:
	return health > 0.0


func _init(start: Vector2i = Vector2i.ZERO, unit_title: String = "Rifle squad") -> void:
	hex = start
	title = unit_title


func order_move(tiles: Dictionary, goal: Vector2i) -> bool:
	if not is_alive():
		return false
	# Commit the in-flight edge before following a replacement route: no teleporting.
	var start: Vector2i = path[0] if progress > 0.0 and not path.is_empty() else hex
	var route: Array[Vector2i] = HexPathfinding.find_path(tiles, start, goal, kind)
	if route.is_empty():
		return false
	route.pop_front()
	if start != hex:
		route.push_front(start)
	else:
		progress = 0.0
	path = route
	garrisoned = false
	holding = false
	return true

func order_hold() -> void:
	if not is_alive():
		return
	path.clear()
	progress = 0.0
	holding = true


func advance(delta: float, tiles: Dictionary) -> void:
	if path.is_empty() or not is_finite(delta) or delta <= 0.0:
		return
	var remaining: float = delta
	while remaining > 0 and not path.is_empty():
		var cost: float = TerrainRules.movement_cost(tiles, hex, path[0], kind)
		if not is_finite(cost):
			return
		var duration: float = maxf(seconds_per_hex, 0.001) * cost
		var needed: float = (1.0 - progress) * duration
		if remaining + 0.000000001 < needed:
			progress += remaining / duration
			return
		remaining = maxf(0.0, remaining - needed)
		hex = path.pop_front()
		progress = 0.0
	if path.is_empty():
		progress = 0.0
