extends "res://scripts/scenes/enemies/Enemy.gd"

var jump_timer: float = 0.0

func _ready() -> void:
	super._ready()
	hp = 1
	score_value = 100
	speed = 150.0
	
	if not sprite.texture:
		var img = Image.create(32, 32, false, Image.FORMAT_RGBA8)
		img.fill(Color(1.0, 0.5, 0.8, 1.0))
		sprite.texture = ImageTexture.create_from_image(img)

func on_pool_acquire() -> void:
	hp = 1
	speed = 150.0

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if stunned:
		return
		
	if player and is_instance_valid(player):
		velocity.x = move_toward(velocity.x, sign(player.global_position.x - global_position.x) * speed, 200.0 * delta)
	velocity.y = speed
	
	var collision = move_and_collide(velocity * delta)
	if collision:
		var col = collision.get_collider()
		if col.name == "Player":
			_die()
