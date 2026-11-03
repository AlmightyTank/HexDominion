extends RefCounted
class_name TerritoryState
## Sparse ownership separate from cached terrain. Zero is neutral.
const CAPTURE_SECONDS: float = 3.0
var continents: ContinentControl = ContinentControl.new()
var owners: Dictionary = {}:
	set(value):
		owners = value
		continents.recount(owners)
var captures: Dictionary = {}
var contested: Dictionary = {}

func owner_at(hex: Vector2i) -> int:
	return owners.get(hex, 0)

func set_owner(hex: Vector2i, faction: int) -> void:
	var previous: int = owner_at(hex)
	owners[hex] = faction
	continents.ownership_changed(hex, previous, faction)

func is_contested(hex: Vector2i) -> bool:
	return contested.has(hex) or captures.has(hex)

func advance(delta: float, tiles: Dictionary, units: Array[UnitState]) -> void:
	if delta <= 0.0:
		return
	var occupants: Dictionary = {}
	contested.clear()
	for unit in units:
		if not unit.is_alive() or not unit.path.is_empty() or not HexPathfinding.is_walkable(tiles, unit.hex):
			continue
		if not tiles[unit.hex].get("capturable", true):
			continue
		if not occupants.has(unit.hex):
			occupants[unit.hex] = {}
		occupants[unit.hex][unit.faction] = true
	for hex in captures.keys():
		if not occupants.has(hex):
			captures.erase(hex)
	for hex in occupants:
		var factions: Dictionary = occupants[hex]
		for present_faction in factions:
			if present_faction != owner_at(hex):
				contested[hex] = true
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
			set_owner(hex, faction)
			captures.erase(hex)
			contested.erase(hex)
		else:
			captures[hex] = capture
