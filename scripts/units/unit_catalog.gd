extends RefCounted
class_name UnitCatalog
## Stable save IDs and shared tuning for simulation, production and presentation.
const INFANTRY: Array[String] = ["rifle", "rocket", "gunner"]
const COSTS: Dictionary = {"rifle": 50, "rocket": 85, "gunner": 75, "tank": 150}
const TRAIN_SECONDS: Dictionary = {"rifle": 4.0, "rocket": 6.0, "gunner": 5.0, "tank": 8.0}
const TYPES: Dictionary = {
	"rifle": {"name": "Rifleman", "health": 100.0, "speed": 0.45, "damage": 5.0, "range": 1, "cooldown": 0.25, "infantry": 1.0, "armor": 1.0, "marker": "R", "appearance": "soldier"},
	"rocket": {"name": "Rocket Soldier", "health": 90.0, "speed": 0.60, "damage": 18.0, "range": 2, "cooldown": 1.5, "infantry": 0.5, "armor": 4.0, "marker": "AT", "appearance": "soldier"},
	"gunner": {"name": "Machine Gunner", "health": 120.0, "speed": 0.55, "damage": 14.0, "range": 1, "cooldown": 0.5, "infantry": 1.0, "armor": 0.35, "marker": "MG", "appearance": "soldier"},
	"tank": {"name": "Main battle tank", "health": 250.0, "speed": 0.65, "damage": 22.5, "range": 1, "cooldown": 0.5, "infantry": 1.0, "armor": 1.0, "marker": "ARM", "appearance": "tracked"}
}

static func is_infantry(kind: String) -> bool:
	return kind in INFANTRY

static func producer(kind: String) -> String:
	return "barracks" if is_infantry(kind) else "factory"

static func counter(attacker: String, target: String) -> float:
	return TYPES[attacker]["infantry" if is_infantry(target) else "armor"]
