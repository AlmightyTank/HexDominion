extends SceneTree

var failures: int = 0
var checks: int = 0

class Gallery extends UnitLayer:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1200, 1480), Color("263b32"))
		var font: Font = ThemeDB.fallback_font
		draw_string(font, Vector2(20, 30), "Damage roster: healthy / damaged / destroyed / damaged stack, three factions", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		var row: int = 0
		for kind in UnitArt.CATEGORIES:
			var y: float = 80 + row * 52
			draw_string(font, Vector2(15, y), kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
			for faction in range(1, 4):
				var unit: UnitState = UnitState.new()
				unit.kind = kind
				unit.faction = faction
				unit.max_health = 100
				unit.facing = -PI / 2
				unit.turret_facing = unit.facing
				var x: float = 210 + (faction - 1) * 330
				for index in range(3):
					unit.health = [100, 35, 0][index]
					UnitAppearance.draw_unit(self, unit, Vector2(x + index * 65, y), Color.WHITE, false, 0, 1.5)
				UnitAppearance.strategic(self, kind, faction, Vector2(x + 210, y), 3, true, true, 1)
			row += 1
		row = 0
		for kind in EconomyState.BUILD_COSTS:
			var y: float = 800 + row * 62
			draw_string(font, Vector2(15, y), kind, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color.WHITE)
			for faction in range(1, 4):
				for index in range(3):
					_draw_building_badge(Vector2(210 + (faction - 1) * 330 + index * 75, y), kind, UnitArt.ACCENTS[faction - 1], false, 0, faction, ["base", "damaged", "destroyed"][index])
			row += 1
		for index in range(8):
			var unit: UnitState = UnitState.new()
			unit.configure_kind("tank" if index < 4 else "artillery")
			unit.health = unit.max_health * 0.35
			unit.facing = -PI / 2
			unit.turret_facing = -PI / 2 + (index % 4) * PI / 2
			unit.attack_flash = 0.14
			UnitAppearance.draw_unit(self, unit, Vector2(170 + index * 130, 1300), Color.WHITE, true, 0, 2)
		draw_string(font, Vector2(20, 1410), "Damaged armor: independent turret aiming and recoiling weapon-tip flashes", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	for kind in ["tank", "artillery"]:
		for faction in range(1, 4):
			for part in ["hull", "turret", "barrel"]:
				for state in ["base", "damaged"]:
					var texture: Texture2D = UnitArt.layer_texture(kind, faction, state, part)
					check(texture != null and texture.get_size() == Vector2(128, 128), "Armor layer " + kind + part + state)
					check(texture == UnitArt.layer_texture(kind, faction, state, part), "Cached armor layer")
				if part != "barrel":
					check(UnitArt.layer_texture(kind, faction, "base", part).get_image().get_data() != UnitArt.layer_texture(kind, faction, "damaged", part).get_image().get_data(), "Visible layer damage")
	for kind in EconomyState.BUILD_COSTS:
		for faction in range(1, 4):
			var images: Array[PackedByteArray] = []
			for state in ["base", "damaged", "destroyed"]:
				var texture: Texture2D = UnitArt.building_texture(kind, faction, state)
				check(texture != null, "Building state " + kind + state)
				if texture != null:
					check(texture.get_size() == Vector2(128, 128), "Building dimensions")
					check(texture.get_image().get_pixel(0, 0).a == 0, "Transparent building state")
					images.append(texture.get_image().get_data())
			check(images.size() == 3 and images[0] != images[1] and images[1] != images[2], "Distinct building states")
	var layer: UnitLayer = UnitLayer.new()
	root.add_child(layer)
	layer.set_physics_process(false)
	layer._watch_building_damage()
	for kind in EconomyState.BUILD_COSTS:
		var hex: Vector2i = Vector2i(layer.building_wrecks.size(), 0)
		layer.economy.add_building(hex, kind)
		check(UnitLayer.building_art_state(layer.economy.buildings[hex]) == "base", "Building starts healthy")
		layer.economy.damage_building(hex, 1)
		check(UnitLayer.building_art_state(layer.economy.buildings[hex]) == "damaged", "Damage selects new art")
		layer.economy.buildings[hex]["health"] = EconomyState.BUILD_HEALTH[kind]
		check(UnitLayer.building_art_state(layer.economy.buildings[hex]) == "base", "Repair restores healthy art")
		layer.economy.damage_building(hex, 10000)
		check(not layer.economy.buildings.has(hex) and layer.building_wrecks[-1]["kind"] == kind, "Destruction leaves cosmetic rubble only")
	var before: int = layer.building_wrecks.size()
	layer.economy.add_building(Vector2i(90, 0), "barracks")
	layer.economy.buildings.erase(Vector2i(90, 0))
	check(layer.building_wrecks.size() == before, "Noncombat removal creates no rubble")
	layer._watch_building_damage()
	check(layer.economy.building_destroyed.get_connections().size() == 1, "No duplicate damage listener")
	layer.match_state.rival_economy.add_building(Vector2i(91, 0), "extractor")
	layer.match_state.rival_economy.damage_building(Vector2i(91, 0), 10000)
	check(layer.building_wrecks[-1]["faction"] == 2, "Rival destruction retains owner")
	layer._physics_process(UnitLayer.WRECK_SECONDS + 1)
	check(layer.building_wrecks.is_empty(), "Rubble expires even outside a match")
	layer.free()
	print("Damage art: %d checks, %d failures" % [checks, failures])
	if failures > 0 or DisplayServer.get_name() == "headless":
		quit(1 if failures else 0)
		return
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1200, 1480)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var gallery: Gallery = Gallery.new()
	gallery.set_physics_process(false)
	viewport.add_child(gallery)
	await process_frame
	await RenderingServer.frame_post_draw
	var output: String = OS.get_environment("HEX_DOMINION_ART_CAPTURE")
	if output.is_empty():
		output = "user://damage-art.png"
	var error: Error = viewport.get_texture().get_image().save_png(output)
	print("Damage gallery: ", output, " ", error_string(error))
	quit(0 if error == OK else 1)
