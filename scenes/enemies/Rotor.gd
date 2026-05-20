extends "res://scenes/enemies/Enemy.gd"

var target_player_x: float = 0.0
var swarm_phase: float = 0.0
var weave_frequency: float = 2.0
var weave_amplitude: float = 32.0

func _physics_process(delta: float) -> void:
	if stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	if player and is_instance_valid(player):
		target_player_x = player.global_position.x
		
	swarm_phase += delta * weave_frequency
	var drift = sin(swarm_phase) * weave_amplitude
	var diff = target_player_x - position.x
	velocity.x = move_toward(velocity.x, diff + drift, 200.0 * delta)
	velocity.y = -speed
	move_and_slide()
