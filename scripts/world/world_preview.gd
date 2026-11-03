extends Node2D
## Temporary visual test grid for Slice A. NOT the Earth world map.
## Slice B will replace the generated preview with actual land/ocean mask data.

const RADIUS: float = 47.0
const WIDTH_HEXES: int = 27
const HEIGHT_HEXES: int = 16
const COLOR_BACKGROUND: Color = Color("091523")
const COLOR_OCEAN: Color = Color("143753")
const COLOR_OCEAN_DEEP: Color = Color("102d45")
const COLOR_PLAINS: Color = Color("2e6659")
const COLOR_FOREST: Color = Color("245047")
const COLOR_HIGHLANDS: Color = Color("7d7862")
const COLOR_OUTLINE: Color = Color("62869b", 0.22)


func _draw() -> void:
	draw_rect(Rect2(-5000.0, -4000.0, 10000.0, 8000.0), COLOR_BACKGROUND)
	for r in range(-int(HEIGHT_HEXES / 2.0), int(HEIGHT_HEXES / 2.0)):
		for q in range(-int(WIDTH_HEXES / 2.0), int(WIDTH_HEXES / 2.0) + 1):
			var axial: Vector2i = Vector2i(q, r)
			var center: Vector2 = HexMath.axial_to_world(axial, RADIUS)
			var fill_color: Color = _preview_terrain(q, r)
			var corners: PackedVector2Array = _hex_corners(center)
			draw_colored_polygon(corners, fill_color)
			var border: PackedVector2Array = corners.duplicate()
			border.append(corners[0])
			draw_polyline(border, COLOR_OUTLINE, 1.35, true)
			if fill_color == COLOR_HIGHLANDS:
				draw_circle(center, 5.0, Color("c5ba94", 0.55))


func _hex_corners(center: Vector2) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for index in range(6):
		var radians: float = deg_to_rad(float(index * 60 - 30))
		result.append(center + Vector2(cos(radians), sin(radians)) * (RADIUS - 1.7))
	return result


func _preview_terrain(q: int, r: int) -> Color:
	# A deterministic abstract archipelago, used only for camera interaction testing.
	var band: float = sin(float(q) * 0.47 + float(r) * 0.13)
	band += cos(float(r) * 0.64 - float(q) * 0.17) * 0.65
	band -= absf(float(q)) * 0.023
	if band < -0.18:
		return COLOR_OCEAN if (q + r) % 4 else COLOR_OCEAN_DEEP
	if band > 1.02:
		return COLOR_HIGHLANDS
	if (q * 7 + r * 3) % 5 == 0:
		return COLOR_FOREST
	return COLOR_PLAINS
