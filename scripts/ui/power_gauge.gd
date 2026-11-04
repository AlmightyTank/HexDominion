extends Control
class_name PowerGauge

var supply: float = 0
var demand: float = 0
var capacity: float = 40

func set_balance(available: float, used: float) -> void:
	supply = maxf(0, available)
	demand = maxf(0, used)
	capacity = maxf(40, ceilf(maxf(supply, demand) / 40.0) * 40)
	tooltip_text = "Power supplied: %d\nPower used: %d\n%s" % [supply, demand, "LOW POWER: factories at half speed; extractors offline" if demand > supply else "Power sufficient"]
	queue_redraw()

func _draw() -> void:
	if size.x < 36:
		var compact_track: Rect2 = Rect2(2, 8, maxf(4, size.x - 4), maxf(40, size.y - 16))
		draw_rect(compact_track, Color("101611"))
		draw_rect(Rect2(compact_track.position + Vector2(0, compact_track.size.y * (1 - supply / capacity)), Vector2(compact_track.size.x, compact_track.size.y * supply / capacity)), Color("f08075") if demand > supply else Color("a9bf73"))
		for step in range(1, 24):
			var segment_y: float = compact_track.position.y + compact_track.size.y * step / 24.0
			draw_line(Vector2(compact_track.position.x, segment_y), Vector2(compact_track.end.x, segment_y), Color("101923"), 2)
		draw_rect(compact_track, Color("969baa"), false)
		var marker_y: float = compact_track.end.y - compact_track.size.y * demand / capacity
		draw_line(Vector2(0, marker_y), Vector2(size.x, marker_y), Color.WHITE, 2)
		return
	var font: Font = ThemeDB.fallback_font
	var pale: Color = Color("f5efdb")
	var low: bool = demand > supply
	var fill: Color = Color("f08075") if low else Color("a9bf73")
	var track: Rect2 = Rect2(8, 38, 14, maxf(40, size.y - 84))
	draw_string(font, Vector2(5, 15), "PWR", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, pale)
	draw_string(font, Vector2(7, 30), str(int(supply)), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, pale)
	draw_rect(track, Color("101611"))
	draw_rect(Rect2(track.position + Vector2(0, track.size.y * (1 - supply / capacity)), Vector2(track.size.x, track.size.y * supply / capacity)), fill)
	for step in range(1, 8):
		var y: float = track.position.y + track.size.y * step / 8.0
		draw_line(Vector2(track.position.x, y), Vector2(track.end.x, y), Color("30392f"), 1)
	draw_rect(track, Color("777762"), false)
	var used_y: float = track.end.y - track.size.y * demand / capacity
	draw_line(Vector2(5, used_y), Vector2(27, used_y), pale, 2)
	draw_colored_polygon(PackedVector2Array([Vector2(23, used_y), Vector2(31, used_y - 4), Vector2(31, used_y + 4)]), pale)
	draw_string(font, Vector2(4, size.y - 27), "USE %d" % demand, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, pale)
	draw_string(font, Vector2(4, size.y - 10), "LOW" if low else "OK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, fill)
