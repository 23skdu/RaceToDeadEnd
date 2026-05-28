extends GutTest

var Enemy

class SignalCapture:
	var pos = Vector2.ZERO
	var type = ""
	var count = 0
	func capture(p, t, _enemy = null):
		pos = p
		type = t
		count += 1

func before_all():
	Enemy = load("res://scripts/scenes/enemies/Enemy.gd")

func test_enemy_type_enum():
	assert_eq(Enemy.EnemyType.BUNNY, 0, "BUNNY = 0")
	assert_eq(Enemy.EnemyType.ROTOR, 1, "ROTOR = 1")
	assert_eq(Enemy.EnemyType.SCAV, 2, "SCAV = 2")
	assert_eq(Enemy.EnemyType.DRONE, 3, "DRONE = 3")
	assert_eq(Enemy.EnemyType.SASQUATCH, 4, "SASQUATCH = 4")

func test_type_names_constant():
	assert_eq(Enemy.TYPE_NAMES.size(), 5, "Should have 5 type names")
	assert_eq(Enemy.TYPE_NAMES[0], "bunny", "Type name 0 should be bunny")
	assert_eq(Enemy.TYPE_NAMES[1], "rotor", "Type name 1 should be rotor")
	assert_eq(Enemy.TYPE_NAMES[2], "scav", "Type name 2 should be scav")
	assert_eq(Enemy.TYPE_NAMES[3], "drone", "Type name 3 should be drone")
	assert_eq(Enemy.TYPE_NAMES[4], "sasquatch", "Type name 4 should be sasquatch")



func test_init_bunny():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.BUNNY, 3, player, 200.0)
	assert_eq(e.hp, 1, "Bunny HP")
	assert_almost_eq(e.speed, 200.0 * Constants.BUNNY_SPEED_MULTIPLIER, 0.001, "Bunny speed")
	assert_eq(e.score_value, 50, "Bunny score")
	assert_eq(e.lane, 3, "Lane should be set")
	assert_eq(e.player, player, "Player reference should be set")

func test_init_rotor():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	assert_eq(e.hp, 1, "Rotor HP")
	assert_almost_eq(e.speed, 200.0 * Constants.ROTOR_SPEED_MULTIPLIER, 0.001, "Rotor speed")
	assert_eq(e.score_value, 50, "Rotor score")
	assert_eq(e.player, player, "Player reference should be set")

func test_init_scav():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.SCAV, 1, player, 200.0)
	assert_eq(e.hp, 3, "Scav HP")
	assert_almost_eq(e.speed, 200.0 * Constants.SCAV_SPEED_MULTIPLIER, 0.001, "Scav speed")
	assert_eq(e.score_value, 100, "Scav score")
	assert_eq(e.player, player, "Player reference should be set")

func test_init_drone():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.DRONE, 2, player, 200.0)
	assert_eq(e.hp, 2, "Drone HP")
	assert_almost_eq(e.speed, 200.0 * Constants.DRONE_SPEED_MULTIPLIER, 0.001, "Drone speed")
	assert_eq(e.score_value, 200, "Drone score")
	assert_eq(e.player, player, "Player reference should be set")

func test_init_sasquatch():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.SASQUATCH, 5, player, 200.0)
	assert_eq(e.hp, Constants.BOSS_SASQUATCH_HP, "Sasquatch HP from constant")
	assert_almost_eq(e.speed, 200.0 * 0.6, 0.001, "Sasquatch speed")
	assert_eq(e.score_value, 300, "Sasquatch score")
	assert_eq(e.player, player, "Player reference should be set")

func test_init_uses_base_speed_not_player_speed():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	assert_almost_eq(e.speed, 180.0, 0.001, "Speed should be based on base_speed, not player.current_speed")

func test_take_damage_reduces_hp():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.SCAV, 0, player, 200.0)
	e.take_damage(1)
	assert_eq(e.hp, 2, "HP should decrease by 1")

