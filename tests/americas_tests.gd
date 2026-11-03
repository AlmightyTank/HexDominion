extends SceneTree


func _initialize() -> void:
	var world: Dictionary = WorldMapData.build(WorldMap.COLUMNS, WorldMap.ROWS)
	var tiles: Dictionary = world["tiles"]
	var endpoints: Array[Vector2i] = []
	for location in [Vector2(-99.1, 19.4), Vector2(-74.1, 4.7)]:
		var uv: Vector2 = Vector2(0.5 + location.x / 360.0, 0.5 - location.y / 180.0)
		var nearest: Vector2i
		var best: float = INF
		for hex in tiles:
			if not tiles[hex]["is_land"]:
				continue
			var distance: float = WorldMapData.cell_uv(tiles[hex]["column"], tiles[hex]["row"], WorldMap.COLUMNS, WorldMap.ROWS).distance_squared_to(uv)
			if distance < best:
				best = distance
				nearest = hex
		endpoints.append(nearest)
	var route: Array[Vector2i] = HexPathfinding.find_path(tiles, endpoints[0], endpoints[1], "rifle")
	if route.is_empty():
		push_error("No land route from Mexico City to Bogota")
		quit(1)
		return
	print("Americas connectivity passed: Mexico City to Bogota, %d hexes" % route.size())
	quit()
