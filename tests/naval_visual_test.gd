extends SceneTree

var output: String = "user://naval-visuals"
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
	var tiles: Dictionary = game.world_map.map_data["tiles"]
	var coast: Vector2i
	var sea: Vector2i
	for hex in tiles:
		if tiles[hex].get("row", 0) < 20 or tiles[hex].get("row", 0) > 50:
			continue
		var port: Variant = NavalRules.deployment(tiles, hex)
		if port == null:
			continue
		var neighbors: int = 0
		for adjacent in HexMath.neighbors(port):
			neighbors += int(NavalRules.water(tiles, adjacent))
		if neighbors >= 4:
			coast = hex
			sea = port
			break
	game.units.territory.set_owner(coast, 1)
	game.units.economy.add_building(coast, "shipyard")
	game.units.units.clear()
	for faction in [1, 2]:
		for kind in ["patrol_boat", "destroyer", "landing_transport"]:
			var member: UnitState = UnitState.new(sea, UnitCatalog.TYPES[kind]["name"])
			member.configure_kind(kind)
			member.faction = faction
			member.facing = -PI / 3 if faction == 1 else PI / 2
			game.units.units.append(member)
	var ship: UnitState = game.units.units[2]
	for kind in ["rifle", "tank"]:
		var cargo: UnitState = UnitState.new(coast)
		cargo.configure_kind(kind)
		game.units.units.append(cargo)
		# No enemy ground defenders on the loading coast.
		if not TransportRules.load(cargo, ship, game.units.units, tiles):
			failures += 1
	game.units.select_one(ship)
	game._process(0)
	for entry in [["naval-far", 0.45], ["naval-medium", 1.0], ["naval-close", 2.3]]:
		game.camera.restore_view(game.world_map.hex_to_world(sea), Vector2.ONE * entry[1])
		game.units.queue_redraw()
		await capture(entry[0])
	for member in game.units.units:
		if member.domain != "naval":
			continue
		for hex in HexMath.neighbors(sea):
			if NavalRules.water(tiles, hex):
				member.order_move(tiles, hex)
				member.advance(member.seconds_per_hex * 0.3, tiles)
				break
	game.units.animation_time = 0
	game.units.queue_redraw()
	var idle: Image = await capture("naval-wake-a")
	game.units.animation_time = 0.5
	game.units.queue_redraw()
	var wake: Image = await capture("naval-wake-b")
	if idle.get_data() == wake.get_data():
		failures += 1
	for member in game.units.units:
		if member.kind in ["patrol_boat", "destroyer"]:
			member.attack_flash = 0.14
			member.damage_flash = 0.18
	game.units.queue_redraw()
	await capture("naval-firing")
	if game.units.units.size() != 8 or TransportRules.passengers(ship, game.units.units).size() != 2:
		failures += 1
	print("Naval rendered fixture: %d failures. Images: %s" % [failures, ProjectSettings.globalize_path(output)])
	game.free()
	quit(1 if failures else 0)
