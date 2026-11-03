extends RefCounted
class_name UnitAppearance
## Local +X is forward. New unit families register an appearance in UnitCatalog.
const INK: Color = Color("131a17")
const CLOTH: Color = Color("92997a")
const LIGHT: Color = Color("c6c7a3")

static func _poly(canvas: CanvasItem, vertices: Array, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array(vertices), color)

static func soldier(canvas: CanvasItem, unit: UnitState, accent: Color, phase: float) -> void:
	var moving: bool = not unit.path.is_empty()
	var stride: float = sin(phase * 16.0) * 2.0 if moving else sin(phase * 2.0) * 0.25
	var recoil: float = -1.2 if unit.attack_flash > 0 else 0.0
	canvas.draw_circle(Vector2(1, 2), 7, Color(0, 0, 0, 0.35))
	# Split boots, tapered shoulders, backpack and faceted helmet retain a human outline.
	canvas.draw_line(Vector2(-3, -2), Vector2(-6 + stride, -3), INK, 3.5)
	canvas.draw_line(Vector2(-3, 2), Vector2(-6 - stride, 3), INK, 3.5)
	_poly(canvas, [Vector2(-4, -4), Vector2(2, -6), Vector2(5, -3), Vector2(4, 4), Vector2(-4, 4)], CLOTH)
	canvas.draw_rect(Rect2(-5, -3, 3, 6), Color("626e53"))
	canvas.draw_line(Vector2(1, -5), Vector2(4, -3), accent, 2.5)
	canvas.draw_line(Vector2(1, 4), Vector2(4, 3), accent, 2.5)
	_poly(canvas, [Vector2(-1, -2), Vector2(2, -3), Vector2(5, -1), Vector2(5, 2), Vector2(1, 3)], LIGHT)
	canvas.draw_line(Vector2(4, -1), Vector2(5, 1), INK, 1.5)
	var muzzle: float = 13.0
	if unit.kind == "rocket":
		# A broad shoulder tube with flared warhead and rear exhaust, not a recolored rifle.
		canvas.draw_rect(Rect2(-7 + recoil, -7, 17, 4), INK)
		canvas.draw_rect(Rect2(-5 + recoil, -6.5, 13, 3), Color("8c9270"))
		_poly(canvas, [Vector2(8 + recoil, -8), Vector2(14 + recoil, -5), Vector2(8 + recoil, -2)], LIGHT)
		canvas.draw_line(Vector2(-7, -8), Vector2(-7, -2), accent, 2)
		muzzle = 15.0
	elif unit.kind == "gunner":
		canvas.draw_rect(Rect2(3 + recoil, 2, 9, 3.5), INK)
		canvas.draw_rect(Rect2(5 + recoil, 4, 4, 3), Color("b5a578"))
		canvas.draw_line(Vector2(9 + recoil, 3), Vector2(18 + recoil, 3), INK, 2.5)
		canvas.draw_line(Vector2(15, 3), Vector2(18, 7), INK, 1.2)
		canvas.draw_line(Vector2(15, 3), Vector2(18, -1), INK, 1.2)
		muzzle = 19.0
	else:
		canvas.draw_line(Vector2(3 + recoil, 3), Vector2(12 + recoil, 3), INK, 2.2)
		canvas.draw_line(Vector2(6, 3), Vector2(5, 6), INK, 2)
	if unit.attack_flash > 0:
		var y: float = -5.0 if unit.kind == "rocket" else 3.0
		_poly(canvas, [Vector2(muzzle, y - 3), Vector2(muzzle + 6, y), Vector2(muzzle, y + 3), Vector2(muzzle + 2, y)], Color("ffe0a0"))

static func tracked(canvas: CanvasItem, unit: UnitState, accent: Color, phase: float) -> void:
	canvas.draw_rect(Rect2(-9, -7, 18, 4), INK)
	canvas.draw_rect(Rect2(-9, 3, 18, 4), INK)
	_poly(canvas, [Vector2(-8, -4), Vector2(6, -5), Vector2(9, -2), Vector2(9, 2), Vector2(6, 5), Vector2(-8, 4)], CLOTH)
	canvas.draw_line(Vector2(-6, -4), Vector2(-6, 4), accent, 3)
	_poly(canvas, [Vector2(-3, -3), Vector2(4, -3), Vector2(6, 0), Vector2(3, 3), Vector2(-3, 3)], LIGHT)
	canvas.draw_line(Vector2(3, 0), Vector2(17 if unit.attack_flash <= 0 else 15, 0), INK, 3)
	if not unit.path.is_empty():
		var tread: float = fmod(phase * 15, 4)
		for x in range(-8, 8, 4):
			canvas.draw_line(Vector2(x + tread, -7), Vector2(x + tread, -3), CLOTH, 1)
	if unit.attack_flash > 0:
		canvas.draw_circle(Vector2(19, 0), 3, Color("ffe0a0"))

static func draw_unit(canvas: CanvasItem, unit: UnitState, point: Vector2, accent: Color, selected: bool, phase: float, size_scale: float = 1.0) -> void:
	if selected:
		canvas.draw_arc(point, 12 * size_scale, 0, TAU, 24, Color("fff0ad"), 1.4 * size_scale, true)
	canvas.draw_set_transform(point, unit.facing, Vector2.ONE * size_scale)
	if UnitCatalog.TYPES[unit.kind]["appearance"] == "tracked":
		tracked(canvas, unit, accent, phase)
	else:
		soldier(canvas, unit, accent, phase)
	if unit.damage_flash > 0:
		canvas.draw_arc(Vector2.ZERO, 8, 0, TAU, 16, Color("fff5db"), 2, true)
	canvas.draw_set_transform(Vector2.ZERO)
	if selected or unit.health < unit.max_health:
		canvas.draw_rect(Rect2(point + Vector2(-9, -14) * size_scale, Vector2(18, 2) * size_scale), INK)
		canvas.draw_rect(Rect2(point + Vector2(-9, -14) * size_scale, Vector2(18 * unit.health / unit.max_health, 2) * size_scale), accent)
	if unit.holding or unit.garrisoned:
		canvas.draw_line(point + Vector2(-5, 11) * size_scale, point + Vector2(5, 11) * size_scale, accent if unit.garrisoned else Color("fff0ad"), 2 * size_scale)

static func draw_marker(canvas: CanvasItem, kind: String, center: Vector2, accent: Color, count: int, selected: bool, scale_factor: float) -> void:
	canvas.draw_set_transform(center, 0, Vector2.ONE * scale_factor)
	canvas.draw_rect(Rect2(-10, -10, 21, 24), INK)
	canvas.draw_rect(Rect2(-10, -10, 21, 24), Color("fff0ad") if selected else accent, false, 1.3)
	if kind == "rifle":
		_poly(canvas, [Vector2(-6, 1), Vector2(0, -6), Vector2(6, 1)], accent)
	elif kind == "rocket":
		_poly(canvas, [Vector2(-6, -2), Vector2(0, -8), Vector2(6, -2), Vector2(0, 4)], accent)
		canvas.draw_line(Vector2(-7, 4), Vector2(7, 4), accent, 2)
	elif kind == "gunner":
		for y in [-5, -1, 3]:
			canvas.draw_line(Vector2(-6, y), Vector2(6, y), accent, 2)
	else:
		canvas.draw_rect(Rect2(-6, -6, 12, 8), accent, false, 2)
		canvas.draw_line(Vector2(0, -7), Vector2(0, 3), accent, 2)
	canvas.draw_string(ThemeDB.fallback_font, Vector2(-6, 12), str(count), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color("f5efdb"))
	canvas.draw_set_transform(Vector2.ZERO)
