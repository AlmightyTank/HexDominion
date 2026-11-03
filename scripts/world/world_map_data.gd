extends RefCounted
class_name WorldMapData
## Deterministic, data-driven hex world. No scene nodes or gameplay state required.
## World definition coordinates use normalized [0, 1] X/Y in map space.

const DEFINITION_PATH: String = "res://data/world/earth_regions.json"
const RIVER_PATH: String = "res://data/world/earth_rivers.geojson"
const TERRAIN_TYPES: Array[String] = ["ocean", "plains", "forest", "desert", "mountain", "snow", "tundra", "city", "resource"]


static func offset_to_axial(column: int, row: int) -> Vector2i:
	# Odd-r horizontal layout of pointy-top hexagons.
	return Vector2i(column - int((row - (row & 1)) / 2), row)


static func axial_to_offset(axial: Vector2i) -> Vector2i:
	return Vector2i(axial.x + int((axial.y - (axial.y & 1)) / 2), axial.y)


static func load_definition() -> Dictionary:
	if not FileAccess.file_exists(DEFINITION_PATH):
		push_error("Missing world definition: %s" % DEFINITION_PATH)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DEFINITION_PATH))
	if not parsed is Dictionary:
		push_error("Invalid world definition JSON: %s" % DEFINITION_PATH)
		return {}
	return parsed


static func build(columns: int, rows: int) -> Dictionary:
	assert(columns > 0 and rows > 0, "World size must be positive")
	var definition: Dictionary = load_definition()
	if definition.is_empty():
		return {}
	var tiles: Dictionary = {}
	var counts: Dictionary = {}
	var continents: Array = definition.get("continents", [])
	var biomes: Array = definition.get("biomes", [])
	for region in continents + biomes:
		region["prepared"] = _prepare_polygons(region.get("polygons", []))
	for row in range(rows):
		for column in range(columns):
			var uv: Vector2 = cell_uv(column, row, columns, rows)
			var axial: Vector2i = offset_to_axial(column, row)
			var continent_name: String = "Open Ocean"
			for continent in continents:
				if _inside_prepared(uv, continent["prepared"]):
					continent_name = String(continent.get("name", "Unknown"))
					break
			var terrain: String = "ocean"
			if continent_name != "Open Ocean":
				terrain = "plains"
				for biome in biomes:
					if _inside_prepared(uv, biome["prepared"]):
						terrain = String(biome.get("terrain", "plains"))
						break
			tiles[axial] = {
				"axial": axial,
				"column": column,
				"row": row,
				"terrain": terrain,
				"biome": terrain,
				"continent": continent_name,
				"site_name": "",
				"is_land": terrain != "ocean",
			}
	# Reserve the nearest unique land cell for each POI; never put a city at sea.
	for site in definition.get("sites", []):
		var goal: Vector2 = _pair_to_vector(site["at"])
		var nearest: Vector2i = Vector2i(-9999, -9999)
		var best_distance: float = INF
		for key in tiles:
			var tile: Dictionary = tiles[key]
			if not tile["is_land"] or tile["site_name"] != "":
				continue
			var center: Vector2 = cell_uv(int(tile["column"]), int(tile["row"]), columns, rows)
			var distance_sq: float = center.distance_squared_to(goal)
			if distance_sq < best_distance:
				best_distance = distance_sq
				nearest = key
		if best_distance < 0.016:  # Ignore a site if its land is implausibly far away.
			var chosen: Dictionary = tiles[nearest]
			chosen["terrain"] = String(site["kind"])
			chosen["site_name"] = String(site["name"])
			tiles[nearest] = chosen
	_add_crossings(tiles, columns, rows)
	for tile in tiles.values():
		var terrain_name: String = tile["terrain"]
		counts[terrain_name] = int(counts.get(terrain_name, 0)) + 1
	return {"columns": columns, "rows": rows, "tiles": tiles, "terrain_counts": counts, "definition_name": String(definition.get("name", "World"))}

