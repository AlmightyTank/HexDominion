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
var damage: float = 5.0
var cooldown: float = 0.25
var weapon_elapsed: float = 0.0
var damage_per_second: float:
	get: return damage / cooldown
	set(value): damage = value * cooldown
var attack_range: int = 1
var facing: float = 0.0
var turret_facing: float = 0.0
var domain: String = "ground"
var carrier: WeakRef
var airfield: Vector2i = Vector2i(-99999, -99999)
var air_mission: String = "ready"
var mission_remaining: float = 0.0
var tactical_order: Dictionary = {}
var guard_target: WeakRef
var supply_cargo: float = 0.0
var supply_task: String = "idle"
var supply_timer: float = 0.0
var assigned_deposit_id: String = ""
var assigned_center: Vector2i = Vector2i(-99999, -99999)
var delivery_route: Array[Vector2i] = []

func is_embarked() -> bool:
	return carrier != null and carrier.get_ref() != null

func is_deployed() -> bool:
	return is_alive() and not is_embarked()
var attack_order: bool = false
var attack_hex: Vector2i = Vector2i.ZERO
var attack_target: WeakRef
var shot_serial: int = 0
var last_shot_hex: Vector2i = Vector2i.ZERO
var attack_flash: float = 0.0
var damage_flash: float = 0.0


func configure_kind(unit_kind: String) -> void:
	if not UnitCatalog.TYPES.has(unit_kind):
		return
	kind = unit_kind
	var definition: Dictionary = UnitCatalog.TYPES[kind]
	max_health = definition["health"]
	health = max_health
	damage = definition["damage"]
	cooldown = definition["cooldown"]
	attack_range = definition["range"]
	seconds_per_hex = definition["speed"]
	domain = "naval" if UnitCatalog.is_naval(kind) else ("air" if UnitCatalog.is_air(kind) else "ground")
	weapon_elapsed = 0.0


func is_alive() -> bool:
	return health > 0.0


func _init(start: Vector2i = Vector2i.ZERO, unit_title: String = "Rifle squad") -> void:
	hex = start
	title = unit_title


func order_move(tiles: Dictionary, goal: Vector2i) -> bool:
	if not is_deployed():
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
	tactical_order = {}
	guard_target = null
	garrisoned = false
	holding = false
	attack_order = false
	attack_target = null
	if kind == "fighter":
		air_mission = "returning"
	return true

func order_hold() -> void:
	if not is_alive():
		return
	path.clear()
	tactical_order = {}
	guard_target = null
	progress = 0.0
	holding = true
	attack_order = false
	attack_target = null
	if kind == "fighter" and air_mission == "striking":
		air_mission = "returning"


func advance(delta: float, tiles: Dictionary) -> void:
	if is_embarked() or path.is_empty() or not is_finite(delta) or delta <= 0.0:
		return
	var remaining: float = delta
	while remaining > 0 and not path.is_empty():
		var heading: float = (HexMath.axial_to_world(path[0], 1.0) - HexMath.axial_to_world(hex, 1.0)).angle()
		facing = rotate_toward(facing, heading, remaining * 5.0) if domain == "air" else heading
		var cost: float = (1.0 if NavalRules.water(tiles, hex) and NavalRules.water(tiles, path[0]) else INF) if domain == "naval" else (1.0 if domain == "air" else TerrainRules.movement_cost(tiles, hex, path[0], kind))
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
