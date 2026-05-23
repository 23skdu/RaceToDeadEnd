extends GutTest

func test_lane_positions():
	assert_eq(Constants.LANE_POSITIONS.size(), 6)
	assert_eq(Constants.LANE_POSITIONS[0], -120.0)
	assert_eq(Constants.LANE_POSITIONS[1], -72.0)
	assert_eq(Constants.LANE_POSITIONS[2], -24.0)
	assert_eq(Constants.LANE_POSITIONS[3], 24.0)
	assert_eq(Constants.LANE_POSITIONS[4], 72.0)
	assert_eq(Constants.LANE_POSITIONS[5], 120.0)

func test_lane_width():
	assert_eq(Constants.LANE_WIDTH, 48.0)

func test_lane_count():
	assert_eq(Constants.LANE_COUNT, 6)

func test_spawn_distance():
	assert_eq(Constants.SPAWN_DISTANCE, 450.0)

func test_cleanup_distance():
	assert_eq(Constants.CLEANUP_DISTANCE, 450.0)

func test_base_speed():
	assert_eq(Constants.BASE_SPEED, 200.0)

func test_tier_threshold():
	assert_eq(Constants.TIER_THRESHOLD, 1000)

func test_max_tier():
	assert_eq(Constants.MAX_TIER, 20)

func test_segment_difficulty_bonus():
	assert_eq(Constants.SEGMENT_DIFFICULTY_BONUS, 200.0)

func test_score_rate():
	assert_eq(Constants.SCORE_RATE, 10)

func test_speed_per_tier():
	assert_eq(Constants.SPEED_PER_TIER, 15.0)

func test_max_game_speed():
	assert_eq(Constants.MAX_GAME_SPEED, 600.0)

func test_base_wave_interval():
	assert_eq(Constants.BASE_WAVE_INTERVAL, 5.0)

func test_min_wave_interval():
	assert_eq(Constants.MIN_WAVE_INTERVAL, 2.0)

func test_wave_interval_decay():
	assert_eq(Constants.WAVE_INTERVAL_DECAY, 0.3)

func test_scav_shoot_interval():
	assert_eq(Constants.SCAV_SHOOT_INTERVAL, 2.5)

func test_drone_bomb_interval():
	assert_eq(Constants.DRONE_BOMB_INTERVAL, 3.0)

func test_rotor_speed_multiplier():
	assert_eq(Constants.ROTOR_SPEED_MULTIPLIER, 0.9)

func test_scav_speed_multiplier():
	assert_eq(Constants.SCAV_SPEED_MULTIPLIER, 0.7)

func test_drone_speed_multiplier():
	assert_eq(Constants.DRONE_SPEED_MULTIPLIER, 0.5)

func test_rain_drop_count():
	assert_eq(Constants.RAIN_DROP_COUNT, 200)

func test_lightning_damage():
	assert_eq(Constants.LIGHTNING_DAMAGE, 1)

func test_acid_rain_damage_interval():
	assert_eq(Constants.ACID_RAIN_DAMAGE_INTERVAL, 2.0)

func test_acid_rain_damage():
	assert_eq(Constants.ACID_RAIN_DAMAGE, 1)

func test_cloud_count():
	assert_eq(Constants.CLOUD_COUNT, 5)

func test_lightning_chance_per_second():
	assert_eq(Constants.LIGHTNING_CHANCE_PER_SECOND, 0.15)

func test_boost_speed_multiplier():
	assert_eq(Constants.BOOST_SPEED_MULTIPLIER, 2.0)

func test_weave_distance():
	assert_eq(Constants.WEAVE_DISTANCE, 128.0)

func test_weave_cooldown():
	assert_eq(Constants.WEAVE_COOLDOWN, 0.5)

func test_boost_duration():
	assert_eq(Constants.BOOST_DURATION, 1.5)

func test_boost_recharge_time():
	assert_eq(Constants.BOOST_RECHARGE_TIME, 8.0)

func test_primary_fire_cooldown():
	assert_eq(Constants.PRIMARY_FIRE_COOLDOWN, 0.1)

func test_double_tap_delay():
	assert_eq(Constants.DOUBLE_TAP_DELAY, 0.25)

func test_accel_speed():
	assert_eq(Constants.ACCEL_SPEED, 300.0)

func test_reverse_speed():
	assert_eq(Constants.REVERSE_SPEED, -350.0)

func test_multiplier_duration():
	assert_eq(Constants.MULTIPLIER_DURATION, 10.0)

func test_enemy_cache_interval():
	assert_eq(Constants.ENEMY_CACHE_INTERVAL, 0.25)

func test_bullet_speed():
	assert_eq(Constants.BULLET_SPEED, 500.0)

