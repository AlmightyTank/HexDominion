extends SceneTree

var output: String = "user://vehicle-visuals"
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
	game.units.units.clear()
	for faction in [1, 2]:
		for kind in ["tank", "scout", "apc", "anti_air"]:
			for index in range(2):
				var unit: UnitState = UnitState.new(home, UnitCatalog.TYPES[kind]["name"])
				unit.configure_kind(kind)
				unit.faction = faction
				unit.facing = PI if faction == 2 else 0.0
				unit.turret_facing = -PI / 2 if faction == 1 else PI / 2
				if index == 1:
					unit.health *= 0.6
				game.units.units.append(unit)
	for kind in UnitCatalog.INFANTRY:
		var unit: UnitState = UnitState.new(home, kind)
		unit.configure_kind(kind)
		game.units.units.append(unit)
	var apc: UnitState = game.units.units[4]
	for index in range(4):
		var unit: UnitState = UnitState.new(home, "Passenger")
		game.units.units.append(unit)
		TransportRules.load(unit, apc, game.units.units)
	game.units.select_one(apc)
	game.hud.command_tabs.current_tab = 2
	game._process(0)
	for entry in [["vehicles-far", 0.45], ["vehicles-medium", 1.0], ["vehicles-close", 2.3]]:
		game.camera.restore_view(game.world_map.hex_to_world(home), Vector2.ONE * entry[1])
		game.units.queue_redraw()
		await capture(entry[0])
		if game.units.units.size() != 23 or TransportRules.passengers(apc, game.units.units).size() != 4:
			failures += 1
	game.units.expanded_hex = home
	game.units.queue_redraw()
	await capture("vehicles-expanded")
	var idle: Image = await capture("vehicles-idle")
	for unit in game.units.units:
		unit.attack_flash = 0.12
		unit.damage_flash = 0.12
	game.units.queue_redraw()
	var firing: Image = await capture("vehicles-firing")
	if idle.get_data() == firing.get_data():
		failures += 1
	for unit in game.units.units:
		unit.attack_flash = 0
		unit.damage_flash = 0
		if unit.is_deployed():
			unit.path.append(HexMath.neighbors(home)[0])
	game.units.animation_time = 0.30
	game.units.queue_redraw()
	var moving: Image = await capture("vehicles-moving")
	game.units.animation_time = 0.45
	game.units.queue_redraw()
	var moving_next: Image = await capture("vehicles-moving-next")
	if moving.get_data() == moving_next.get_data():
		failures += 1
	for unit in game.units.units:
		unit.order_hold()
	TransportRules.unload(apc, home, game.world_map.map_data["tiles"], game.units.units)
	game.units.queue_redraw()
	game._process(0)
	await capture("vehicles-unloaded")
	print("Vehicle rendered fixture: %d failures. Images: %s" % [failures, ProjectSettings.globalize_path(output)])
	game.free()
	quit(1 if failures else 0)
