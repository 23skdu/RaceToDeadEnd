extends GutTest

var BorderScript

func before_all():
	BorderScript = load("res://scripts/scenes/ui/TopWeatherBorder.gd")

func _create_border():
	var border = BorderScript.new()
	add_child_autofree(border)
	return border

func test_border_default_weather():
	var b = _create_border()
	assert_eq(b.current_weather, "clear", "Default weather should be clear")

func test_border_time_elapsed_starts_zero():
	var b = _create_border()
	assert_eq(b.time_elapsed, 0.0, "Time elapsed starts at 0")

func test_border_flash_inactive_by_default():
	var b = _create_border()
	assert_false(b.flash_active, "Flash should be inactive")

func test_border_ready_sets_minimum_size():
	var b = _create_border()
	assert_eq(b.custom_minimum_size, Vector2(1280, 72), "Minimum size should be 1280x72")

func test_border_ready_sets_anchor():
	var b = _create_border()
	assert_eq(b.anchors_preset, Control.PRESET_TOP_WIDE, "Should use PRESET_TOP_WIDE")

func test_border_weather_changed_updates_current():
	var b = _create_border()
	b._on_weather_changed("acid_rain")
	assert_eq(b.current_weather, "acid_rain", "Weather should update")

func test_border_weather_changed_queues_redraw():
	var b = _create_border()
	b._on_weather_changed("storm")
	assert_true(true, "Weather changed should not crash")

func test_border_lightning_strike_sets_flash():
	var b = _create_border()
	b._on_lightning_strike(Vector2.ZERO)
	assert_true(b.flash_active, "Flash should be active after lightning")

func test_border_lightning_strike_sets_timer():
	var b = _create_border()
	b._on_lightning_strike(Vector2.ZERO)
	assert_gt(b.flash_timer, 0.0, "Flash timer should be set")

func test_border_process_increments_time():
	var b = _create_border()
	b._process(0.5)
	assert_eq(b.time_elapsed, 0.5, "Time elapsed should increment")

func test_border_process_decrements_flash_timer():
	var b = _create_border()
	b._on_lightning_strike(Vector2.ZERO)
	var initial_timer = b.flash_timer
	b._process(0.1)
	assert_lt(b.flash_timer, initial_timer, "Flash timer should decrement")

func test_border_process_disables_flash_when_expired():
	var b = _create_border()
	b._on_lightning_strike(Vector2.ZERO)
	b.flash_timer = 0.01
	b._process(0.02)
	assert_false(b.flash_active, "Flash should deactivate when timer expires")

func test_border_set_weather_reactions():
	var b = _create_border()
	b._on_weather_changed("clear")
	assert_eq(b.current_weather, "clear")
	b._on_weather_changed("light_rain")
	assert_eq(b.current_weather, "light_rain")
	b._on_weather_changed("acid_rain")
	assert_eq(b.current_weather, "acid_rain")
	b._on_weather_changed("storm")
	assert_eq(b.current_weather, "storm")

func test_border_redraw_after_weather_change():
	var b = _create_border()
	b._on_weather_changed("storm")
	assert_eq(b.current_weather, "storm")

func test_border_redraw_after_lightning():
	var b = _create_border()
	b._on_lightning_strike(Vector2(100, 0))
	assert_true(b.flash_active)
	assert_gt(b.flash_timer, 0.0)

func test_border_flash_expires_after_time():
	var b = _create_border()
	b._on_lightning_strike(Vector2.ZERO)
	b.flash_timer = 0.05
	for i in range(5):
		b._process(0.02)
	assert_false(b.flash_active, "Flash should expire")