func test_mine_damage():
	assert_eq(Constants.MINE_DAMAGE, 2)

func test_mine_explosion_radius():
	assert_eq(Constants.MINE_EXPLOSION_RADIUS, 64.0)

func test_mine_arm_time():
	assert_eq(Constants.MINE_ARM_TIME, 0.5)

func test_emp_damage():
	assert_eq(Constants.EMP_DAMAGE, 1)

func test_emp_stun_duration():
	assert_eq(Constants.EMP_STUN_DURATION, 2.0)

func test_emp_expand_speed():
	assert_eq(Constants.EMP_EXPAND_SPEED, 400.0)

func test_emp_max_radius():
	assert_eq(Constants.EMP_MAX_RADIUS, 400.0)

func test_detonation_time():
	assert_eq(Constants.DETONATION_TIME, 1.5)

func test_blast_radius():
	assert_eq(Constants.BLAST_RADIUS, 80.0)

func test_world_scale():
	assert_eq(Constants.WORLD_SCALE, Vector2(1.0, 0.5))

func test_camera_y_offset():
	assert_eq(Constants.CAMERA_Y_OFFSET, -100.0)

func test_civilian_speed():
	assert_eq(Constants.CIVILIAN_SPEED, 150.0)

func test_civilian_spawn_chance():
	assert_eq(Constants.CIVILIAN_SPAWN_CHANCE, 0.15)

func test_civilian_bonus():
	assert_eq(Constants.CIVILIAN_BONUS, 500)

func test_civilian_penalty():
	assert_eq(Constants.CIVILIAN_PENALTY, 1)

func test_boss_score_interval():
	assert_eq(Constants.BOSS_SCORE_INTERVAL, 3000)

func test_boss_war_rig_hp():
	assert_eq(Constants.BOSS_WAR_RIG_HP, 20)

func test_boss_alien_carrier_hp():
	assert_eq(Constants.BOSS_ALIEN_CARRIER_HP, 15)

func test_boss_score():
	assert_eq(Constants.BOSS_SCORE, 1000)

func test_boss_attack_interval():
	assert_eq(Constants.BOSS_ATTACK_INTERVAL, 2.0)

func test_sprite_base_size():
	assert_eq(Constants.SPRITE_BASE_SIZE, 64.0)

func test_sprite_base_viewport():
	assert_eq(Constants.SPRITE_BASE_VIEWPORT, 1280.0)

func test_guardrail_width():
	assert_eq(Constants.GUARDRAIL_WIDTH, 3.0)

func test_scav_flank_offset():
	assert_eq(Constants.SCAV_FLANK_OFFSET, 64.0)

func test_multiplier_bar_width():
	assert_eq(Constants.MULTIPLIER_BAR_WIDTH, 120.0)

func test_multiplier_bar_height():
	assert_eq(Constants.MULTIPLIER_BAR_HEIGHT, 8.0)

func test_weapon_data_count():
	assert_eq(Constants.WEAPON_DATA.size(), 3)

func test_weapon_data_missile():
	assert_eq(Constants.WEAPON_DATA[0].type_name, "missile")
	assert_eq(Constants.WEAPON_DATA[0].display_name, "Homing Missile")
	assert_eq(Constants.WEAPON_DATA[0].color, Color.RED)
	assert_eq(Constants.WEAPON_DATA[0].base_ammo, 30)

func test_weapon_data_mine():
	assert_eq(Constants.WEAPON_DATA[1].type_name, "mine")
	assert_eq(Constants.WEAPON_DATA[1].display_name, "Proximity Mine")
	assert_eq(Constants.WEAPON_DATA[1].color, Color.YELLOW)
	assert_eq(Constants.WEAPON_DATA[1].base_ammo, 15)

func test_weapon_data_emp():
	assert_eq(Constants.WEAPON_DATA[2].type_name, "emp")
	assert_eq(Constants.WEAPON_DATA[2].display_name, "EMP Blast")
	assert_eq(Constants.WEAPON_DATA[2].color, Color.CYAN)
	assert_eq(Constants.WEAPON_DATA[2].base_ammo, 5)