func test_take_damage_kills_at_zero():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	watch_signals(e)
	e.take_damage(1)
	assert_signal_emitted(e, "destroyed", "Destroyed signal should emit")

func test_take_damage_does_not_kill_above_zero():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.SCAV, 0, player, 200.0)
	var capture = SignalCapture.new()
	e.destroyed.connect(capture.capture)
	e.take_damage(1)
	assert_eq(capture.count, 0, "Should not emit destroyed with remaining HP")

func test_die_emits_correct_enemy_type():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.DRONE, 0, player, 200.0)
	var capture = SignalCapture.new()
	e.destroyed.connect(capture.capture)
	e.take_damage(2)
	assert_eq(capture.type, "drone", "Should emit lowercase enemy type")
	assert_eq(capture.count, 1, "Signal should be emitted once")

func test_die_rotor_type():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	var capture = SignalCapture.new()
	e.destroyed.connect(capture.capture)
	e.take_damage(1)
	assert_eq(capture.type, "rotor", "Should emit 'rotor'")

func test_die_scav_type():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.SCAV, 0, player, 200.0)
	var capture = SignalCapture.new()
	e.destroyed.connect(capture.capture)
	e.take_damage(3)
	assert_eq(capture.type, "scav", "Should emit 'scav'")

func test_destroyed_signal_emits_position():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	e.global_position = Vector2(100, 200)
	var capture = SignalCapture.new()
	e.destroyed.connect(capture.capture)
	e.take_damage(1)
	assert_eq(capture.pos, Vector2(100, 200), "Should emit global position")

func test_take_damage_overkill():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	watch_signals(e)
	e.take_damage(100)
	assert_signal_emitted(e, "destroyed", "Should die from overkill damage")

func _create_enemy():
	var scene = load("res://scenes/enemies/Rotor.tscn")
	var e = scene.instantiate()
	add_child_autofree(e)
	return e

func _create_bunny():
	var scene = load("res://scenes/enemies/Bunny.tscn")
	var e = scene.instantiate()
	add_child_autofree(e)
	return e

func test_ready_sets_z_index():
	var e = _create_enemy()
	assert_eq(e.z_index, 1, "Enemy z_index should be 1")

func _stop_all_sfx():
	for p in AudioManager.sfx_players:
		p.stop()

func test_take_damage_plays_hit_sound():
	_stop_all_sfx()
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.SCAV, 0, player, 200.0)
	e.take_damage(1)
	var playing = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing += 1
	assert_gt(playing, 0, "Hit sound should play on damage")

func test_die_plays_death_sound():
	_stop_all_sfx()
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	e.take_damage(1)
	var playing = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing += 1
	assert_gt(playing, 0, "Death sound should play on kill")

func test_drone_hit_plays_sound():
	_stop_all_sfx()
	var scene = load("res://scenes/enemies/Drone.tscn")
	var e = scene.instantiate()
	add_child_autofree(e)
	var player = Node2D.new()
	e.init(Enemy.EnemyType.DRONE, 0, player, 200.0)
	e.take_damage(1)
	var playing = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing += 1
	assert_gt(playing, 0, "Drone hit sound should play")

class MockSpawnerWithDestroyedHandler:
	extends Node
	var destroyed_called = false
	func _on_enemy_destroyed(_pos, _type, _enemy):
		destroyed_called = true

func test_on_pool_release_disconnects_destroyed_signal():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	var mock_spawner = MockSpawnerWithDestroyedHandler.new()
	e._spawner = mock_spawner
	e.destroyed.connect(mock_spawner._on_enemy_destroyed)
	assert_true(e.destroyed.is_connected(mock_spawner._on_enemy_destroyed), "Signal should be connected before release")
	e.on_pool_release()
	assert_false(e.destroyed.is_connected(mock_spawner._on_enemy_destroyed), "Signal should be disconnected after release")

