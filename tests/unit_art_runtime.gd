extends SceneTree

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.units.set_physics_process(false)
	var home: Vector2i = game.units.units[0].hex
	game.units.units.clear()
	for kind in UnitCatalog.TYPES:
		for index in range(3):
			var unit: UnitState = UnitState.new(home, kind)
			unit.configure_kind(kind)
			unit.health = unit.max_health * 0.4 if index == 0 else unit.max_health
			game.units.units.append(unit)
	var expected_count: int = game.units.units.size()
	for zoom_factor in [0.45, 1.0, 2.3]:
		game.camera.restore_view(game.world_map.hex_to_world(home), Vector2.ONE * zoom_factor)
		await process_frame
		var batches: Array[Dictionary] = UnitVisuals.stacks(game.units.units)
		var point: Vector2 = game.units.group_position(batches[0], batches, zoom_factor)
		game._select_at(game.units.to_global(point))
		assert(game.units.selected != null, "Mouse selection at each tier")
		game.units.select_one(null)
		var screen_point: Vector2 = root.get_canvas_transform() * game.units.to_global(point)
		var touch: InputEventScreenTouch = InputEventScreenTouch.new()
		touch.position = screen_point
		touch.pressed = true
		game._unhandled_input(touch)
		touch.pressed = false
		game._unhandled_input(touch)
		assert(game.units.selected != null, "Touch selection at each tier")
		game.units.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
		var directory: String = OS.get_environment("HEX_FRONTLINES_RUNTIME_CAPTURE")
		if not directory.is_empty():
			assert(root.get_texture().get_image().save_png(directory.path_join("unit-runtime-%s.png" % UnitVisuals.tier(zoom_factor))) == OK)
		assert(game.units.units.size() == expected_count)
		print("Runtime ", UnitVisuals.tier(zoom_factor), ": mouse/touch selected, ", expected_count, " simulation units unchanged")
	game.free()
	quit()
