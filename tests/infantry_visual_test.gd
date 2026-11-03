extends SceneTree
## Run with a real renderer (not --headless); writes reproducible review images.
var output: String = "user://infantry-visuals"
var failures: int = 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	call_deferred("_run")

func _capture(name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join(name + ".png")) != OK:
		failures += 1
		push_error("Could not capture " + name)
	return image

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1280, 900)
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.units.set_physics_process(false)
	game.camera.set_process(false)
	var home: Vector2i = game.units.units[0].hex
	game.units.units.clear()
	for faction in [1, 2]:
		for kind in UnitCatalog.INFANTRY:
			for index in range(3):
				var unit: UnitState = UnitState.new(home, UnitCatalog.TYPES[kind]["name"])
				unit.configure_kind(kind)
				unit.faction = faction
				unit.facing = 0.0 if faction == 1 else PI
				if index == 1:
					unit.health *= 0.6
				game.units.units.append(unit)
	game.units.select_one(game.units.units[0])
	game.units.selected_units.append(game.units.units[6])
	game.hud.command_tabs.current_tab = 1
	for entry in [["far", 0.45], ["medium", 1.0], ["close", 2.3]]:
		game.camera.restore_view(game.world_map.hex_to_world(home), Vector2.ONE * entry[1])
		game.units.queue_redraw()
		await _capture(entry[0])
		if game.units.units.size() != 18:
			failures += 1
	# Record real feedback frames independently of wall-clock speed.
	var idle: Image = await _capture("idle")
	game.units.animation_time = 0.14
	for unit in game.units.units:
		unit.attack_flash = 0.12
		unit.damage_flash = 0.12
	game.units.queue_redraw()
	var firing: Image = await _capture("attack-damage")
	if idle != null and firing != null and idle.get_data() == firing.get_data():
		failures += 1
		push_error("Feedback frames did not change")
	for unit in game.units.units:
		unit.attack_flash = 0
		unit.damage_flash = 0
		unit.path.append(HexMath.neighbors(home)[0])
	game.units.animation_time = 0.35
	game.units.queue_redraw()
	await _capture("moving")
	print("Infantry rendered verification: 18 independent units, three zoom tiers and feedback frames; %d failures. Images: %s" % [failures, ProjectSettings.globalize_path(output)])
	game.free()
	quit(1 if failures else 0)
