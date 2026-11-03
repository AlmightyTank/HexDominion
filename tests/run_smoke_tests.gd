extends SceneTree
## Run: godot --headless --path . --script res://tests/run_smoke_tests.gd
## No external test framework needed. Exits non-zero on a failed assertion.

var _successes: int = 0
var _failures: int = 0


func _init() -> void:
	call_deferred("_run_tests")


func _check(condition: bool, description: String) -> void:
	if condition:
		_successes += 1
	else:
		_failures += 1
		push_error("FAIL: %s" % description)


func _run_tests() -> void:
	for hex in [Vector2i.ZERO, Vector2i(1, -1), Vector2i(-6, 4), Vector2i(20, 10)]:
		var world_point: Vector2 = HexMath.axial_to_world(hex, 26.0)
		_check(HexMath.world_to_axial(world_point, 26.0) == hex, "Hex coordinate round trip %s" % hex)
	_check(HexMath.distance(Vector2i.ZERO, Vector2i(3, -2)) == 3, "Hex distance")
	var neighbors: Array[Vector2i] = HexMath.neighbors(Vector2i.ZERO)
	_check(neighbors.size() == 6, "Six neighbors")
	var unique: Dictionary = {}
	for neighbor in neighbors:
		unique[neighbor] = true
	_check(unique.size() == 6, "Neighbor directions are unique")

	for row in [0, 1, 2, 3, 13, 35]:
		for column in [0, 1, 15, 65]:
			var key: Vector2i = WorldMapData.offset_to_axial(column, row)
			_check(WorldMapData.axial_to_offset(key) == Vector2i(column, row), "Offset/axial round trip %s,%s" % [column, row])

	var world: Dictionary = WorldMapData.build(66, 36)
	_check(not world.is_empty(), "World definition parses")
	if world.is_empty():
		print("Hex Dominion v0.1 Slice B: %d passed, %d failed" % [_successes, _failures])
		quit(1)
		return
	var tiles: Dictionary = world["tiles"]
	var counts: Dictionary = world["terrain_counts"]
	_check(tiles.size() == 66 * 36, "All world hexes created")
	var num_land: int = tiles.size() - int(counts.get("ocean", 0))
	_check(num_land > 300 and num_land < 1700, "Ocean/land ratio is plausible")
	_check(int(counts.get("city", 0)) == 14, "14 unique city hexes")
	_check(int(counts.get("resource", 0)) == 10, "10 unique resource hexes")
	for terrain in WorldMapData.TERRAIN_TYPES:
		_check(int(counts.get(terrain, 0)) > 0, "Terrain present: %s" % terrain)
	var continents: Dictionary = {}
	for tile in tiles.values():
		if tile["is_land"]:
			continents[String(tile["continent"])] = true
		if tile["terrain"] in ["city", "resource"]:
			_check(tile["is_land"], "Special site lies on land")
			_check(not String(tile["site_name"]).is_empty(), "Special site has name")
	_check(continents.size() == 6, "All six continent regions have hexes")
	var sample: Vector2i = WorldMapData.offset_to_axial(12, 12)
	var second_world: Dictionary = WorldMapData.build(66, 36)
	_check(tiles[sample] == second_world["tiles"][sample], "Map generation deterministic")
	_check(world["terrain_counts"] == second_world["terrain_counts"], "Distribution deterministic")
	print("Hex Dominion v0.1 Slice B: %d passed, %d failed" % [_successes, _failures])
	quit(1 if _failures > 0 else 0)
