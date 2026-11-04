extends SceneTree

class Gallery extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1440, 1650), Color("192326"))
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(16, 23), "A base / damage / wreck / icon     B base / damage / wreck / icon     C base / damage / wreck / icon", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
		var row: int = 0
		for kind in UnitArt.CATEGORIES:
			var y: float = 65 + row * 88
			draw_string(font, Vector2(10, y + 5), kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
			for faction in range(1, 4):
				var column: int = 0
				for state in ["base", "damaged", "destroyed", "icon"]:
					var x: float = 175 + (faction - 1) * 400 + column * 90
					UnitArt.draw(self, kind, faction, state, Vector2(x, y), -PI / 2, false, 64)
					UnitArt.draw(self, kind, faction, state, Vector2(x + 35, y + 25), -PI / 2, false, 25)
					column += 1
			row += 1
		var colors: Array[Color] = [Color("dfe9ec"), Color("486d43"), Color("d4b575"), Color("24516b"), Color("788188")]
		for terrain in range(colors.size()):
			var x: float = terrain * 285
			draw_rect(Rect2(x, 1230, 280, 110), colors[terrain])
			for index in range(6):
				UnitArt.draw(self, UnitArt.CATEGORIES.keys()[index], 1, "base", Vector2(x + 25 + index * 44, 1280), -PI / 2, true, 28)
		for index in range(13):
			UnitAppearance.strategic(self, UnitArt.CATEGORIES.keys()[index], 1 + index % 3, Vector2(45 + index * 104, 1400), 125 + index, true, true, 1)
		draw_rect(Rect2(0, 1460, 1440, 180), Color("dfdfdf"))
		draw_string(font, Vector2(16, 1480), "Black silhouettes, same roster order (infantry share a hexagonal frame)", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.BLACK)
		for index in range(13):
			var image: Texture2D = UnitArt.texture(UnitArt.CATEGORIES.keys()[index], 1)
			draw_texture_rect(image, Rect2(12 + index * 108, 1500, 64, 64), false, Color.BLACK)
			draw_texture_rect(image, Rect2(32 + index * 108, 1585, 28, 28), false, Color.BLACK)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1440, 1650)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(Gallery.new())
	await process_frame
	await RenderingServer.frame_post_draw
	var output: String = OS.get_environment("HEX_FRONTLINES_ART_CAPTURE")
	if output.is_empty():
		output = "user://unit-art-gallery.png"
	var error: Error = viewport.get_texture().get_image().save_png(output)
	print("Art gallery: ", output, " ", error_string(error))
	quit(0 if error == OK else 1)
