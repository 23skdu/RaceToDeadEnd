extends Node

signal score_popped(position: Vector2, points: int, label: String)

const SCORE_VALUES: Dictionary = {
	rotor_kill = 50,
	scav_kill = 100,
	drone_kill = 200,
	civilian_protected = 500,
	pickup_collected = 0,
	segment_bonus = 100,
}

func register_kill(enemy_type: String, position: Vector2) -> void:
	var points = SCORE_VALUES.get(enemy_type + "_kill", 50)
	GameManager.add_score(points)
	score_popped.emit(position, points, "+" + str(points))

func register_civilian_protected(position: Vector2) -> void:
	GameManager.add_score(SCORE_VALUES.civilian_protected)
	score_popped.emit(position, SCORE_VALUES.civilian_protected, "PROTECTED!")

func register_pickup(pickup_type: String, position: Vector2) -> void:
	match pickup_type:
		"repair":
			GameManager.add_health(1)
		"boost":
			pass
		"ammo":
			pass
		"multiplier":
			GameManager.set_multiplier(GameManager.multiplier + 1)
