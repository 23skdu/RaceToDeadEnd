extends Area2D

var speed: float = Constants.BULLET_SPEED * 0.6
var direction: Vector2 = Vector2.DOWN
var damage: int = 1

func _ready() -> void:
	z_index = 2
	add_to_group("enemy_projectile")
	body_entered.connect(_on_body_entered)
	$VisibleOnScreenNotifier2D.screen_exited.connect(_on_visible_on_screen_notifier_screen_exited)
	
	if not $Sprite2D.texture:
		var img = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.4, 0.25, 0.1, 1.0))
		$Sprite2D.texture = ImageTexture.create_from_image(img)

func init(pos: Vector2, dir: Vector2, _player_owned: bool = false) -> void:
	global_position = pos
	direction = dir.normalized()
	collision_layer = 4
	collision_mask = 1

func _physics_process(delta: float) -> void:
	position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	if body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(damage)
		if body.has_method("set_slippery"):
			body.set_slippery(true)
			get_tree().create_timer(2.0).timeout.connect(func(): if is_instance_valid(body): body.set_slippery(false))
	_die()

func _die() -> void:
	ObjectPool.release(self)

func on_pool_acquire() -> void:
	pass

func on_pool_release() -> void:
	pass

func _on_visible_on_screen_notifier_screen_exited() -> void:
	ObjectPool.release(self)
