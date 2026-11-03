extends SceneTree
## Run: godot --headless --path . --script res://tests/run_smoke_tests.gd
## Test script intentionally has no third-party dependencies.


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var successes: int = 0
	var failures: int = 0
	for hex in [Vector2i.ZERO, Vector2i(1, -1), Vector2i(-6, 4), Vector2i(20, 10)]:
		var world: Vector2 = HexMath.axial_to_world(hex, 47.0)
		if HexMath.world_to_axial(world, 47.0) == hex:
			successes += 1
		else:
			failures += 1
			push_error("Roundtrip failure at hex %s" % hex)
	if HexMath.distance(Vector2i.ZERO, Vector2i(3, -2)) == 3:
		successes += 1
	else:
		failures += 1
		push_error("Hex distance was incorrect")
	if HexMath.neighbors(Vector2i.ZERO).size() == 6:
		successes += 1
	else:
		failures += 1
		push_error("Hex neighbors count was incorrect")
	var unique: Dictionary = {}
	for neighbor in HexMath.neighbors(Vector2i.ZERO):
		unique[neighbor] = true
	if unique.size() == 6:
		successes += 1
	else:
		failures += 1
		push_error("Hex neighbor directions have duplicates")
	print("HexDominion v0.1 Slice A: %d passed, %d failed" % [successes, failures])
	quit(1 if failures else 0)
