extends GutTest

func test_constants_lane_positions():
	assert_eq(Constants.LANE_POSITIONS.size(), 4, "Should have 4 lane positions")
	assert_eq(Constants.LANE_POSITIONS[0], -96.0, "Lane 0 position")
	assert_eq(Constants.LANE_POSITIONS[1], -32.0, "Lane 1 position")
	assert_eq(Constants.LANE_POSITIONS[2], 32.0, "Lane 2 position")
	assert_eq(Constants.LANE_POSITIONS[3], 96.0, "Lane 3 position")

func test_constants_lane_width():
	assert_eq(Constants.LANE_WIDTH, 64.0, "Lane width should be 64")

func test_constants_lane_count():
	assert_eq(Constants.LANE_COUNT, 4, "Lane count should be 4")

func test_constants_spawn_distance():
	assert_eq(Constants.SPAWN_DISTANCE, 450.0, "Spawn distance should be 450")

func test_constants_cleanup_distance():
	assert_eq(Constants.CLEANUP_DISTANCE, 450.0, "Cleanup distance should be 450")

func test_constants_base_speed():
	assert_eq(Constants.BASE_SPEED, 200.0, "Base speed should be 200")
