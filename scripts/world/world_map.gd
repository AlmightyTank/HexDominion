extends Node2D
class_name WorldMap
## Real Earth coastlines sampled onto a dense hex grid.
## Terrain is rendered once into a texture; selection stays a live overlay.

const HEX_RADIUS: float = 18.0
const COLUMNS: int = 120
const ROWS: int = 70
const TERRAIN_CACHE_SCALE: float = 2.0

const COLOR_OUTER: Color = Color("243a3a")
const COLOR_GRID: Color = Color("86afa1", 0.25)
const COLOR_COAST: Color = Color("9cc5b4", 0.70)
const COLOR_HIGHLIGHT: Color = Color("6dd5fa")
const COLOR_OCEAN: Color = Color("263f46")
const COLOR_OCEAN_DEEP: Color = Color("263f46")
const COLOR_PLAINS: Color = Color("497c64")
const COLOR_FOREST: Color = Color("466a5e")
const COLOR_DESERT: Color = Color("656d58")
const COLOR_MOUNTAIN: Color = Color("566a57")
const COLOR_CITY: Color = Color("4c7860")
const COLOR_RESOURCE: Color = Color("66735a")
const COLOR_SNOW: Color = Color("96aba1")
const COLOR_TUNDRA: Color = Color("748c7d")
const COLOR_SEA_ICE: Color = Color("6e8785")

const COLOR_BY_TERRAIN: Dictionary = {
	"ocean": COLOR_OCEAN, "plains": COLOR_PLAINS, "forest": COLOR_FOREST,
	"desert": COLOR_DESERT, "mountain": COLOR_MOUNTAIN,
	"city": COLOR_CITY, "resource": COLOR_RESOURCE,
	"snow": COLOR_SNOW, "tundra": COLOR_TUNDRA,
}

var map_data: Dictionary = {}
var selected_hex: Vector2i = Vector2i(-9999, -9999)
var _origin: Vector2 = Vector2.ZERO
var _bounds: Rect2 = Rect2()
var _selection_overlay: Node2D
var _terrain_viewport: SubViewport
var _terrain_canvas: Node2D


func _ready() -> void:
	map_data = WorldMapData.build(COLUMNS, ROWS)
	var center_span: Vector2 = Vector2(HexMath.SQRT_3 * HEX_RADIUS * (float(COLUMNS - 1) + 0.5), 1.5 * HEX_RADIUS * float(ROWS - 1))
	_origin = -center_span * 0.5
	_bounds = Rect2(_origin - Vector2.ONE * HEX_RADIUS, center_span + Vector2.ONE * HEX_RADIUS * 2.0)
	_create_terrain_cache()
	_selection_overlay = Node2D.new()
	_selection_overlay.name = "SelectionOverlay"
	_selection_overlay.draw.connect(_draw_selection)
	add_child(_selection_overlay)
	queue_redraw()


func _create_terrain_cache() -> void:
	# The static map used tens of thousands of draw calls every frame. Bake it
	# once at 2x resolution so camera zoom does not magnify a low-DPI grid.
	_terrain_viewport = SubViewport.new()
	_terrain_viewport.name = "TerrainCache"
	var cache_size: Vector2i = Vector2i(
		ceili(_bounds.size.x * TERRAIN_CACHE_SCALE),
		ceili(_bounds.size.y * TERRAIN_CACHE_SCALE)
	)
	_terrain_viewport.size = cache_size
	_terrain_viewport.size_2d_override = Vector2i(ceili(_bounds.size.x), ceili(_bounds.size.y))
	_terrain_viewport.size_2d_override_stretch = true
	_terrain_viewport.world_2d = World2D.new()
	_terrain_viewport.disable_3d = true
	_terrain_viewport.transparent_bg = true
	_terrain_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(_terrain_viewport)
	_terrain_canvas = Node2D.new()
	_terrain_canvas.position = -_bounds.position
	_terrain_canvas.draw.connect(_draw_terrain)
	_terrain_viewport.add_child(_terrain_canvas)
	var terrain_sprite: Sprite2D = Sprite2D.new()
	terrain_sprite.name = "CachedTerrain"
	terrain_sprite.centered = false
	terrain_sprite.position = _bounds.position
	terrain_sprite.scale = Vector2.ONE / TERRAIN_CACHE_SCALE
	terrain_sprite.texture = _terrain_viewport.get_texture()
	terrain_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	add_child(terrain_sprite)


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
	_selection_overlay.queue_redraw()
	return tile


func _draw() -> void:
	draw_rect(_bounds.grow(220.0), COLOR_OUTER)


