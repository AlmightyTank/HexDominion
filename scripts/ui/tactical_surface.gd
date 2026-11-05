extends Control

var deck: bool = false
var values: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func update_values(next: Dictionary) -> void:
	if values != next:
		values = next
		queue_redraw()

func _draw() -> void:
	var scale: float = size.x / (720.0 if deck else 900.0)
	draw_rect(Rect2(Vector2.ZERO, size), Color("112333") if deck else Color("142739"))
	draw_line(Vector2.ZERO if deck else Vector2(0, size.y - 1), Vector2(size.x, 0 if deck else size.y - 1), Color("4e7486"), 2)
	var font: Font = ThemeDB.fallback_font
	if deck:
		var count: int = values.get("count", 0)
		if count > 0:
			var health: float = clampf(values.get("health", 0.0), 0.0, 1.0)
			var health_color: Color = Color("5cb487") if health >= 0.67 else (Color("d19a4c") if health >= 0.34 else Color("d97872"))
			_write(font, "SELECTED FORCE", Vector2(175, 16), 10, Color("a6c4d4"), scale)
			_write(font, "1 UNIT" if count == 1 else "%d UNITS" % count, Vector2(175, 40), 20, CommandTheme.TEXT, scale)
			_write(font, values.get("composition", ""), Vector2(175, 57), 11, Color("c0d4df"), scale, 210 * scale)
			_write(font, "HEALTH", Vector2(175, 74), 9, Color("a6c4d4"), scale)
			draw_rect(Rect2(Vector2(222, 67) * scale, Vector2(127, 7) * scale), Color("2a4857"))
			draw_rect(Rect2(Vector2(222, 67) * scale, Vector2(127 * health, 7) * scale), health_color)
			_write(font, "%d%%" % roundi(health * 100.0), Vector2(356, 74), 9, health_color, scale, 30 * scale)
		else:
			_write(font, "FIELD COMMAND", Vector2(175, 16), 10, Color("a6c4d4"), scale)
			_write(font, "No force selected", Vector2(175, 40), 18, CommandTheme.TEXT, scale)
			_write(font, "Select units on the battlefield to issue orders.", Vector2(175, 59), 11, Color("c0d4df"), scale, 210 * scale)
	else:
		_write(font, "HEX FRONTLINES", Vector2(18, 20), 17, Color("e9f4fc"), scale)
		_write(font, "WORLD CONQUEST", Vector2(18, 34), 10, Color("a6c4d4"), scale)
		var entries: Array = [[221, "CREDITS", values.get("credits", "0")], [346, "INCOME", values.get("income", "60s +0")]]
		for entry in entries:
			_write(font, entry[1], Vector2(entry[0], 12), 10, Color("a6c4d4"), scale)
			_write(font, entry[2], Vector2(entry[0], 33), 17, CommandTheme.TEXT, scale)

func _write(font: Font, text: String, point: Vector2, font_size: int, color: Color, scale: float, width: float = -1) -> void:
	draw_string(font, point * scale, text, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(font_size * scale), color)
