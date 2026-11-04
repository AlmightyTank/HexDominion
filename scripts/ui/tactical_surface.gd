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
		_write(font, "SELECTED ARMY" if values.get("count", 0) > 0 else "FIELD COMMAND", Vector2(175, 16), 11, Color("a6c4d4"), scale)
		_write(font, ("1 Unit" if values["count"] == 1 else "%d Units" % values["count"]) if values.get("count", 0) > 0 else "No army selected", Vector2(175, 37), 17, CommandTheme.TEXT, scale)
		_write(font, values.get("composition", "Select an army or inspect a territory."), Vector2(175, 55), 11, Color("c0d4df"), scale, 210 * scale)
		if values.get("count", 0) > 0:
			draw_style_box(CommandTheme.box(Color("2a4857"), Color("2a4857")), Rect2(Vector2(300, 29) * scale, Vector2(80, 6) * scale))
			draw_rect(Rect2(Vector2(300, 29) * scale, Vector2(80 * values.get("health", 0.0), 6) * scale), Color("5cb487"))
	else:
		_write(font, "HEX FRONTLINES", Vector2(18, 20), 17, Color("e9f4fc"), scale)
		_write(font, "WORLD CONQUEST", Vector2(18, 34), 10, Color("a6c4d4"), scale)
		var entries: Array = [[221, "CREDITS", values.get("credits", "0")], [346, "INCOME", values.get("income", "+0/min")]]
		for entry in entries:
			_write(font, entry[1], Vector2(entry[0], 12), 10, Color("a6c4d4"), scale)
			_write(font, entry[2], Vector2(entry[0], 33), 17, CommandTheme.TEXT, scale)

func _write(font: Font, text: String, point: Vector2, font_size: int, color: Color, scale: float, width: float = -1) -> void:
	draw_string(font, point * scale, text, HORIZONTAL_ALIGNMENT_LEFT, width, roundi(font_size * scale), color)
