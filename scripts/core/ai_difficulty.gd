extends RefCounted
class_name AIDifficulty
## Decision pacing and force composition only; every mode shares player rules and prices.

const EASY: String = "easy"
const MEDIUM: String = "medium"
const HARD: String = "hard"
const ORDER: Array[String] = [EASY, MEDIUM, HARD]
const PROFILES: Dictionary = {
	EASY: {
		"title": "Easy",
		"opening_delay": 16.0,
		"think_interval": 2.0,
		"army_limit": 4,
		"target_search_radius": 3,
		"bunker_limit": 0,
		"defender_limit": 0,
		"combined_arms": false,
		"air_and_naval": false,
	},
	MEDIUM: {
		"title": "Medium",
		"opening_delay": 12.0,
		"think_interval": 1.5,
		"army_limit": 6,
		"target_search_radius": 5,
		"bunker_limit": 1,
		"defender_limit": 1,
		"combined_arms": true,
		"air_and_naval": false,
	},
	HARD: {
		"title": "Hard",
		"opening_delay": 8.0,
		"think_interval": 1.0,
		"army_limit": 8,
		"target_search_radius": 6,
		"bunker_limit": 2,
		"defender_limit": 2,
		"combined_arms": true,
		"air_and_naval": true,
	},
}


static func is_valid(value: Variant) -> bool:
	return value is String and PROFILES.has(value)


static func profile(value: String) -> Dictionary:
	return PROFILES.get(value, PROFILES[EASY])


static func opening_delay(value: String) -> float:
	return float(profile(value)["opening_delay"])


static func think_interval(value: String) -> float:
	return float(profile(value)["think_interval"])
