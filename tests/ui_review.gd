extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var directory: String = OS.get_environment("HEX_DOMINION_RUNTIME_CAPTURE")
	if not directory.is_empty():
		assert(root.get_texture().get_image().save_png(directory.path_join("ui-" + label + ".png")) == OK)


func _run() -> void:
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var hud: StrategyHUD = current_scene.get_node("HUD/Overlay")
	for index in range(3):
		hud.command_tabs.current_tab = index
		await _capture("tab-%d" % index)
	hud.command_tabs.current_tab = 1
	for index in range(3):
		hud.production_tabs.current_tab = index
		await _capture("production-%d" % index)
	current_scene.set_process(false)
	var economy: EconomyState = EconomyState.new(1000)
	var territory: TerritoryState = TerritoryState.new()
	var producer: Vector2i = Vector2i(1, 1)
	territory.set_owner(producer, economy.faction)
	economy.add_building(producer, "barracks")
	assert(economy.train(producer, "rifle", territory))
	economy.advance(1, {}, territory)
	var rifle: UnitState = UnitState.new(Vector2i.ZERO, "rifle")
	rifle.configure_kind("rifle")
	hud.production_tabs.current_tab = 1
	hud.show_selection([rifle], false)
	hud.show_stack([rifle], [rifle], Vector2i(-1, -1), [rifle])
	hud.show_tile_actions(Vector2i(9, 9), economy, territory, {})
	assert(hud.command_tabs.current_tab == 1 and hud.production_tabs.current_tab == 1)
	assert("1 queued" in hud.production_queue.text)
	await _capture("production-fighting")
	hud.command_tabs.current_tab = 0
	await _capture("army-selected")
	current_scene.set_process(true)
	hud.match_action_requested.emit("pause")
	assert(hud.pause_overlay.visible)
	await _capture("pause")
	hud.show_save_browser("load", [])
	assert(hud.save_accept.disabled)
	assert(hud.save_message.text == "No saved matches yet.")
	await _capture("load-empty")
	hud.close_save_browser()
	hud.show_save_browser("save", [])
	assert(not hud.save_accept.disabled)
	hud.save_name.text = ""
	hud.save_name.text_changed.emit("")
	assert(hud.save_accept.disabled)
	await _capture("save-empty-name")
	hud.close_save_browser()
	hud.pause_overlay.hide()
	current_scene.set_process(false)
	hud.power_gauge.set_balance(20, 30)
	await _capture("power-low")
	assert(hud.power_gauge.demand == 30 and hud.power_gauge.supply == 20)
	hud.power_gauge.set_balance(80, 30)
	await _capture("power-restored")
	assert(not "\n" in hud.economy_summary.text)
	current_scene.set_process(true)
	hud.match_action_requested.emit("resume")
	DisplayServer.window_set_size(Vector2i(960, 640))
	await process_frame
	await process_frame
	hud.command_tabs.current_tab = 1
	assert(hud.power_gauge.size.y == hud.power_rail.size.y)
	assert(hud.power_rail.get_rect().end.y == hud.get_viewport_rect().size.y)
	await _capture("compact")
	var match_state: MatchState = MatchState.new()
	match_state.result = "victory"
	hud.show_match_status(match_state)
	assert(hud.match_panel.is_visible_in_tree())
	assert(hud.match_label.text.begins_with("VICTORY"))
	await _capture("victory")
	print("UI review passed: management and production tabs, pause/resume, empty saves, save-name validation, power states, compact capture, visible victory banner")
	quit()
