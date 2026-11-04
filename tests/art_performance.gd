extends SceneTree

class BuildingProbe extends UnitLayer:
	var measured: bool = false
	func _draw() -> void:
		var kinds: Array[String] = ["headquarters", "barracks", "factory", "extractor", "power_plant", "bunker"]
		for kind in kinds:
			UnitArt.building_texture(kind, 1)
		var start: int = Time.get_ticks_usec()
		for iteration in range(100):
			for kind in kinds:
				_draw_building_badge(Vector2(30, 30), kind, UnitArt.ACCENTS[0], false)
		print("Warm building body submission, mean us/building: ", (Time.get_ticks_usec() - start) / 600.0)
		measured = true

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.units.set_physics_process(false)
	game.camera.set_process(false)
	var home: Vector2i = game.units.units[0].hex
	game.units.units.clear()
	for index in range(1200):
		var unit: UnitState = UnitState.new(home + Vector2i(index % 20, index / 20), "benchmark")
		unit.configure_kind(UnitCatalog.TYPES.keys()[index % UnitCatalog.TYPES.size()])
		game.units.units.append(unit)
	var start: int = Time.get_ticks_usec()
	for iteration in range(100):
		UnitVisuals.stacks(game.units.units)
	print("Uncached stacks, 1200 units, mean us: ", (Time.get_ticks_usec() - start) / 100.0)
	if game.units.has_method("visual_stacks"):
		game.units.visual_stacks()
		start = Time.get_ticks_usec()
		for iteration in range(100):
			game.units.visual_stacks()
		print("Validated cached stacks, mean us: ", (Time.get_ticks_usec() - start) / 100.0)
	var shared: int = 0
	for kind in UnitArt.CATEGORIES:
		for faction in range(1, 4):
			if UnitArt.texture(kind, faction) == UnitArt.texture(kind, faction, "icon"):
				shared += 1
	print("Shared base/icon texture pairs: ", shared, "/39")
	for frame in range(120):
		game.units.queue_redraw()
		await process_frame
		await RenderingServer.frame_post_draw
	print("Rendered draw calls: ", Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	print("Texture memory bytes: ", Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED))
	var probe: BuildingProbe = BuildingProbe.new()
	root.add_child(probe)
	await process_frame
	await RenderingServer.frame_post_draw
	assert(probe.measured)
	probe.free()
	game.free()
	quit()