func test_death_animation_sets_scale_to_zero():
	var e = _create_enemy()
	e._ready()
	e.sprite.scale = Vector2.ONE
	e._death_animation()
	assert_almost_eq(e.sprite.scale.x, 0.0, 0.001, "Sprite scale x should be near zero after death animation")
	assert_almost_eq(e.sprite.scale.y, 0.0, 0.001, "Sprite scale y should be near zero after death animation")

func test_on_pool_release_resets_sprite_scale():
	var e = _create_enemy()
	e._ready()
	e.sprite.scale = Vector2.ZERO
	e.on_pool_release()
	assert_eq(e.sprite.scale, Vector2.ONE, "Sprite scale should be reset to one after pool release")

func test_on_pool_release_resets_stunned():
	var e = _create_enemy()
	e.stunned = true
	e.stun_timer = 5.0
	e.on_pool_release()
	assert_false(e.stunned, "Stunned should be false after pool release")
	assert_almost_eq(e.stun_timer, 0.0, 0.001, "Stun timer should be zero after pool release")

func test_on_pool_release_resets_velocity():
	var e = _create_enemy()
	e.velocity = Vector2(100, 200)
	e.on_pool_release()
	assert_eq(e.velocity, Vector2.ZERO, "Velocity should be zero after pool release")

func test_apply_stun_sets_stunned():
	var e = _create_enemy()
	e.apply_stun(2.0)
	assert_true(e.stunned, "Should be stunned after apply_stun")
	assert_almost_eq(e.stun_timer, 2.0, 0.001, "Stun timer should be set")

func test_apply_stun_sets_sprite_modulate():
	var e = _create_enemy()
	e.apply_stun(1.0)
	assert_almost_eq(e.sprite.modulate.r, 0.5, 0.01, "Modulate R should be 0.5 when stunned")
	assert_almost_eq(e.sprite.modulate.g, 0.5, 0.01, "Modulate G should be 0.5 when stunned")
	assert_almost_eq(e.sprite.modulate.b, 1.0, 0.01, "Modulate B should be 1.0 when stunned")

func test_stun_expires_after_timer():
	var e = _create_enemy()
	e.apply_stun(0.01)
	e._physics_process(1.0)
	assert_false(e.stunned, "Stun should expire after delta > stun_timer")

func test_hit_flash_timer_timeout_restores_white():
	var e = _create_enemy()
	e.sprite.modulate = Color.RED
	e.stunned = false
	e._on_hit_flash_timer_timeout()
	assert_eq(e.sprite.modulate, Color.WHITE, "Modulate should be white after hit-flash timeout")

func test_hit_flash_timer_timeout_does_not_override_stun():
	var e = _create_enemy()
	e.apply_stun(5.0)
	var stun_color = e.sprite.modulate
	e._on_hit_flash_timer_timeout()
	assert_eq(e.sprite.modulate, stun_color, "Modulate should not change when stunned")

func test_can_damage_player_default_true():
	var e = _create_enemy()
	assert_true(e.can_damage_player, "can_damage_player should default to true")

func test_boss_key_default_empty():
	var e = _create_enemy()
	assert_eq(e.boss_key, "", "boss_key should default to empty string")

func test_die_uses_boss_key_when_set():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0)
	e.boss_key = "boss_rotor"
	var capture = SignalCapture.new()
	e.destroyed.connect(capture.capture)
	e.take_damage(100)
	assert_eq(capture.type, "boss_rotor", "Should use boss_key when set")

func test_bunny_texture_is_not_null():
	var e = _create_bunny()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.BUNNY, 0, player, 200.0)
	assert_not_null(e.sprite.texture, "Bunny should have a texture after init")

func test_bunny_texture_is_64x64():
	var e = _create_bunny()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.BUNNY, 0, player, 200.0)
	var img = e.sprite.texture.get_image()
	assert_eq(img.get_width(), 64, "Bunny texture should be 64px wide")
	assert_eq(img.get_height(), 64, "Bunny texture should be 64px tall")