static func _add_crossings(tiles: Dictionary, columns: int, rows: int) -> void:
	for hex in tiles:
		if not tiles[hex]["is_land"]:
			continue
		var exits: int = 0
		for neighbor in HexMath.neighbors(hex):
			exits += int(HexPathfinding.is_walkable(tiles, neighbor))
		tiles[hex]["narrow_crossing"] = exits > 0 and exits <= 2
		tiles[hex]["river_neighbors"] = []
	var rivers: Variant = JSON.parse_string(FileAccess.get_file_as_string(RIVER_PATH))
	if not rivers is Dictionary:
		push_error("Missing or invalid bundled river data")
		return
	for feature in rivers.get("features", []):
		var geometry: Dictionary = feature.get("geometry", {})
		var lines: Array = geometry.get("coordinates", [])
		if geometry.get("type", "") == "LineString":
			lines = [lines]
		elif geometry.get("type", "") != "MultiLineString":
			continue
		for line in lines:
			for index in range(1, line.size()):
				var a: Vector2 = Vector2(0.5 + float(line[index - 1][0]) / 360.0, 0.5 - float(line[index - 1][1]) / 180.0)
				var b: Vector2 = Vector2(0.5 + float(line[index][0]) / 360.0, 0.5 - float(line[index][1]) / 180.0)
				if absf(a.x - b.x) > 0.5:
					continue # Do not draw a dateline-spanning segment across the world.
				var left: int = maxi(0, floori(minf(a.x, b.x) * (columns + 0.5)) - 2)
				var right: int = mini(columns - 1, ceili(maxf(a.x, b.x) * (columns + 0.5)) + 2)
				var top: int = maxi(0, floori(minf(a.y, b.y) * rows) - 2)
				var bottom: int = mini(rows - 1, ceili(maxf(a.y, b.y) * rows) + 2)
				for row in range(top, bottom + 1):
					for column in range(left, right + 1):
						var hex: Vector2i = offset_to_axial(column, row)
						if not tiles[hex]["is_land"]:
							continue
						var center: Vector2 = cell_uv(column, row, columns, rows)
						for neighbor in HexMath.neighbors(hex):
							if not HexPathfinding.is_walkable(tiles, neighbor) or neighbor in tiles[hex]["river_neighbors"]:
								continue
							var offset: Vector2i = axial_to_offset(neighbor)
							var destination: Vector2 = cell_uv(offset.x, offset.y, columns, rows)
							if Geometry2D.segment_intersects_segment(center, destination, a, b) != null:
								tiles[hex]["river_neighbors"].append(neighbor)
								tiles[neighbor]["river_neighbors"].append(hex)


static func cell_uv(column: int, row: int, columns: int, rows: int) -> Vector2:
	# Match the actual staggered hex centers, including half a cell at the edges.
	return Vector2((float(column) + 0.5 + 0.5 * float(row & 1)) / (float(columns) + 0.5), (float(row) + 0.5) / float(rows))


static func _prepare_polygons(polygons: Array) -> Array:
	var prepared: Array = []
	for polygon in polygons:
		var points: PackedVector2Array = PackedVector2Array()
		for pair in polygon:
			points.append(_pair_to_vector(pair))
		if points.size() < 3:
			continue
		var bounds: Rect2 = Rect2(points[0], Vector2.ZERO)
		for point in points:
			bounds = bounds.expand(point)
		prepared.append({"bounds": bounds.grow(0.000001), "points": points})
	return prepared


static func _inside_prepared(point: Vector2, polygons: Array) -> bool:
	for polygon in polygons:
		var bounds: Rect2 = polygon["bounds"]
		if bounds.has_point(point) and Geometry2D.is_point_in_polygon(point, polygon["points"]):
			return true
	return false


static func _pair_to_vector(pair: Array) -> Vector2:
	return Vector2(float(pair[0]), float(pair[1]))
