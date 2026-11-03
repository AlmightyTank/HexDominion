extends Node2D
class_name WorldMap
## Slice B: authored Earth-inspired continent silhouettes represented as hexes.
## Geometry and classification are generated once. No per-hex scene nodes.

const HEX_RADIUS: float = 26.0
const COLUMNS: int = 66
const ROWS: int = 36

const COLOR_OUTER: Color = Color("071522")
const COLOR_GRID: Color = Color("233e48", 0.53)
const COLOR_COAST: Color = Color("9cc5b4", 0.70)
const COLOR_HIGHLIGHT: Color = Color("fff0ad")
const COLOR_OCEAN: Color = Color("12364c")
const COLOR_OCEAN_DEEP: Color = Color("103044")
const COLOR_PLAINS: Color = Color("60876b")
const COLOR_FOREST: Color = Color("28624c")
const COLOR_DESERT: Color = Color("bc9d60")
const COLOR_MOUNTAIN: Color = Color("858a81")
const COLOR_CITY: Color = Color("4e8f84")
const COLOR_RESOURCE: Color = Color("85804c")

const COLOR_BY_TERRAIN: Dictionary = {
	"ocean": COLOR_OCEAN, "plains": COLOR_PLAINS, "forest": COLOR_FOREST,
	"desert": COLOR_DESERT, "mountain": COLOR_MOUNTAIN,
	"city": COLOR_CITY, "resource": COLOR_RESOURCE,
}

var map_data: Dictionary = {}
var selected_hex: Vector2i = Vector2i(-9999, -9999)
var _origin: Vector2 = Vector2.ZERO
var _bounds: Rect2 = Rect2()


func _ready() -> void:
	map_data = WorldMapData.build(COLUMNS, ROWS)
	var center_span: Vector2 = Vector2(HexMath.SQRT_3 * HEX_RADIUS * (float(COLUMNS - 1) + 0.5), 1.5 * HEX_RADIUS * float(ROWS - 1))
	_origin = -center_span * 0.5
	_bounds = Rect2(_origin - Vector2.ONE * HEX_RADIUS, center_span + Vector2.ONE * HEX_RADIUS * 2.0)
	queue_redraw()


func world_bounds() -> Rect2:
	return _bounds


func world_to_hex(global_point: Vector2) -> Vector2i:
	return HexMath.world_to_axial(to_local(global_point) - _origin, HEX_RADIUS)


func hex_to_world(axial: Vector2i) -> Vector2:
	return to_global(_origin + HexMath.axial_to_world(axial, HEX_RADIUS))


func tile_at_world(global_point: Vector2) -> Dictionary:
	if map_data.is_empty():
		return {}
	var key: Vector2i = world_to_hex(global_point)
	var tiles: Dictionary = map_data["tiles"]
	return tiles.get(key, {})


func inspect_at_world(global_point: Vector2) -> Dictionary:
	var tile: Dictionary = tile_at_world(global_point)
	if tile.is_empty():
		selected_hex = Vector2i(-9999, -9999)
	else:
		selected_hex = tile["axial"]
	queue_redraw()
	return tile


func _draw() -> void:
	draw_rect(_bounds.grow(220.0), COLOR_OUTER)
	if map_data.is_empty():
		return
	var tiles: Dictionary = map_data["tiles"]
	for row in range(ROWS):
		for column in range(COLUMNS):
			var hex: Vector2i = WorldMapData.offset_to_axial(column, row)
			var tile: Dictionary = tiles[hex]
			var center: Vector2 = _origin + HexMath.axial_to_world(hex, HEX_RADIUS)
			var corners: PackedVector2Array = _hex_corners(center)
			var terrain: String = tile["terrain"]
			var fill_color: Color = COLOR_BY_TERRAIN.get(terrain, COLOR_PLAINS)
			if terrain == "ocean" and (column * 13 + row * 7) % 9 < 3:
				fill_color = COLOR_OCEAN_DEEP
			draw_colored_polygon(corners, fill_color)
			var border: PackedVector2Array = corners.duplicate()
			border.append(corners[0])
			draw_polyline(border, COLOR_GRID, 1.15, true)
			if tile["is_land"]:
				_draw_coast_edges(corners, hex, tiles)
				_draw_terrain_symbol(center, tile)
			elif (row * 11 + column * 7) % 13 == 0:
				draw_line(center + Vector2(-7.0, 2.0), center + Vector2(7.0, 2.0), Color("3b728a", 0.5), 1.3, true)
			if selected_hex == hex:
				draw_polyline(border, COLOR_HIGHLIGHT, 3.4, true)


func _hex_corners(center: Vector2) -> PackedVector2Array:
	var corners: PackedVector2Array = PackedVector2Array()
	for index in range(6):
		var radians: float = deg_to_rad(float(index * 60 - 30))
		corners.append(center + Vector2(cos(radians), sin(radians)) * (HEX_RADIUS - 1.0))
	return corners


func _draw_coast_edges(corners: PackedVector2Array, hex: Vector2i, tiles: Dictionary) -> void:
	# Side order matches corner angles: E, SE, SW, W, NW, NE.
	var directions: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1),
		Vector2i(-1, 0), Vector2i(0, -1), Vector2i(1, -1)
	]
	for index in range(6):
		var neighbor: Dictionary = tiles.get(hex + directions[index], {})
		if neighbor.is_empty() or not neighbor["is_land"]:
			draw_line(corners[index], corners[(index + 1) % 6], COLOR_COAST, 2.1, true)


func _draw_terrain_symbol(center: Vector2, tile: Dictionary) -> void:
	var terrain: String = tile["terrain"]
	match terrain:
		"forest":
			for offset in [Vector2(-7.0, 5.0), Vector2(0.0, -4.0), Vector2(7.0, 5.0)]:
				var trunk: Vector2 = center + offset
				draw_line(trunk, trunk + Vector2(0.0, 6.0), Color("142d26"), 2.1, true)
				draw_circle(trunk, 4.4, Color("193f32"))
		"mountain":
			var peak: PackedVector2Array = PackedVector2Array([center + Vector2(-10.0, 7.0), center + Vector2(0.0, -9.0), center + Vector2(11.0, 7.0)])
			draw_colored_polygon(peak, Color("475456"))
			draw_line(center + Vector2(-3.0, -4.0), center, Color("e1ddd0"), 2.2, true)
		"desert":
			draw_arc(center + Vector2(0.0, 6.0), 8.0, PI, TAU, 14, Color("e7c887", 0.75), 1.7, true)
		"city":
			draw_circle(center, 11.0, Color("112e39", 0.9))
			draw_rect(Rect2(center + Vector2(-5.0, -5.0), Vector2(10.0, 10.0)), Color("f5e7b1"))
			draw_rect(Rect2(center + Vector2(-2.0, -9.0), Vector2(4.0, 4.0)), Color("f5e7b1"))
		"resource":
			draw_circle(center, 10.0, Color("23362e", 0.94))
			var diamond: PackedVector2Array = PackedVector2Array([center + Vector2(0.0, -7.0), center + Vector2(6.0, 0.0), center + Vector2(0.0, 7.0), center + Vector2(-6.0, 0.0)])
			draw_colored_polygon(diamond, Color("f1d777"))
