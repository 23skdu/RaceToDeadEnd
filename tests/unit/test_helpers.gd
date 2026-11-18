extends GutTest

const Helpers = preload("res://scripts/utils/Helpers.gd")

func test_scale_sprite_to_viewport_no_crash():
	var sprite = Sprite2D.new()
	add_child_autofree(sprite)
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	sprite.texture = ImageTexture.create_from_image(img)
	sprite.add_to_group("test_sprite")
	Helpers.scale_sprite_to_viewport(sprite, 64.0, 1280.0)
	assert_true(sprite.scale.length() > 0, "Sprite scale should be set")

func test_scale_sprite_to_viewport_null_sprite():
	Helpers.scale_sprite_to_viewport(null, 64.0, 1280.0)
	assert_true(true, "Should not crash with null sprite")

func test_scale_sprite_to_viewport_no_texture():
	var sprite = Sprite2D.new()
	add_child_autofree(sprite)
	sprite.add_to_group("test_sprite2")
	Helpers.scale_sprite_to_viewport(sprite, 64.0, 1280.0)
	assert_true(true, "Should not crash with no texture")

# --- GUT post-run orphan guard coverage ---

const OrphanGuard = preload("res://tests/gut_orphan_guard.gd")

class OrphanGuardFakeOrphanage extends RefCounted:
	func clean() -> void:
		pass

class OrphanGuardFakeCounter extends RefCounted:
	var live: int = 0
	var recorded: int = 0
	var orphanage: OrphanGuardFakeOrphanage = OrphanGuardFakeOrphanage.new()

	func orphan_count() -> int:
		return live

	func get_orphan_ids(_group = null, _subgroup = null) -> Array:
		var ids := []
		for i in recorded:
			ids.append(i)
		return ids

class OrphanGuardFakeLogger extends RefCounted:
	var errors: Array[String] = []
	var logs: Array[String] = []

	func error(message: String) -> void:
		errors.append(message)

	func log(message: String) -> void:
		logs.append(message)

class OrphanGuardFakeGut extends RefCounted:
	var counter: OrphanGuardFakeCounter = OrphanGuardFakeCounter.new()
	var logger: OrphanGuardFakeLogger = OrphanGuardFakeLogger.new()

	func get_orphan_counter() -> OrphanGuardFakeCounter:
		return counter

func _make_orphan_guard_gut(live: int, recorded: int) -> OrphanGuardFakeGut:
	var gut := OrphanGuardFakeGut.new()
	gut.counter.live = live
	gut.counter.recorded = recorded
	return gut

func test_orphan_guard_counts_live_and_recorded_totals() -> void:
	var counts: Dictionary = OrphanGuard.orphan_counts(_make_orphan_guard_gut(2, 3))
	assert_eq(counts.get("live"), 2)
	assert_eq(counts.get("recorded"), 3)

func test_orphan_guard_fails_when_orphans_are_present() -> void:
	var guard = OrphanGuard.new()
	guard.gut = _make_orphan_guard_gut(1, 2)
	guard.run()
	assert_eq(guard.get_exit_code(), 1)
	assert_eq(guard.gut.logger.errors.size(), 1)
	assert_true(guard.gut.logger.errors[0].contains("Orphan guard failed"))

func test_orphan_guard_passes_when_no_orphans_are_present() -> void:
	var guard = OrphanGuard.new()
	guard.gut = _make_orphan_guard_gut(0, 0)
	guard.run()
	assert_null(guard.get_exit_code())
	assert_eq(guard.gut.logger.errors.size(), 0)
	assert_true(guard.gut.logger.logs[0].contains("0 live and 0 recorded orphans"))
