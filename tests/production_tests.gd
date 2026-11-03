extends SceneTree


func _initialize() -> void:
	var economy: EconomyState = EconomyState.new(1000)
	var territory: TerritoryState = TerritoryState.new()
	var first: Vector2i = Vector2i(1, 1)
	var second: Vector2i = Vector2i(2, 1)
	var factory: Vector2i = Vector2i(3, 1)
	for hex in [first, second, factory]:
		territory.set_owner(hex, economy.faction)
	economy.add_building(first, "barracks")
	economy.add_building(second, "barracks")
	economy.add_building(factory, "factory")
	assert(economy.production_site("rifle", territory) == second)
	assert(economy.production_site("tank", territory) == factory)
	assert(economy.set_primary(first, territory))
	assert(economy.production_site("rifle", territory) == first)
	assert(economy.train(economy.production_site("rifle", territory), "rifle", territory))
	assert(economy.buildings[first]["queue"] == ["rifle"])
	territory.set_owner(first, 2)
	assert(economy.production_site("rifle", territory) == second)
	economy.buildings[second]["construction"] = 0.0
	assert(economy.production_site("rifle", territory) == null)
	print("Production tests passed: newest, explicit primary, independent unit categories, queue routing, capture fallback, unfinished exclusion")
	quit()