func test_weather_colors_exist():
	assert_eq(Constants.RAIN_DROPLET_COLOR, Color(0.5, 0.6, 0.8, 0.5))
	assert_eq(Constants.RAIN_DROPLET_ZERO_ALPHA, Color(0.5, 0.6, 0.8, 0.0))
	assert_eq(Constants.RAIN_PARTICLE_CLEAR, Color(0.5, 0.6, 0.8, 0.3))
	assert_eq(Constants.RAIN_PARTICLE_ACID, Color(0.2, 0.9, 0.2, 0.5))
	assert_eq(Constants.RAIN_PARTICLE_STORM, Color(0.3, 0.8, 0.3, 0.6))
	assert_eq(Constants.LIGHTNING_BOLT_COLOR, Color(0.8, 0.9, 1.0, 1.0))
	assert_eq(Constants.LIGHTNING_FLASH_COLOR, Color(0.9, 0.95, 1.0, 0.8))
	assert_eq(Constants.CLOUD_BODY_COLOR, Color(0.15, 0.1, 0.2, 0.7))
	assert_eq(Constants.CLOUD_GLOW_COLOR, Color(0.0, 0.8, 0.2, 0.2))
	assert_eq(Constants.ACID_OVERLAY_CLEAR, Color(0, 0, 0, 0))
	assert_eq(Constants.ACID_OVERLAY_COLOR_LIGHT, Color(0.1, 0.3, 0.1, 0.15))
	assert_eq(Constants.ACID_OVERLAY_COLOR_HEAVY, Color(0.15, 0.2, 0.15, 0.25))

func test_acid_overlay_alpha():
	assert_eq(Constants.ACID_OVERLAY_ALPHA_LIGHT, 0.15)
	assert_eq(Constants.ACID_OVERLAY_ALPHA_HEAVY, 0.25)

func test_all_color_constants_are_color_type():
	assert_true(Constants.RAIN_DROPLET_COLOR is Color)
	assert_true(Constants.RAIN_DROPLET_ZERO_ALPHA is Color)
	assert_true(Constants.RAIN_PARTICLE_CLEAR is Color)
	assert_true(Constants.RAIN_PARTICLE_ACID is Color)
	assert_true(Constants.RAIN_PARTICLE_STORM is Color)
	assert_true(Constants.LIGHTNING_BOLT_COLOR is Color)
	assert_true(Constants.LIGHTNING_FLASH_COLOR is Color)
	assert_true(Constants.CLOUD_BODY_COLOR is Color)
	assert_true(Constants.CLOUD_GLOW_COLOR is Color)
	assert_true(Constants.ACID_OVERLAY_CLEAR is Color)
	assert_true(Constants.ACID_OVERLAY_COLOR_LIGHT is Color)
	assert_true(Constants.ACID_OVERLAY_COLOR_HEAVY is Color)

func test_fire_rate_constants():
	assert_eq(Constants.FIRE_RATE_STEP, 0.01, "Fire rate step should be 0.01")
	assert_eq(Constants.FIRE_RATE_MIN, 0.05, "Fire rate min should be 0.05")
	assert_eq(Constants.FIRE_RATE_MAX, 0.1, "Fire rate max should be 0.1")

func test_scav_constants():
	assert_eq(Constants.SCAV_RAM_DIST_Y, 120.0, "Scav ram Y distance")
	assert_eq(Constants.SCAV_RAM_DIST_X, 80.0, "Scav ram X distance")
	assert_eq(Constants.SCAV_LATERAL_RAM_SPEED, 300.0, "Scav lateral ram speed")
	assert_eq(Constants.SCAV_LATERAL_NORMAL_SPEED, 150.0, "Scav lateral normal speed")

func test_boss_constants():
	assert_eq(Constants.BOSS_RAM_FORCE, 200.0, "Boss ram force")
	assert_eq(Constants.BOSS_RAM_SPEED, 500.0, "Boss ram speed")

func test_highway_chunk_weight_constants():
	assert_eq(Constants.CHUNK_WEIGHT_STANDARD_BASE, 40.0, "Standard chunk base weight")
	assert_eq(Constants.CHUNK_WEIGHT_DEBRIS_BASE, 20.0, "Debris chunk base weight")
	assert_eq(Constants.CHUNK_WEIGHT_ICE_BASE, 10.0, "Ice chunk base weight")
	assert_eq(Constants.CHUNK_WEIGHT_CONSTRUCTION_BASE, 15.0, "Construction chunk base weight")
	assert_eq(Constants.CHUNK_WEIGHT_BRIDGE_BASE, 15.0, "Bridge chunk base weight")
	assert_eq(Constants.CHUNK_HAZARD_CAP, 10, "Hazard tier cap")
	assert_eq(Constants.CHUNK_HAZARD_STEP, 2, "Hazard step per tier")
	assert_eq(Constants.CHUNK_WEIGHT_STANDARD_MIN, 15.0, "Standard min weight")
	assert_eq(Constants.CHUNK_WEIGHT_DEBRIS_MAX, 35.0, "Debris max weight")
	assert_eq(Constants.CHUNK_WEIGHT_ICE_MAX, 25.0, "Ice max weight")
	assert_eq(Constants.CHUNK_WEIGHT_CONSTRUCTION_MAX, 30.0, "Construction max weight")
	assert_eq(Constants.CHUNK_WEIGHT_BRIDGE_MAX, 30.0, "Bridge max weight")
