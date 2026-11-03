extends RefCounted
class_name ContinentControl
## Eligibility is fixed from the starting armies' land components, not current borders.
const BONUS: float = 0.1
var regions: Dictionary = {}
var membership: Dictionary = {}
var revision: int = 0

func configure(tiles: Dictionary, starts: Array[Vector2i], owners: Dictionary) -> void:
	regions.clear()
	membership.clear()
	var reached: Dictionary = {}
	var queue: Array[Vector2i] = []
	for hex in starts:
		if HexPathfinding.is_walkable(tiles, hex) and not reached.has(hex):
			reached[hex] = true
			queue.append(hex)
	var index: int = 0
	while index < queue.size():
		var hex: Vector2i = queue[index]
		index += 1
		for neighbor in HexMath.neighbors(hex):
			if not reached.has(neighbor) and HexPathfinding.is_walkable(tiles, neighbor):
				reached[neighbor] = true
				queue.append(neighbor)
	for hex in tiles:
		var tile: Dictionary = tiles[hex]
		if not tile.get("is_land", false):
			continue
		var region: String = tile.get("continent", "")
		if region.is_empty() or region == "Open Ocean":
			continue
		if not regions.has(region):
			regions[region] = {"total": 0, "excluded": 0, "counts": {}}
		if not reached.has(hex) or not tile.get("capturable", true):
			regions[region]["excluded"] += 1
			continue
		membership[hex] = region
		regions[region]["total"] += 1
	recount(owners)

func recount(owners: Dictionary) -> void:
	for region in regions.values():
		region["counts"] = {}
	for hex in membership:
		_change(hex, int(owners.get(hex, 0)), 1)
	revision += 1

func ownership_changed(hex: Vector2i, previous: int, current: int) -> void:
	if previous == current or not membership.has(hex):
		return
	_change(hex, previous, -1)
	_change(hex, current, 1)
	revision += 1

func _change(hex: Vector2i, faction: int, amount: int) -> void:
	if faction <= 0:
		return
	var counts: Dictionary = regions[membership[hex]]["counts"]
	counts[faction] = counts.get(faction, 0) + amount

func controller(name: String) -> int:
	var region: Dictionary = regions[name]
	if region["total"] > 0:
		for faction in region["counts"]:
			if region["counts"][faction] == region["total"]:
				return faction
	return 0

func bonus(faction: int) -> float:
	var completed: int = 0
	for name in regions:
		if faction > 0 and controller(name) == faction:
			completed += 1
	return completed * BONUS
