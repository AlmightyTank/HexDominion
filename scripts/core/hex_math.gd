extends RefCounted
class_name HexMath
## Axial coordinate helpers for pointy-top hexagons (q, r).
## This is the shared foundation for world generation and movement in later slices.

const SQRT_3: float = 1.7320508075688772
const NEIGHBOR_DIRECTIONS: Array[Vector2i] = [
	Vector2i(1, 0),
	Vector2i(1, -1),
	Vector2i(0, -1),
	Vector2i(-1, 0),
	Vector2i(-1, 1),
	Vector2i(0, 1),
]


static func axial_to_world(hex: Vector2i, radius: float) -> Vector2:
	return Vector2(
		SQRT_3 * radius * (float(hex.x) + float(hex.y) * 0.5),
		1.5 * radius * float(hex.y)
	)


static func world_to_axial(world: Vector2, radius: float) -> Vector2i:
	assert(radius > 0.0, "Hex radius must be positive")
	var fractional_q: float = (SQRT_3 / 3.0 * world.x - world.y / 3.0) / radius
	var fractional_r: float = (2.0 / 3.0 * world.y) / radius
	return cube_round(fractional_q, fractional_r)


static func cube_round(q: float, r: float) -> Vector2i:
	var s: float = -q - r
	var rounded_q: int = roundi(q)
	var rounded_r: int = roundi(r)
	var rounded_s: int = roundi(s)
	var delta_q: float = absf(float(rounded_q) - q)
	var delta_r: float = absf(float(rounded_r) - r)
	var delta_s: float = absf(float(rounded_s) - s)
	if delta_q > delta_r and delta_q > delta_s:
		rounded_q = -rounded_r - rounded_s
	elif delta_r > delta_s:
		rounded_r = -rounded_q - rounded_s
	return Vector2i(rounded_q, rounded_r)


static func neighbors(hex: Vector2i) -> Array[Vector2i]:
	var results: Array[Vector2i] = []
	for direction: Vector2i in NEIGHBOR_DIRECTIONS:
		results.append(hex + direction)
	return results


static func distance(a: Vector2i, b: Vector2i) -> int:
	var q_diff: int = a.x - b.x
	var r_diff: int = a.y - b.y
	return maxi(maxi(absi(q_diff), absi(r_diff)), absi(q_diff + r_diff))
