extends "res://scripts/scenes/enemies/Enemy.gd"

var target_player_x: float = 0.0
var bounce_timer: float = 0.0
const BOUNCE_FREQUENCY: float = 3.5
const BOUNCE_HEIGHT: float = 14.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if stunned:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	if player and is_instance_valid(player):
		target_player_x = player.global_position.x
		var target_y = player.global_position.y - 70.0
		var diff_y = target_y - position.y
		velocity.y = move_toward(velocity.y, diff_y * 3.0, 180.0 * delta)
	else:
		velocity.y = -speed * 0.3

	var diff = target_player_x - position.x
	velocity.x = move_toward(velocity.x, diff, 150.0 * delta)
	move_and_slide()

	# Bouncing visual and audio triggers
	var old_cycle = int(bounce_timer * BOUNCE_FREQUENCY)
	bounce_timer += delta
	var new_cycle = int(bounce_timer * BOUNCE_FREQUENCY)
	if new_cycle > old_cycle:
		AudioManager.play_synth_bounce(global_position)
		
	var bounce_phase = fmod(bounce_timer * BOUNCE_FREQUENCY * PI, PI)
	var bounce_height = sin(bounce_phase)
	if sprite:
		sprite.position.y = -bounce_height * BOUNCE_HEIGHT

func on_pool_release() -> void:
	super.on_pool_release()
	bounce_timer = 0.0
	if sprite:
		sprite.position = Vector2.ZERO
