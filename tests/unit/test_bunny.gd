extends GutTest

func test_bunny_extends_enemy():
	var bunny = load("res://scenes/enemies/Bunny.tscn").instantiate()
	add_child_autofree(bunny)
	assert_true(bunny is CharacterBody2D, "Bunny should be a CharacterBody2D")

func test_bunny_has_bounce_timer():
	var bunny = load("res://scenes/enemies/Bunny.tscn").instantiate()
	add_child_autofree(bunny)
	assert_eq(bunny.bounce_timer, 0.0, "Bounce timer starts at 0")

func test_bunny_constants():
	var bunny = load("res://scenes/enemies/Bunny.tscn").instantiate()
	add_child_autofree(bunny)
	assert_eq(bunny.BOUNCE_FREQUENCY, 3.5, "Bounce frequency")
	assert_eq(bunny.BOUNCE_HEIGHT, 14.0, "Bounce height")

func test_bunny_physics_process_moves_toward_player_x():
	var bunny = load("res://scenes/enemies/Bunny.tscn").instantiate()
	add_child_autofree(bunny)
	var player = Node2D.new()
	player.global_position = Vector2(100, -200)
	bunny.position = Vector2(0, 0)
	bunny.init(bunny.EnemyType.BUNNY, 1, player, 200.0)
	bunny._physics_process(0.1)
	assert_gt(bunny.velocity.x, 0.0, "Bunny should move toward player X")

func test_bunny_physics_process_moves_toward_player_y():
	var bunny = load("res://scenes/enemies/Bunny.tscn").instantiate()
	add_child_autofree(bunny)
	var player = Node2D.new()
	player.global_position = Vector2(0, -300)
	bunny.position = Vector2(0, 0)
	bunny.init(bunny.EnemyType.BUNNY, 1, player, 200.0)
	bunny._physics_process(0.1)
	assert_lt(bunny.velocity.y, 0.0, "Bunny should move upward toward player")

func test_bunny_stunned_sets_zero_velocity():
	var bunny = load("res://scenes/enemies/Bunny.tscn").instantiate()
	add_child_autofree(bunny)
	var player = Node2D.new()
	bunny.init(bunny.EnemyType.BUNNY, 0, player, 200.0)
	bunny.apply_stun(1.0)
	bunny._physics_process(0.1)
	assert_eq(bunny.velocity, Vector2.ZERO, "Stunned bunny should have zero velocity")

func test_bunny_increments_bounce_timer():
	var bunny = load("res://scenes/enemies/Bunny.tscn").instantiate()
	add_child_autofree(bunny)
	var player = Node2D.new()
	bunny.init(bunny.EnemyType.BUNNY, 0, player, 200.0)
	bunny._physics_process(0.5)
	assert_gt(bunny.bounce_timer, 0.0, "Bounce timer should increment")

func test_bunny_sprite_bounce_moves():
	var bunny = load("res://scenes/enemies/Bunny.tscn").instantiate()
	add_child_autofree(bunny)
	var player = Node2D.new()
	bunny.init(bunny.EnemyType.BUNNY, 0, player, 200.0)
	var initial_y = bunny.sprite.position.y
	bunny._physics_process(0.1)
	assert_ne(bunny.sprite.position.y, initial_y, "Sprite Y should change due to bounce")

func test_bunny_sets_velocity_y_when_no_player():
	var bunny = load("res://scenes/enemies/Bunny.tscn").instantiate()
	add_child_autofree(bunny)
	bunny.init(bunny.EnemyType.BUNNY, 0, null, 200.0)
	bunny._physics_process(0.1)
	assert_eq(bunny.velocity.y, -bunny.speed * 0.3, "Bunny should move down at reduced speed without player")

func test_bunny_release_resets_bounce_timer():
	var bunny = load("res://scenes/enemies/Bunny.tscn").instantiate()
	add_child_autofree(bunny)
	var player = Node2D.new()
	bunny.init(bunny.EnemyType.BUNNY, 0, player, 200.0)
	bunny._physics_process(1.0)
	assert_gt(bunny.bounce_timer, 0.0, "Bounce timer should be positive after processing")
	bunny.on_pool_release()
	assert_eq(bunny.bounce_timer, 0.0, "Bounce timer should reset on pool release")

func test_bunny_release_resets_sprite_position():
	var bunny = load("res://scenes/enemies/Bunny.tscn").instantiate()
	add_child_autofree(bunny)
	var player = Node2D.new()
	bunny.init(bunny.EnemyType.BUNNY, 0, player, 200.0)
	bunny._physics_process(0.5)
	bunny.on_pool_release()
	assert_eq(bunny.sprite.position, Vector2.ZERO, "Sprite position should reset on pool release")
