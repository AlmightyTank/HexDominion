extends RefCounted
class_name UnitCatalog
## Stable save IDs and shared tuning for simulation, production and presentation.
const INFANTRY: Array[String] = ["rifle", "rocket", "gunner"]
const COSTS: Dictionary = {"rifle": 50, "rocket": 85, "gunner": 75, "tank": 150, "scout": 80, "apc": 120, "anti_air": 140, "artillery": 200, "helicopter": 180, "fighter": 240}
const TRAIN_SECONDS: Dictionary = {"rifle": 4.0, "rocket": 6.0, "gunner": 5.0, "tank": 8.0, "scout": 4.0, "apc": 6.0, "anti_air": 7.0, "artillery": 10.0, "helicopter": 9.0, "fighter": 12.0}
const TYPES: Dictionary = {
	"rifle": {"name": "Rifleman", "health": 100.0, "speed": 0.45, "damage": 5.0, "range": 1, "cooldown": 0.25, "infantry": 1.0, "armor": 1.0, "marker": "R", "appearance": "soldier"},
	"rocket": {"name": "Rocket Soldier", "health": 90.0, "speed": 0.60, "damage": 18.0, "range": 2, "cooldown": 1.5, "infantry": 0.5, "armor": 4.0, "marker": "AT", "appearance": "soldier"},
	"gunner": {"name": "Machine Gunner", "health": 120.0, "speed": 0.55, "damage": 14.0, "range": 1, "cooldown": 0.5, "infantry": 1.0, "armor": 0.35, "marker": "MG", "appearance": "soldier"},
	"tank": {"name": "Main battle tank", "health": 250.0, "speed": 0.65, "damage": 22.5, "range": 1, "cooldown": 0.5, "infantry": 0.5, "armor": 1.5, "marker": "MBT", "appearance": "tracked"},
	"scout": {"name": "Scout Vehicle", "health": 100.0, "speed": 0.30, "damage": 4.0, "range": 1, "cooldown": 0.2, "infantry": 1.0, "armor": 0.3, "marker": "SC", "appearance": "wheeled"},
	"apc": {"name": "Armored Personnel Carrier", "health": 200.0, "speed": 0.50, "damage": 4.0, "range": 1, "cooldown": 0.4, "infantry": 0.8, "armor": 0.25, "marker": "APC", "appearance": "transport"},
	"anti_air": {"name": "Mobile Anti-Air", "health": 180.0, "speed": 0.60, "damage": 10.0, "range": 3, "cooldown": 0.8, "infantry": 0.4, "armor": 0.15, "marker": "AA", "appearance": "launcher"},
	"artillery": {"name": "Self-Propelled Artillery", "health": 110.0, "speed": 0.95, "damage": 45.0, "range": 3, "cooldown": 3.0, "infantry": 0.6, "armor": 0.5, "structure": 3.0, "capture": false, "marker": "SPG", "appearance": "siege"},
	"helicopter": {"name": "Attack Helicopter", "health": 140.0, "speed": 0.32, "damage": 16.0, "range": 2, "cooldown": 0.8, "infantry": 1.0, "armor": 1.5, "capture": false, "marker": "HEL", "appearance": "rotor"},
	"fighter": {"name": "Fighter Jet", "health": 120.0, "speed": 0.16, "damage": 70.0, "range": 2, "cooldown": 0.5, "mission_cooldown": 8.0, "infantry": 0.8, "armor": 1.5, "structure": 1.5, "capture": false, "marker": "JET", "appearance": "jet"}
}

static func is_air(kind: String) -> bool:
	return kind in ["helicopter", "fighter"]

static func is_infantry(kind: String) -> bool:
	return kind in INFANTRY

static func producer(kind: String) -> String:
	return "airfield" if is_air(kind) else ("barracks" if is_infantry(kind) else "factory")

static func counter(attacker: String, target: String) -> float:
	return TYPES[attacker]["infantry" if is_infantry(target) else "armor"]

static func can_target(attacker: UnitState, target: UnitState) -> bool:
	return target.domain == "ground" or ((attacker.kind == "anti_air" or attacker.kind == "fighter") and target.domain == "air")