func _draw_terrain() -> void:
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
			# Sites keep their natural ground color; their markers identify them.
			var ground: String = String(tile["biome"])
			var fill_color: Color = COLOR_BY_TERRAIN.get(ground, COLOR_PLAINS)
			if terrain == "ocean" and (column * 13 + row * 7) % 9 < 3:
				fill_color = COLOR_OCEAN_DEEP
			if tile["is_land"]:
				# Stable, subtle variation avoids flat rectangular color bands.
				var shade: float = float((column * 17 + row * 31) % 11 - 5) * 0.006
				fill_color = fill_color.lightened(shade) if shade > 0.0 else fill_color.darkened(-shade)
			else:
				var latitude: float = 90.0 - WorldMapData.cell_uv(column, row, COLUMNS, ROWS).y * 180.0
				# Illustrative static polar sea ice. These remain ocean gameplay cells.
				var ice_edge: float = 77.0 + sin(float(column) * 0.37) * 2.0
				if latitude > ice_edge or latitude < -70.0 - sin(float(column) * 0.23) * 2.0:
					fill_color = COLOR_SEA_ICE.lerp(COLOR_SNOW, 0.3 + float((column + row) % 3) * 0.1)
			_terrain_canvas.draw_colored_polygon(corners, fill_color)
			var border: PackedVector2Array = corners.duplicate()
			border.append(corners[0])
			_terrain_canvas.draw_polyline(border, COLOR_GRID, 0.35, true)
			if tile["is_land"]:
				_draw_coast_edges(corners, hex, tiles)
				if terrain in ["city", "resource"]:
					_terrain_canvas.draw_set_transform(center, 0.0, Vector2.ONE * (HEX_RADIUS / 26.0))
					_draw_terrain_symbol(Vector2.ZERO, tile)
					_terrain_canvas.draw_set_transform(Vector2.ZERO)


func _draw_selection() -> void:
	# Selection does not rebuild the terrain draw commands.
	if map_data.is_empty() or not map_data["tiles"].has(selected_hex):
		return
	var center: Vector2 = _origin + HexMath.axial_to_world(selected_hex, HEX_RADIUS)
	var border: PackedVector2Array = _hex_corners(center)
	_selection_overlay.draw_colored_polygon(border, Color("2073aa", 0.28))
	border.append(border[0])
	_selection_overlay.draw_polyline(border, COLOR_HIGHLIGHT, 1.8, true)


func _hex_corners(center: Vector2) -> PackedVector2Array:
	var corners: PackedVector2Array = PackedVector2Array()
	for index in range(6):
		var radians: float = deg_to_rad(float(index * 60 - 30))
		corners.append(center + Vector2(cos(radians), sin(radians)) * HEX_RADIUS)
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
			_terrain_canvas.draw_line(corners[index], corners[(index + 1) % 6], COLOR_COAST, 0.65, true)
		elif hex + directions[index] in tiles[hex].get("river_neighbors", []):
			_terrain_canvas.draw_line(corners[index], corners[(index + 1) % 6], Color("77b9dc"), 1.6, true)


func _draw_terrain_symbol(center: Vector2, tile: Dictionary) -> void:
	var terrain: String = tile["terrain"]
	match terrain:
		"forest":
			for offset in [Vector2(-7.0, 5.0), Vector2(0.0, -4.0), Vector2(7.0, 5.0)]:
				var trunk: Vector2 = center + offset
				_terrain_canvas.draw_line(trunk, trunk + Vector2(0.0, 6.0), Color("142d26"), 2.1, true)
				_terrain_canvas.draw_circle(trunk, 4.4, Color("193f32"))
		"mountain":
			var peak: PackedVector2Array = PackedVector2Array([center + Vector2(-10.0, 7.0), center + Vector2(0.0, -9.0), center + Vector2(11.0, 7.0)])
			_terrain_canvas.draw_colored_polygon(peak, Color("475456"))
			var snow_cap: PackedVector2Array = PackedVector2Array([center + Vector2(-4.0, -2.5), center + Vector2(0.0, -9.0), center + Vector2(4.5, -2.5), center + Vector2(1.0, -4.0), center + Vector2(-1.0, -1.0)])
			_terrain_canvas.draw_colored_polygon(snow_cap, COLOR_SNOW)
		"snow":
			_terrain_canvas.draw_line(center + Vector2(-8.0, 4.0), center + Vector2(-1.0, 2.0), Color("b3cdd6"), 1.1, true)
			_terrain_canvas.draw_line(center + Vector2(2.0, -3.0), center + Vector2(8.0, -4.0), Color("f7faf8"), 1.5, true)
		"tundra":
			_terrain_canvas.draw_line(center + Vector2(-6.0, 4.0), center + Vector2(-2.0, 2.0), Color("748c80"), 1.3, true)
		"desert":
			_terrain_canvas.draw_arc(center + Vector2(0.0, 6.0), 8.0, PI, TAU, 14, Color("e7c887", 0.75), 1.7, true)
		"city":
			_terrain_canvas.draw_circle(center, 11.0, Color("112e39", 0.9))
			_terrain_canvas.draw_rect(Rect2(center + Vector2(-5.0, -5.0), Vector2(10.0, 10.0)), Color("f5e7b1"))
			_terrain_canvas.draw_rect(Rect2(center + Vector2(-2.0, -9.0), Vector2(4.0, 4.0)), Color("f5e7b1"))
		"resource":
			_terrain_canvas.draw_circle(center, 10.0, Color("23362e", 0.94))
			var diamond: PackedVector2Array = PackedVector2Array([center + Vector2(0.0, -7.0), center + Vector2(6.0, 0.0), center + Vector2(0.0, 7.0), center + Vector2(-6.0, 0.0)])
			_terrain_canvas.draw_colored_polygon(diamond, Color("f1d777"))