func test_bunny_texture_has_transparent_corners():
	var e = _create_bunny()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.BUNNY, 0, player, 200.0)
	var img = e.sprite.texture.get_image()
	assert_eq(img.get_pixel(0, 0).a, 0.0, "Bunny texture top-left corner should be transparent")
	assert_eq(img.get_pixel(63, 63).a, 0.0, "Bunny texture bottom-right corner should be transparent")

func test_bunny_texture_has_red_eyes():
	var e = _create_bunny()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.BUNNY, 0, player, 200.0)
	var img = e.sprite.texture.get_image()
	# Eye pixels at (25,30) should be glowing red
	var eye_px = img.get_pixel(25, 30)
	assert_gt(eye_px.r, 0.7, "Eye pixel should be predominantly red")

func test_bunny_texture_cached_across_instances():
	var e1 = _create_bunny()
	var player = Node2D.new()
	e1.init(Enemy.EnemyType.BUNNY, 0, player, 200.0)
	var tex1 = e1.sprite.texture
	var e2 = _create_bunny()
	e2.init(Enemy.EnemyType.BUNNY, 0, player, 200.0)
	var tex2 = e2.sprite.texture
	assert_true(tex1 == tex2, "Bunny texture should be the same cached instance")

func test_bunny_hit_plays_sound():
	_stop_all_sfx()
	var e = _create_bunny()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.BUNNY, 0, player, 200.0)
	e.take_damage(1)
	var playing = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing += 1
	assert_gt(playing, 0, "Bunny hit sound should play")

func test_bunny_death_plays_sound():
	_stop_all_sfx()
	var e = _create_bunny()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.BUNNY, 0, player, 200.0)
	e.take_damage(1)
	var playing = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing += 1
	assert_gt(playing, 0, "Bunny death sound should play")

func test_bunny_die_emits_correct_type():
	var e = _create_bunny()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.BUNNY, 0, player, 200.0)
	var capture = SignalCapture.new()
	e.destroyed.connect(capture.capture)
	e.take_damage(1)
	assert_eq(capture.type, "bunny", "Destroyed signal should emit 'bunny'")

func test_sasquatch_hit_plays_sound():
	_stop_all_sfx()
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.SASQUATCH, 0, player, 200.0)
	e.take_damage(1)
	var playing = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing += 1
	assert_gt(playing, 0, "Sasquatch hit sound should play")

func test_sasquatch_die_plays_sound():
	_stop_all_sfx()
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.SASQUATCH, 0, player, 200.0)
	e.take_damage(Constants.BOSS_SASQUATCH_HP)
	var playing = 0
	for p in AudioManager.sfx_players:
		if p.playing:
			playing += 1
	assert_gt(playing, 0, "Sasquatch death sound should play")

func test_sasquatch_die_emits_correct_type():
	var e = _create_enemy()
	var player = Node2D.new()
	e.init(Enemy.EnemyType.SASQUATCH, 0, player, 200.0)
	var capture = SignalCapture.new()
	e.destroyed.connect(capture.capture)
	e.take_damage(Constants.BOSS_SASQUATCH_HP)
	assert_eq(capture.type, "sasquatch", "Destroyed signal should emit 'sasquatch'")

func test_enemy_added_to_group():
	var e = _create_enemy()
	assert_true(e.is_in_group("enemy"), "Enemy should be in 'enemy' group after _ready")

func test_enemy_collision_layer():
	var e = _create_enemy()
	assert_eq(e.collision_layer, 2, "Enemy collision_layer should be 2")

func test_init_sets_spawner():
	var e = _create_enemy()
	var player = Node2D.new()
	var spawner = Node.new()
	e.init(Enemy.EnemyType.ROTOR, 0, player, 200.0, spawner)
	assert_eq(e._spawner, spawner, "Spawner should be set via init")
	spawner.free()
