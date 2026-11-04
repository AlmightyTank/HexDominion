extends RefCounted
class_name UnitAppearance
## Local +X is forward. New unit families register an appearance in UnitCatalog.
const INK: Color = Color("131a17")
const CLOTH: Color = Color("92997a")
const LIGHT: Color = Color("c6c7a3")

static func muzzle_points(kind: String, remaining: float, icon: bool = false) -> Array[Vector2]:
	if not icon:
		if kind == "tank":
			return [Vector2(67 * 28.0 / 128.0 - 2 * clampf(remaining / 0.14, 0, 1), 0)]
		if kind == "artillery":
			return [Vector2(81 * 28.0 / 128.0 - 4 * clampf(remaining / 0.14, 0, 1), 0)]
	# SVG weapons face north in a 128px source; convert to local +X forward.
	var source: Array[Vector2] = []
	match kind:
		"rifle": source = [Vector2(79, 17)]
		"rocket": source = [Vector2(79, 9)]
		"gunner": source = [Vector2(79, 11)]
		"scout": source = [Vector2(73, 42)]
		"apc": source = [Vector2(64, 30)]
		"anti_air": source = [Vector2(35, 10), Vector2(87, 10)]
		"tank": source = [Vector2(64, 9)]
		"artillery": source = [Vector2(64, 4)]
		"helicopter": source = [Vector2(37, 35), Vector2(91, 35)]
		"fighter": source = [Vector2(37, 45), Vector2(91, 45)]
	var points: Array[Vector2] = []
	for tip in source:
		points.append(Vector2(64 - tip.y, tip.x - 64) * (25.0 if icon else 28.0) / 128.0)
	return points

static func firing_effect(canvas: CanvasItem, unit: UnitState, point: Vector2, size_scale: float = 1.0, icon: bool = false) -> void:
	if unit.attack_flash <= 0:
		return
	var direction: float = unit.turret_facing if unit.kind in ["tank", "artillery"] else unit.facing
	var age: float = 0.14 - clampf(unit.attack_flash, 0, 0.14)
	var heavy: bool = unit.kind in ["tank", "artillery"]
	var duration: float = 0.09 if heavy else 0.065
	if age >= duration:
		return
	var fade: float = 1.0 - age / duration
	var length: float = (9.0 if heavy else 4.5) * (0.65 + 0.35 * fade)
	var width: float = 3.2 if heavy else 1.6
	if heavy and not icon:
		point += turret_offset(unit) * size_scale
	for tip in muzzle_points(unit.kind, unit.attack_flash, icon):
		canvas.draw_set_transform(point + tip.rotated(direction) * size_scale, direction, Vector2.ONE * size_scale)
		_poly(canvas, [Vector2.ZERO, Vector2(length * 0.35, -width), Vector2(length * 0.65, -width * 0.4), Vector2(length, 0), Vector2(length * 0.65, width * 0.4), Vector2(length * 0.35, width)], Color(1.0, 0.62, 0.2, fade))
		_poly(canvas, [Vector2.ZERO, Vector2(length * 0.45, -width * 0.4), Vector2(length * 0.7, 0), Vector2(length * 0.45, width * 0.4)], Color(1.0, 0.95, 0.76, fade))
	canvas.draw_set_transform(Vector2.ZERO)

static func _poly(canvas: CanvasItem, vertices: Array, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array(vertices), color)

static func turret_offset(unit: UnitState) -> Vector2:
	var pivot_y: float = 76 if unit.kind == "tank" else 85
	return Vector2((64 - pivot_y) * 28.0 / 128.0, 0).rotated(unit.facing)

static func draw_armor(canvas: CanvasItem, unit: UnitState, point: Vector2, state: String, size_scale: float) -> void:
	var pixel: float = 28.0 / 128.0 * size_scale
	canvas.draw_set_transform(point, unit.facing + PI / 2)
	canvas.draw_texture_rect(UnitArt.layer_texture(unit.kind, unit.faction, state, "hull"), Rect2(Vector2(-64, -64) * pixel, Vector2.ONE * 128 * pixel), false)
	var pivot: Vector2 = point + turret_offset(unit) * size_scale
	var pivot_y: float = 76 if unit.kind == "tank" else 85
	var rect: Rect2 = Rect2(Vector2(-64, -pivot_y) * pixel, Vector2.ONE * 128 * pixel)
	canvas.draw_set_transform(pivot, unit.turret_facing + PI / 2)
	canvas.draw_texture_rect(UnitArt.layer_texture(unit.kind, unit.faction, state, "turret"), rect, false)
	var recoil: float = (2.0 if unit.kind == "tank" else 4.0) * clampf(unit.attack_flash / 0.14, 0, 1) * size_scale
	canvas.draw_set_transform(pivot - Vector2.from_angle(unit.turret_facing) * recoil, unit.turret_facing + PI / 2)
	canvas.draw_texture_rect(UnitArt.layer_texture(unit.kind, unit.faction, state, "barrel"), rect, false)
	canvas.draw_set_transform(Vector2.ZERO)

