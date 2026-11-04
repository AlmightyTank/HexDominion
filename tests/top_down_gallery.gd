extends SceneTree

class Gallery extends UnitLayer:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1100, 1450), Color("192326"))
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(20, 28), "Top-down roster: A / B / C, enlarged and native-size", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("f5efdb"))
		var row: int = 0
		for kind in UnitArt.CATEGORIES:
			var y: float = 75 + row * 55
			draw_string(font, Vector2(20, y), kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
			for faction in range(1, 4):
				var point: Vector2 = Vector2(230 + (faction - 1) * 295, y - 5)
				UnitArt.draw(self, kind, faction, "base", point, -PI / 2, false, 48)
				UnitArt.draw(self, kind, faction, "base", point + Vector2(65, 0), -PI / 2, true, 28)
				UnitArt.draw(self, kind, faction, "damaged", point + Vector2(110, 0), -PI / 2, false, 28)
				UnitAppearance.strategic(self, kind, faction, point + Vector2(155, 0), 7, false, false, 1)
			row += 1
		row = 0
		for kind in EconomyState.BUILD_COSTS:
			var y: float = 810 + row * 65
			draw_string(font, Vector2(20, y), kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
			for faction in range(1, 4):
				var point: Vector2 = Vector2(230 + (faction - 1) * 295, y - 5)
				draw_texture_rect(UnitArt.building_texture(kind, faction), Rect2(point - Vector2(24, 24), Vector2(48, 48)), false)
				_draw_building_badge(point + Vector2(65, 0), kind, UnitArt.ACCENTS[faction - 1], true)
			row += 1
		for index in range(4):
			var point: Vector2 = Vector2(220 + index * 210, 1270)
			draw_rect(Rect2(point - Vector2(65, 45), Vector2(130, 100)), Color("486d43"))
			UnitArt.draw(self, "rifle", 1, "base", point, -PI / 2 + index * PI / 2, true, 64)
			UnitArt.draw(self, "rifle", 1, "base", point + Vector2(0, 85), -PI / 2 + index * PI / 2, true, 28)
		draw_string(font, Vector2(20, 1420), "Soldier facing: north / east / south / west. Selection stays upright.", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1100, 1450)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(Gallery.new())
	await process_frame
	await RenderingServer.frame_post_draw
	var output: String = OS.get_environment("HEX_FRONTLINES_ART_CAPTURE")
	if output.is_empty():
		output = "user://top-down-gallery.png"
	var error: Error = viewport.get_texture().get_image().save_png(output)
	print("Top-down gallery: ", output, " ", error_string(error))
	quit(0 if error == OK else 1)
