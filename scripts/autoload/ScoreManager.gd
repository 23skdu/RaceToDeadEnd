extends Node

signal score_popped(position: Vector2, points: int, label: String)

const SCORE_VALUES: Dictionary = {
	bunny_kill = 50,
	sasquatch_kill = 300,
	rotor_kill = 50,
	scav_kill = 100,
	drone_kill = 200,
	civilian_protected = 500,
	pickup_collected = 0,
	segment_bonus = 100,
}

var _cached_player: Node = null

func _ready() -> void:
	GameManager.game_started.connect(_on_game_started)
	GameManager.game_over.connect(_on_game_over)

func _on_game_started() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_cached_player = players[0]

func _on_game_over(_final_score: int) -> void:
	_cached_player = null

func register_kill(enemy_type: String, position: Vector2) -> void:
	var points = SCORE_VALUES.get(enemy_type + "_kill", 50)
	GameManager.add_score(points)
	score_popped.emit(position, points, "+" + str(points))

func register_civilian_protected(position: Vector2) -> void:
	GameManager.add_score(SCORE_VALUES.civilian_protected)
	score_popped.emit(position, SCORE_VALUES.civilian_protected, "PROTECTED!")

func register_civilian_damaged() -> void:
	score_popped.emit(Vector2.ZERO, 0, "CIVILIAN HIT!")

func register_pickup(pickup_type: String, _position: Vector2) -> void:
	match pickup_type:
		"repair":
			GameManager.add_health(1)
		"boost":
			if _cached_player and _cached_player.has_method("add_boost"):
				_cached_player.add_boost()
		"ammo":
			if _cached_player and _cached_player.has_method("add_ammo"):
				_cached_player.add_ammo()
		"multiplier":
			GameManager.add_temporary_multiplier(1)
