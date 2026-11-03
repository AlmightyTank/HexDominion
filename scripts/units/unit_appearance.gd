extends RefCounted
class_name UnitAppearance
## Local +X is forward. New unit families register an appearance in UnitCatalog.
const INK: Color = Color("131a17")
const CLOTH: Color = Color("92997a")
const LIGHT: Color = Color("c6c7a3")

static func _poly(canvas: CanvasItem, vertices: Array, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array(vertices), color)

static func tracked(canvas: CanvasItem, unit: UnitState, accent: Color, phase: float) -> void:
	canvas.draw_rect(Rect2(-9, -7, 18, 4), INK)
	canvas.draw_rect(Rect2(-9, 3, 18, 4), INK)
	for x in range(-8, 9, 4):
		canvas.draw_line(Vector2(x, -7), Vector2(x, -4), Color("626b61"), 1)
		canvas.draw_line(Vector2(x, 4), Vector2(x, 7), Color("626b61"), 1)
	_poly(canvas, [Vector2(-8, -4), Vector2(6, -5), Vector2(9, -2), Vector2(9, 2), Vector2(6, 5), Vector2(-8, 4)], CLOTH)
	canvas.draw_line(Vector2(-6, -4), Vector2(-6, 4), accent, 3)
	canvas.draw_line(Vector2(-3, -3), Vector2(6, -3), Color("e0ddbb"), 1)
	canvas.draw_line(Vector2(-3, 3), Vector2(6, 3), Color("56614e"), 1)
	if not unit.path.is_empty():
		var tread: float = fmod(phase * 15, 4)
		for x in range(-8, 8, 4):
			canvas.draw_line(Vector2(x + tread, -7), Vector2(x + tread, -3), CLOTH, 1)
			canvas.draw_line(Vector2(x + tread, 3), Vector2(x + tread, 7), CLOTH, 1)

static func draw_unit(canvas: CanvasItem, unit: UnitState, point: Vector2, accent: Color, selected: bool, phase: float, size_scale: float = 1.0) -> void:
	if unit.kind == "tank":
		if selected:
			canvas.draw_arc(point, 17 * size_scale, 0, TAU, 32, Color("fff0ad"), 2 * size_scale, true)
		canvas.draw_set_transform(point, unit.facing, Vector2.ONE * size_scale)
		tracked(canvas, unit, accent, phase)
		canvas.draw_set_transform(point, unit.turret_facing, Vector2.ONE * size_scale)
		_poly(canvas, [Vector2(-4, -4), Vector2(4, -4), Vector2(6, 0), Vector2(3, 4), Vector2(-4, 4)], LIGHT)
		canvas.draw_line(Vector2(3, 0), Vector2(17 if unit.attack_flash <= 0 else 15, 0), INK, 3)
	else:
		UnitArt.draw(canvas, unit.kind, unit.faction, UnitArt.state_for(unit.health, unit.max_health, unit.kind), point, unit.facing, selected, 28 * size_scale)
	canvas.draw_set_transform(point, unit.facing, Vector2.ONE * size_scale)
	if not UnitCatalog.is_infantry(unit.kind) and not unit.path.is_empty() and unit.kind != "tank":
		var movement: float = fmod(phase * 12, 4)
		for side in [-1, 1]:
			for x in [-7, 5]:
				canvas.draw_line(Vector2(x + movement, side * 8), Vector2(x + movement + 2, side * 8), LIGHT, 2)
	if unit.kind == "tank":
		canvas.draw_set_transform(point, unit.turret_facing, Vector2.ONE * size_scale)
	if unit.attack_flash > 0:
		if unit.kind == "anti_air":
			for side in [-1, 1]:
				canvas.draw_line(Vector2(9, side * 5), Vector2(18, side * 5), Color("ffe0a0"), 3)
		else:
			canvas.draw_circle(Vector2(17, 0), 2.5 + sin(phase) * 0.2, Color("ffe0a0"))
	if unit.damage_flash > 0:
		if UnitCatalog.is_infantry(unit.kind):
			canvas.draw_set_transform(Vector2.ZERO)
			UnitArt.badge_outline(canvas, point, 28 * size_scale, Color("ed736a"), 2)
		else:
			canvas.draw_arc(Vector2.ZERO, 8, 0, TAU, 16, Color("fff5db"), 2, true)
	canvas.draw_set_transform(Vector2.ZERO)
	if selected or unit.health < unit.max_health:
		canvas.draw_rect(Rect2(point + Vector2(-9, -14) * size_scale, Vector2(18, 2) * size_scale), INK)
		canvas.draw_rect(Rect2(point + Vector2(-9, -14) * size_scale, Vector2(18 * unit.health / unit.max_health, 2) * size_scale), accent)
	if unit.holding or unit.garrisoned:
		canvas.draw_line(point + Vector2(-5, 11) * size_scale, point + Vector2(5, 11) * size_scale, accent if unit.garrisoned else Color("fff0ad"), 2 * size_scale)

static func strategic(canvas: CanvasItem, kind: String, faction: int, center: Vector2, count: int, selected: bool, damaged: bool, scale_factor: float) -> void:
	UnitArt.draw(canvas, kind, faction, "icon", center, 0, selected, 25 * scale_factor)
	canvas.draw_set_transform(center, 0, Vector2.ONE * scale_factor)
	var digits: String = str(count)
	var width: float = maxf(14, ThemeDB.fallback_font.get_string_size(digits, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x + 6)
	canvas.draw_rect(Rect2(5, 6, width, 15), INK)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(8, 18), digits, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("f5efdb"))
	if damaged:
		canvas.draw_line(Vector2(-11, -10), Vector2(-5, -4), Color("fff0ad"), 3, true)
	canvas.draw_set_transform(Vector2.ZERO)
