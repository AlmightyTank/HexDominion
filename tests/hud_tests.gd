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
	camera.restore_view(Vector2.ZERO, Vector2.ONE)
	var before: Vector2 = camera.position
	hud.radar._navigate(hud.radar.size * Vector2(0.8, 0.5))
	assert(camera.position != before)
	hud.match_action_requested.emit("pause")
	assert(hud.pause_overlay.visible)
	hud.match_action_requested.emit("resume")
	assert(not hud.pause_overlay.visible)
	print("HUD tests passed: four tabs, build signal, radar navigation, pause/resume")
	quit()
