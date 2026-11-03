extends SceneTree
## Rendered benchmark: godot --path . --script res://tests/profile_map.gd --disable-vsync
## Headless mode cannot measure GPU rendering or draw calls.


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Run this benchmark with a rendering display, not --headless.")
		quit(1)
		return
	root.size = Vector2i(1280, 720)
	var scene: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(scene)
	var camera: StrategyCamera = scene.get_node("Camera2D")
	for frame in range(30):
		await process_frame
	var map: WorldMap = scene.get_node("WorldMap")
	var cache: SubViewport = map.get_node("TerrainCache")
	var image: Image = cache.get_texture().get_image()
	if image.is_empty() or image.get_pixel(image.get_width() / 2, image.get_height() / 2).a < 0.9:
		push_error("Terrain cache did not render an opaque map center.")
		quit(1)
		return
	# Check selection on both staggered rows without invalidating static terrain.
	for row in [20, 21]:
		var key: Vector2i = WorldMapData.offset_to_axial(60, row)
		var tile: Dictionary = map.inspect_at_world(map.hex_to_world(key))
		if tile.get("axial") != key:
			push_error("Cached map selection is misaligned.")
			quit(1)
			return
		await process_frame
	# Some versions keep UPDATE_ONCE in the property after the renderer consumes it.
	if cache.render_target_update_mode not in [SubViewport.UPDATE_ONCE, SubViewport.UPDATE_DISABLED]:
		push_error("Static terrain cache is configured to render repeatedly.")
		quit(1)
		return
	var capture_path: String = OS.get_environment("HEX_DOMINION_CAPTURE")
	if not capture_path.is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(capture_path)
	var elapsed_usec: int = 0
	var draw_calls: float = 0.0
	var samples: int = 180
	for frame in range(samples):
		var start: int = Time.get_ticks_usec()
		# Exercise panning and zoom as well as the full-world overview.
		if frame == 60:
			camera.zoom_centered(2.0)
		elif frame == 120:
			camera.reset_view()
		if frame >= 60 and frame < 120:
			camera.pan_screen_pixels(Vector2(2.0, 0.0))
		await process_frame
		elapsed_usec += Time.get_ticks_usec() - start
		draw_calls += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	print("Map benchmark: %.2f ms/frame, %.1f draw calls/frame (%d samples; %s)" % [float(elapsed_usec) / samples / 1000.0, draw_calls / samples, samples, DisplayServer.get_name()])
	if draw_calls / samples > 100.0:
		push_error("Map rendering exceeded the 100 draw-call budget.")
		quit(1)
	else:
		quit()
