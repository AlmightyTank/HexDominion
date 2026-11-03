extends RefCounted
class_name HexPathfinding
## Uniform-cost land routes. BFS is optimal while every land hex costs one step.

static func find_path(tiles: Dictionary, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if not is_walkable(tiles, start) or not is_walkable(tiles, goal):
		return empty
	var frontier: Array[Vector2i] = [start]
	var previous: Dictionary = {start: start}
	var head: int = 0
	while head < frontier.size():
		var current: Vector2i = frontier[head]
		head += 1
		if current == goal:
			var path: Array[Vector2i] = [goal]
			while path[-1] != start:
				path.append(previous[path[-1]])
			path.reverse()
			return path
		for neighbor in HexMath.neighbors(current):
			if not previous.has(neighbor) and is_walkable(tiles, neighbor):
				previous[neighbor] = current
				frontier.append(neighbor)
	return empty


static func is_walkable(tiles: Dictionary, hex: Vector2i) -> bool:
	return tiles.has(hex) and bool(tiles[hex].get("is_land", false))
