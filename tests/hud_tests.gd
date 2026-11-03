extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var hud: StrategyHUD = current_scene.get_node("HUD/Overlay")
	assert(hud.command_tabs.get_tab_count() == 4)
	for index in range(4):
		hud.command_tabs.current_tab = index
		await process_frame
		assert(hud.command_tabs.get_current_tab_control().visible)
	var requests: Array[String] = []
	hud.build_requested.connect(func(kind: String) -> void: requests.append(kind))
	hud.build_buttons["barracks"].pressed.emit()
	assert(requests == ["barracks"])
	var camera: StrategyCamera = current_scene.get_node("Camera2D")
	var map_rect: Rect2 = camera.map_screen_rect()
	assert(map_rect.end.x <= hud.build_panel.position.x)
	assert(map_rect.end.y <= hud.help_panel.position.y)
	assert(map_rect.end.y <= hud.match_panel.position.y)
	camera.reset_view()
	var world: WorldMap = current_scene.get_node("WorldMap")
	var canvas: Transform2D = root.get_canvas_transform()
	assert((canvas * world.world_bounds().get_center()).distance_to(map_rect.get_center()) < 1.0)
	assert(map_rect.encloses(Rect2(canvas * world.world_bounds().position, world.world_bounds().size * camera.zoom)))
	camera.restore_view(Vector2.ZERO, Vector2.ONE)
	var cursor: Vector2 = map_rect.get_center() + Vector2(20, 10)
	var under_cursor: Vector2 = root.get_canvas_transform().affine_inverse() * cursor
	camera.zoom_at_screen_point(cursor, 1.14)
	assert((root.get_canvas_transform().affine_inverse() * cursor).distance_to(under_cursor) < 1.0)
	var before: Vector2 = camera.position
	hud.radar._navigate(hud.radar.size * Vector2(0.8, 0.5))
	assert(camera.position != before)
	hud.match_action_requested.emit("pause")
	assert(hud.pause_overlay.visible)
	hud.match_action_requested.emit("resume")
	assert(not hud.pause_overlay.visible)
	print("HUD tests passed: reserved map bounds, whole-map fit, centering, cursor zoom, four tabs, build signal, radar navigation, pause/resume")
	quit()
