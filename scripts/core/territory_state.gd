extends RefCounted
class_name TerritoryState
## Sparse ownership separate from cached terrain. Zero is neutral.
const CAPTURE_SECONDS: float = 3.0
var owners: Dictionary = {}
var captures: Dictionary = {}

func owner_at(hex: Vector2i) -> int:
	return owners.get(hex, 0)

func advance(delta: float, tiles: Dictionary, units: Array[UnitState]) -> void:
	if delta <= 0.0:
		return
	var occupants: Dictionary = {}
	for unit in units:
		if not unit.is_alive() or not unit.path.is_empty() or not HexPathfinding.is_walkable(tiles, unit.hex):
			continue
		if not occupants.has(unit.hex):
			occupants[unit.hex] = {}
		occupants[unit.hex][unit.faction] = true
	for hex in captures.keys():
		if not occupants.has(hex):
			captures.erase(hex)
	for hex in occupants:
		var factions: Dictionary = occupants[hex]
		if factions.size() != 1:
			continue
		var faction: int = factions.keys()[0]
		if owner_at(hex) == faction:
			captures.erase(hex)
			continue
		var capture: Dictionary = captures.get(hex, {"faction": faction, "elapsed": 0.0})
		if capture["faction"] != faction:
			capture = {"faction": faction, "elapsed": 0.0}
		capture["elapsed"] += delta
		if capture["elapsed"] >= CAPTURE_SECONDS:
			owners[hex] = faction
			captures.erase(hex)
		else:
			captures[hex] = capture