static func draw_unit(canvas: CanvasItem, unit: UnitState, point: Vector2, accent: Color, selected: bool, phase: float, size_scale: float = 1.0) -> void:
	accent = UnitArt.ACCENTS[UnitArt.faction_slot(unit.faction)]
	var state: String = UnitArt.state_for(unit.health, unit.max_health, unit.kind)
	if unit.domain == "air":
		canvas.draw_set_transform(point + Vector2(8, 19) * size_scale, unit.facing + PI / 2, Vector2.ONE * size_scale)
		canvas.draw_texture_rect(UnitArt.texture(unit.kind, unit.faction, state), Rect2(-14, -14, 28, 28), false, Color(0, 0, 0, 0.35))
		canvas.draw_set_transform(Vector2.ZERO)
	if unit.kind in ["tank", "artillery"] and state != "destroyed":
		if selected:
			canvas.draw_arc(point, 17 * size_scale, 0, TAU, 32, INK, 4 * size_scale, true)
			canvas.draw_arc(point, 17 * size_scale, 0, TAU, 32, Color("fff0ad"), 2 * size_scale, true)
		draw_armor(canvas, unit, point, state, size_scale)
	else:
		UnitArt.draw(canvas, unit.kind, unit.faction, state, point, unit.facing, selected, 28 * size_scale)
	canvas.draw_set_transform(point, unit.facing, Vector2.ONE * size_scale)
	if unit.domain == "ground" and not UnitCatalog.is_infantry(unit.kind) and not unit.path.is_empty() and unit.kind != "tank":
		var movement: float = fmod(phase * 12, 4)
		for side in [-1, 1]:
			for x in [-7, 5]:
				canvas.draw_line(Vector2(x + movement, side * 8), Vector2(x + movement + 2, side * 8), LIGHT, 2)
	if unit.kind in ["tank", "artillery"]:
		canvas.draw_set_transform(point, unit.turret_facing, Vector2.ONE * size_scale)
	firing_effect(canvas, unit, point, size_scale)
	canvas.draw_set_transform(point, unit.turret_facing if unit.kind in ["tank", "artillery"] else unit.facing, Vector2.ONE * size_scale)
	if unit.damage_flash > 0:
		if UnitCatalog.is_infantry(unit.kind):
			canvas.draw_set_transform(Vector2.ZERO)
			canvas.draw_arc(point, 14 * size_scale, 0, TAU, 24, Color("ed736a"), 2, true)
		else:
			canvas.draw_arc(Vector2.ZERO, 8, 0, TAU, 16, Color("fff5db"), 2, true)
	canvas.draw_set_transform(Vector2.ZERO)
	if unit.kind == "helicopter":
		canvas.draw_set_transform(point, phase * 25, Vector2.ONE * size_scale)
		canvas.draw_line(Vector2(-18, 0), Vector2(18, 0), Color(0.8, 0.85, 0.83, 0.8), 2, true)
		canvas.draw_line(Vector2(0, -18), Vector2(0, 18), Color(0.8, 0.85, 0.83, 0.8), 2, true)
		canvas.draw_set_transform(point - Vector2.from_angle(unit.facing) * 11 * size_scale, phase * -35, Vector2.ONE * size_scale)
		canvas.draw_line(Vector2(-4, 0), Vector2(4, 0), Color("c6c7a3"), 1.5, true)
		canvas.draw_set_transform(Vector2.ZERO)
	if selected or unit.health < unit.max_health:
		canvas.draw_rect(Rect2(point + Vector2(-9, -14) * size_scale, Vector2(18, 2) * size_scale), INK)
		canvas.draw_rect(Rect2(point + Vector2(-9, -14) * size_scale, Vector2(18 * unit.health / unit.max_health, 2) * size_scale), accent)
	if unit.holding or unit.garrisoned:
		canvas.draw_line(point + Vector2(-5, 11) * size_scale, point + Vector2(5, 11) * size_scale, accent if unit.garrisoned else Color("fff0ad"), 2 * size_scale)

static func strategic(canvas: CanvasItem, kind: String, faction: int, center: Vector2, count: int, selected: bool, damaged: bool, scale_factor: float, facing: float = -PI / 2) -> void:
	# Rotate artwork only; selection, count and status remain screen-aligned.
	canvas.draw_set_transform(center, facing + PI / 2, Vector2.ONE)
	canvas.draw_texture_rect(UnitArt.texture(kind, faction, "damaged" if damaged else "icon"), Rect2(Vector2.ONE * -12.5 * scale_factor, Vector2.ONE * 25 * scale_factor), false)
	canvas.draw_set_transform(Vector2.ZERO)
	if selected:
		canvas.draw_arc(center, 14 * scale_factor, 0, TAU, 32, INK, 3 * scale_factor, true)
		canvas.draw_arc(center, 14 * scale_factor, 0, TAU, 32, Color("fff0ad"), scale_factor, true)
	canvas.draw_set_transform(center, 0, Vector2.ONE * scale_factor)
	var digits: String = str(count)
	var width: float = maxf(14, ThemeDB.fallback_font.get_string_size(digits, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6)
	canvas.draw_rect(Rect2(5, 6, width, 15), INK)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(8, 18), digits, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5efdb"))
	if damaged:
		canvas.draw_line(Vector2(-11, -10), Vector2(-5, -4), Color("fff0ad"), 3, true)
	canvas.draw_set_transform(Vector2.ZERO)
