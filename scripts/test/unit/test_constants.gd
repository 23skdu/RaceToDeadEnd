extends GutTest

func test_constants_lane_positions():
	assert_eq(Constants.LANE_POSITIONS.size(), 6, "Should have 6 lane positions")
	assert_eq(Constants.LANE_POSITIONS[0], -120.0, "Lane 0 position")
	assert_eq(Constants.LANE_POSITIONS[1], -72.0, "Lane 1 position")
	assert_eq(Constants.LANE_POSITIONS[2], -24.0, "Lane 2 position")
	assert_eq(Constants.LANE_POSITIONS[3], 24.0, "Lane 3 position")
	assert_eq(Constants.LANE_POSITIONS[4], 72.0, "Lane 4 position")
	assert_eq(Constants.LANE_POSITIONS[5], 120.0, "Lane 5 position")

func test_constants_lane_width():
	assert_eq(Constants.LANE_WIDTH, 48.0, "Lane width should be 48")

func test_constants_lane_count():
	assert_eq(Constants.LANE_COUNT, 6, "Lane count should be 6")

func test_constants_spawn_distance():
	assert_eq(Constants.SPAWN_DISTANCE, 450.0, "Spawn distance should be 450")

func test_constants_cleanup_distance():
	assert_eq(Constants.CLEANUP_DISTANCE, 450.0, "Cleanup distance should be 450")

func test_constants_base_speed():
	assert_eq(Constants.BASE_SPEED, 200.0, "Base speed should be 200")
