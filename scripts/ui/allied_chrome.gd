extends Control
## Procedural metal housing, sized independently of the command contents.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("1c2938"))
	for x in range(10):
		var metal: Color = Color("344454").lerp(Color("9baab7"), sin(float(x) / 10 * PI))
		draw_line(Vector2(x, 0), Vector2(x, size.y), metal)
		draw_line(Vector2(size.x - x, 0), Vector2(size.x - x, size.y), metal)
	draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), Color("8495a5"), false, 1)
	for y in [18.0, 264.0, size.y - 20]:
		for x in [5.0, size.x - 5]:
			draw_circle(Vector2(x, y), 3, Color("10131b"))
			draw_line(Vector2(x - 1, y - 1), Vector2(x + 1, y - 1), Color("d4d6e0"))
	var base: Rect2 = Rect2(12, size.y - 12, size.x - 24, 4)
	draw_style_box(CommandTheme.box(Color("245c93"), Color("638bb4")), base)
