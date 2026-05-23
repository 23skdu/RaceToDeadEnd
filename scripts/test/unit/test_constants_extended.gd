extends GutTest

func test_new_constants_exist():
	assert_gt(Constants.CIVILIAN_SPEED, 0, "Civilian speed constant should exist")
	assert_gt(Constants.CIVILIAN_BONUS, 0, "Civilian bonus constant should exist")
	assert_gt(Constants.BOSS_SCORE_INTERVAL, 1000, "Boss score interval should be >= 1000")
	assert_gt(Constants.BOSS_WAR_RIG_HP, 0, "Boss HP constant should exist")
	assert_gt(Constants.SPRITE_BASE_SIZE, 0, "Sprite base size constant should exist")
	assert_gt(Constants.GUARDRAIL_WIDTH, 0, "Guardrail width constant should exist")
	assert_gt(Constants.MULTIPLIER_BAR_WIDTH, 0, "Multiplier bar width constant should exist")
	assert_lt(Constants.CAMERA_Y_OFFSET, 0, "Camera Y offset should be negative (above player)")
	assert_eq(Constants.WORLD_SCALE, Vector2(1.0, 0.5), "World scale constant should match")

func test_world_scale_constant():
	assert_eq(Constants.WORLD_SCALE.x, 1.0, "World scale X should be 1.0")
	assert_eq(Constants.WORLD_SCALE.y, 0.5, "World scale Y should be 0.5")
