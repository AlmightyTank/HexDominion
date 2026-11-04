extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var directory: String = OS.get_environment("HEX_FRONTLINES_RUNTIME_CAPTURE")
	if not directory.is_empty():
		assert(root.get_texture().get_image().save_png(directory.path_join("ui-" + label + ".png")) == OK)


func _run() -> void:
	create_timer(45).timeout.connect(func() -> void:
		push_error("UI review exceeded 45 seconds; check assertion output")
		quit(1)
	)
	root.size = Vector2i(1280, 720)
	change_scene_to_file("res://scenes/main.tscn")
	await process_frame
	await process_frame
	var hud: StrategyHUD = current_scene.get_node("HUD/Overlay")
	assert(hud.command_tabs.get_tab_count() == 1 and not hud.command_tabs.tabs_visible)
	await _capture("production-sidebar")
	for index in range(4):
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
	hud.production_tabs.current_tab = 2
	hud.show_selection([rifle], false)
	hud.show_stack([rifle], [rifle], Vector2i(-1, -1), [rifle])
	hud.show_tile_actions(Vector2i(9, 9), economy, territory, {})
	assert(hud.command_tabs.current_tab == 0 and hud.production_tabs.current_tab == 2)
	assert("1 queued" in hud.production_queue.text)
	await _capture("production-fighting")
	hud.command_tabs.current_tab = 0
	hud.context_expanded = true
	hud._layout_for_viewport()
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
	root.size = Vector2i(760, 640)
	await process_frame
	await process_frame
	hud.command_tabs.current_tab = 0
	assert(hud.mobile_layout)
	assert(not hud.production_open)
	await _capture("compact")
	hud.production_toggle.pressed.emit()
	await _capture("compact-production")
	root.size = Vector2i(390, 844)
	await process_frame
	await process_frame
	if not hud.production_open:
		hud.production_toggle.pressed.emit()
	await _capture("phone-production")
	var match_state: MatchState = MatchState.new()
	match_state.result = "victory"
	hud.show_match_status(match_state)
	assert(hud.match_panel.is_visible_in_tree())
	assert(hud.match_label.text.begins_with("VICTORY"))
	await _capture("victory")
	print("UI review passed: production-only sidebar and four categories, pause/resume, empty saves, save-name validation, power states, compact capture, visible victory banner")
	quit()
