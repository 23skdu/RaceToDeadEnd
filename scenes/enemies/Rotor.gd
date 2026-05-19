extends "res://scenes/enemies/Enemy.gd"

var target_player_x: float = 0.0
var swarm_phase: float = 0.0
var weave_frequency: float = 2.0
var weave_amplitude: float = 32.0
var player: Node = null

func _physics_process(delta: float) -> void:
	if not player or not is_instance_valid(player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]
			
	if player:
		target_player_x = player.global_position.x
		
	swarm_phase += delta * weave_frequency
	var drift = sin(swarm_phase) * weave_amplitude
	var diff = target_player_x - position.x
	velocity.x = move_toward(velocity.x, diff + drift, 200.0 * delta)
	velocity.y = -speed
	move_and_slide()

func set_target_x(player_x: float) -> void:
	target_player_x = player_x
