extends RefCounted
class_name SupplyNetwork

var supplied: Dictionary = {}
var road_supplied: Dictionary = {}
var rebuild_count: int = 0
var _signature: Dictionary = {}

func refresh(tiles: Dictionary, territory: TerritoryState, economy: EconomyState) -> void:
	# Inspect owned cells only. Rebuild graphs only when connectivity inputs change,
	# including direct dictionary edits made by capture, load and scenario setup.
	var cells: Dictionary = {}
	for hex in territory.owners:
		if territory.owner_at(hex) == economy.faction:
			cells[hex] = [territory.is_contested(hex), HexPathfinding.is_walkable(tiles, hex), RoadRules.has_road(tiles, hex), tiles.get(hex, {}).get("terrain", "")]
	var roots: Dictionary = {}
	var endpoints: Dictionary = {}
	for hex in cells:
		if tiles.get(hex, {}).get("terrain", "") == "city":
			endpoints[hex] = true
	for hex in economy.buildings:
		var site: Dictionary = economy.buildings[hex]
		if site["kind"] == "extractor":
			endpoints[hex] = true
		if site["kind"] == "headquarters" and EconomyState.is_complete(site) and site.get("health", EconomyState.BUILD_HEALTH["headquarters"]) > 0:
			roots[hex] = true
	var signature: Dictionary = {"cells": cells, "roots": roots, "endpoints": endpoints}
	if signature == _signature:
		return
	_signature = signature
	rebuild_count += 1
	supplied.clear()
	road_supplied.clear()
	var frontier: Array[Vector2i] = []
	for hex in roots:
		if _eligible(cells, hex):
			supplied[hex] = true
			frontier.append(hex)
	var index: int = 0
	while index < frontier.size():
		var current: Vector2i = frontier[index]
		index += 1
		for neighbor in HexMath.neighbors(current):
			if _eligible(cells, neighbor) and not supplied.has(neighbor):
				supplied[neighbor] = true
				frontier.append(neighbor)
	# Only road cells can carry road supply between endpoints. An unroaded city
	# may receive a bonus, but cannot bridge two otherwise separate highways.
	frontier.clear()
	var roads: Dictionary = {}
	for hex in roots:
		if not supplied.has(hex):
			continue
		if cells[hex][2]:
			road_supplied[hex] = true
			roads[hex] = true
			frontier.append(hex)
		for neighbor in HexMath.neighbors(hex):
			if _eligible(cells, neighbor) and cells[neighbor][2] and not roads.has(neighbor):
				road_supplied[hex] = true
				roads[neighbor] = true
				frontier.append(neighbor)
	index = 0
	while index < frontier.size():
		var current: Vector2i = frontier[index]
		index += 1
		road_supplied[current] = true
		for neighbor in HexMath.neighbors(current):
			if _eligible(cells, neighbor) and cells[neighbor][2] and not roads.has(neighbor):
				roads[neighbor] = true
				frontier.append(neighbor)
	for hex in endpoints:
		if not supplied.has(hex):
			continue
		for neighbor in HexMath.neighbors(hex):
			if roads.has(neighbor):
				road_supplied[hex] = true
				break

static func _eligible(cells: Dictionary, hex: Vector2i) -> bool:
	return cells.has(hex) and not cells[hex][0] and cells[hex][1]
