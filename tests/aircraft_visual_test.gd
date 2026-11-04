extends SceneTree

var output: String = "user://aircraft-visuals"
var failures: int = 0

func _initialize() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
	call_deferred("run")

func capture(name: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	if image == null or image.is_empty() or image.save_png(output.path_join(name + ".png")) != OK:
		failures += 1
	return image

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	root.size = Vector2i(1440, 900)
	var game: Node2D = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.units.set_physics_process(false)
	game.camera.set_process(false)
	var home: Vector2i = game.units.units[0].hex
	var tiles: Dictionary = game.world_map.map_data["tiles"]
	game.units.economy.add_building(home, "airfield")
	game.units.units.clear()
	for faction in [1, 2]:
		for kind in ["tank", "anti_air", "helicopter", "helicopter", "fighter"]:
			var member: UnitState = UnitState.new(home, UnitCatalog.TYPES[kind]["name"])
			member.configure_kind(kind)
			member.faction = faction
			member.airfield = home
			member.facing = -PI / 3 if faction == 1 else PI / 2
			game.units.units.append(member)
	var helicopter: UnitState = game.units.units[2]
	game.units.select_one(helicopter)
	game._process(0)
	for entry in [["aircraft-far", 0.45], ["aircraft-medium", 1.0], ["aircraft-close", 2.3]]:
		game.camera.restore_view(game.world_map.hex_to_world(home), Vector2.ONE * entry[1])
		game.units.queue_redraw()
		await capture(entry[0])
	game.units.animation_time = 0
	game.units.queue_redraw()
	var idle: Image = await capture("aircraft-rotor-idle")
	game.units.animation_time = 0.045
	game.units.queue_redraw()
	var rotor: Image = await capture("aircraft-rotor-moving")
	if idle.get_data() == rotor.get_data():
		failures += 1
	for member in game.units.units:
		if member.domain == "air":
			member.attack_flash = 0.14
			member.damage_flash = 0.18
	game.units.shell_effects.append({"from": game.units.unit_position(helicopter), "to": game.units.unit_position(game.units.units[6]), "age": 0.2})
	game.units.queue_redraw()
	await capture("aircraft-missile-flight")
	for member in game.units.units:
		if member.domain == "air":
			for hex in HexMath.neighbors(home):
				if tiles.has(hex):
					member.order_move(tiles, hex)
					member.advance(member.seconds_per_hex * 0.5, tiles)
	game.units.queue_redraw()
	await capture("aircraft-directional-flight")
	if game.units.units.size() != 10:
		failures += 1
	print("Aircraft rendered fixture: %d failures. Images: %s" % [failures, ProjectSettings.globalize_path(output)])
	game.free()
	quit(1 if failures else 0)
