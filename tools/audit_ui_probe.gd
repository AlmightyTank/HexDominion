extends SceneTree
## Temporary probe: measures where the new orders panel lands inside the inspector.

func _initialize() -> void:
	call_deferred("run")

func run() -> void:

	for size in [Vector2i(1152, 648), Vector2i(480, 960)]:
		get_root().size = size
		await process_frame
		await _measure(size)
	quit(0)

func _measure(size: Vector2i) -> void:
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	await process_frame
	var panel: Control = game.military_orders_panel
	var scroll: Control = game.hud.selection_panel
	var viewport: Vector2 = Vector2(get_root().size)
	print("UI viewport=%s scroll_size=%s scroll_rect=%s" % [viewport, scroll.size, scroll.get_global_rect()])
	print("UI panel_rect=%s panel_size=%s" % [panel.get_global_rect(), panel.size])
	var visible_rect: Rect2 = scroll.get_global_rect()
	var button: Control = panel.get_child(0)
	print("UI first_button=%s text=%s size=%s" % [button.get_global_rect(), button.text, button.size])
	print("UI first_button_visible=%s" % str(visible_rect.encloses(button.get_global_rect())))
	print("UI panel_fully_visible=%s" % str(visible_rect.encloses(panel.get_global_rect())))
	print("UI cursor_first_button=%d" % button.mouse_default_cursor_shape)
	print("UI checkbox_cursor=%d" % panel.rally_attack_move.mouse_default_cursor_shape)
	print("UI scroll_v_mode=%d" % scroll.vertical_scroll_mode)
	# With a selection the window grows; measure that case too.
	var unit: UnitState = game.units.units[0]
	game.units.select_one(unit)
	game.hud.show_selection(game.units.selected_units, false, game.units.units)
	await process_frame
	print("UI with_selection scroll_size=%s panel_rect=%s" % [scroll.size, panel.get_global_rect()])
	print("UI with_selection panel_fully_visible=%s" % str(scroll.get_global_rect().encloses(panel.get_global_rect())))
	game.free()
