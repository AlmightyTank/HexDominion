extends SceneTree

class Gallery extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1000, 760), Color("263b32"))
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(20, 30), "Weapon-tip flashes: N / E / S / W, native, stack, faded", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		var row: int = 0
		for kind in UnitCatalog.TYPES:
			var y: float = 85 + row * 82
			draw_string(font, Vector2(15, y), kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
			var unit: UnitState = UnitState.new()
			unit.configure_kind(kind)
			unit.attack_flash = 0.14
			for facing in range(4):
				unit.facing = -PI / 2 + facing * PI / 2
				unit.turret_facing = unit.facing + (PI / 2 if kind in ["tank", "artillery"] else 0.0)
				UnitAppearance.draw_unit(self, unit, Vector2(180 + facing * 130, y), Color.WHITE, false, 0, 2)
			UnitAppearance.draw_unit(self, unit, Vector2(700, y), Color.WHITE, false, 0)
			UnitAppearance.strategic(self, kind, 1, Vector2(800, y), 4, false, false, 1, unit.turret_facing if kind in ["tank", "artillery"] else unit.facing)
			UnitAppearance.firing_effect(self, unit, Vector2(800, y), 1, true)
			unit.attack_flash = 0.01
			UnitAppearance.draw_unit(self, unit, Vector2(920, y), Color.WHITE, false, 0)
			row += 1

func _init() -> void:
	call_deferred("run")

func run() -> void:
	for kind in UnitCatalog.TYPES:
		assert(not UnitAppearance.muzzle_points(kind, 0.14).is_empty(), kind)
		assert(not UnitAppearance.muzzle_points(kind, 0.14, true).is_empty(), kind)
	assert(UnitAppearance.muzzle_points("rifle", 0.14)[0].is_equal_approx(Vector2(47, 15) * UnitVisuals.UNIT_BOX / 128))
	assert(UnitAppearance.muzzle_points("tank", 0.14)[0].is_equal_approx(Vector2(67 * UnitVisuals.UNIT_BOX / 128.0 - 2 * UnitVisuals.UNIT_BOX / UnitAppearance.CHROME_BASE, 0)))
	assert(UnitAppearance.muzzle_points("tank", 0)[0].is_equal_approx(Vector2(67 * UnitVisuals.UNIT_BOX / 128.0, 0)))
	assert(UnitAppearance.muzzle_points("artillery", 0.14)[0].is_equal_approx(Vector2(81 * UnitVisuals.UNIT_BOX / 128.0 - 4 * UnitVisuals.UNIT_BOX / UnitAppearance.CHROME_BASE, 0)))
	assert(UnitAppearance.muzzle_points("artillery", 0)[0].is_equal_approx(Vector2(81 * UnitVisuals.UNIT_BOX / 128.0, 0)))
	assert(UnitAppearance.muzzle_points("anti_air", 0.14).size() == 2)
	if DisplayServer.get_name() == "headless":
		print("Firing effect anchor checks passed")
		quit()
		return
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1000, 760)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.add_child(Gallery.new())
	await process_frame
	await RenderingServer.frame_post_draw
	var output: String = OS.get_environment("HEX_FRONTLINES_ART_CAPTURE")
	if output.is_empty():
		output = "user://firing-effects.png"
	var error: Error = viewport.get_texture().get_image().save_png(output)
	assert(error == OK)
	print("Firing effect anchor checks and gallery passed: ", output)
	quit()
