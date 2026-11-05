extends RefCounted
class_name UnitCatalog
## Stable save IDs and shared tuning for simulation, production and presentation.
const INFANTRY: Array[String] = ["rifle", "rocket", "gunner"]
const COSTS: Dictionary = {"rifle": 50, "rocket": 85, "gunner": 75, "tank": 150, "scout": 80, "apc": 120, "anti_air": 140, "artillery": 200, "helicopter": 180, "fighter": 240, "patrol_boat": 90, "destroyer": 300, "landing_transport": 180}
const TRAIN_SECONDS: Dictionary = {"rifle": 4.0, "rocket": 6.0, "gunner": 5.0, "tank": 8.0, "scout": 4.0, "apc": 6.0, "anti_air": 7.0, "artillery": 10.0, "helicopter": 9.0, "fighter": 12.0, "patrol_boat": 5.0, "destroyer": 14.0, "landing_transport": 9.0}
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
	"fighter": {"name": "Fighter Jet", "health": 120.0, "speed": 0.16, "damage": 70.0, "range": 2, "cooldown": 0.5, "mission_cooldown": 8.0, "infantry": 0.8, "armor": 1.5, "structure": 1.5, "capture": false, "marker": "JET", "appearance": "jet"},
	"patrol_boat": {"name": "Patrol Boat", "health": 130.0, "speed": 0.30, "damage": 12.0, "range": 2, "cooldown": 0.5, "infantry": 0.5, "armor": 0.5, "light_naval": 1.5, "capture": false, "marker": "PB", "appearance": "patrol"},
	"destroyer": {"name": "Destroyer", "health": 400.0, "speed": 0.65, "damage": 40.0, "range": 3, "cooldown": 1.5, "infantry": 1.0, "armor": 1.5, "capture": false, "marker": "DD", "appearance": "warship"},
	"landing_transport": {"name": "Landing Transport", "health": 280.0, "speed": 0.55, "damage": 0.0, "range": 0, "cooldown": 1.0, "infantry": 0.0, "armor": 0.0, "capacity": 8, "capture": false, "marker": "LC", "appearance": "landing"},
	"supply_truck": {"name": "Supply Truck", "health": 90.0, "speed": 0.35, "damage": 0.0, "range": 0, "cooldown": 1.0, "infantry": 0.0, "armor": 0.0, "capture": false, "marker": "SUP", "appearance": "wheeled"}
}

static func is_air(kind: String) -> bool:
	return kind in ["helicopter", "fighter"]

static func is_naval(kind: String) -> bool:
	return kind in ["patrol_boat", "destroyer", "landing_transport"]

static func is_infantry(kind: String) -> bool:
	return kind in INFANTRY

static func producer(kind: String) -> String:
	return "shipyard" if is_naval(kind) else ("airfield" if is_air(kind) else ("barracks" if is_infantry(kind) else "factory"))

static func counter(attacker: String, target: String) -> float:
	if target in ["patrol_boat", "landing_transport"]:
		return TYPES[attacker].get("light_naval", TYPES[attacker]["armor"])
	return TYPES[attacker]["infantry" if is_infantry(target) else "armor"]

static func can_target(attacker: UnitState, target: UnitState) -> bool:
	if attacker.kind in ["landing_transport", "supply_truck"] or (attacker.kind == "patrol_boat" and target.domain != "naval"):
		return false
	return target.domain in ["ground", "naval"] or ((attacker.kind == "anti_air" or attacker.kind == "fighter") and target.domain == "air")
