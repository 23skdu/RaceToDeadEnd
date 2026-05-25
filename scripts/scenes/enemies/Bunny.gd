extends "res://scripts/scenes/enemies/Enemy.gd"

var target_player_x: float = 0.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	if player and is_instance_valid(player):
		target_player_x = player.global_position.x
		
	var diff = target_player_x - position.x
	velocity.x = move_toward(velocity.x, diff, 150.0 * delta)
	velocity.y = -speed
	move_and_slide()
