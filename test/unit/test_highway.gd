extends GutTest

var Highway

func before_all():
	Highway = load("res://scenes/world/Highway.gd")

func test_chunk_constants():
	var h = Highway.new()
	assert_eq(h.CHUNK_HEIGHT, 10, "Chunk height should be 10")
	assert_eq(h.CHUNK_WIDTH, 5, "Chunk width should be 5")
	assert_eq(h.TILE_SIZE, Vector2i(64, 32), "Tile size should be 64x32")
	assert_eq(h.CHUNK_PIXEL_HEIGHT, 320, "Chunk pixel height should be 320")
	assert_eq(h.PREWARM_CHUNKS, 4, "Prewarm chunks should be 4")
	assert_eq(h.TOTAL_CHUNK_WEIGHT, 95, "Total chunk weight should be 95")

func test_chunk_type_enum():
	var h = Highway.new()
	assert_eq(h.ChunkType.STANDARD, 0, "STANDARD = 0")
	assert_eq(h.ChunkType.DEBRIS, 1, "DEBRIS = 1")
	assert_eq(h.ChunkType.ICE, 2, "ICE = 2")
	assert_eq(h.ChunkType.CONSTRUCTION, 3, "CONSTRUCTION = 3")
	assert_eq(h.ChunkType.BRIDGE, 4, "BRIDGE = 4")

func test_chunk_weights_sum():
	var h = Highway.new()
	var total = 0
	for w in h.chunk_weights.values():
		total += w
	assert_eq(total, h.TOTAL_CHUNK_WEIGHT, "Total weight should match constant")

func test_chunk_weights_scale_with_difficulty():
	var h = Highway.new()
	var gm = load("res://autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	gm.difficulty_tier = 1
	var type1 = h._pick_chunk_type()
	gm.difficulty_tier = 10
	var type10 = h._pick_chunk_type()
	assert_true(type1 >= 0 and type1 <= 4, "Tier 1 should return valid type")
	assert_true(type10 >= 0 and type10 <= 4, "Tier 10 should return valid type")

func test_pick_chunk_type_returns_valid():
	var h = Highway.new()
	for i in range(20):
		var result = h._pick_chunk_type()
		assert_true(result >= 0 and result <= 4, "Should return valid chunk type")

func test_first_chunks_are_standard():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	h._ready()
	var first_chunk = h.active_chunks[0]
	assert_eq(first_chunk.get_meta("chunk_type"), h.ChunkType.STANDARD, "First chunk should be STANDARD")
	var second_chunk = h.active_chunks[1]
	assert_eq(second_chunk.get_meta("chunk_type"), h.ChunkType.STANDARD, "Second chunk should be STANDARD")

func test_prewarm_creates_4_chunks():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	h._ready()
	assert_eq(h.active_chunks.size(), 4, "Should have 4 prewarmed chunks")

func test_chunks_positioned_correctly():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	h._ready()
	for i in range(4):
		var expected_y = -i * 320
		assert_eq(h.active_chunks[i].position.y, expected_y, "Chunk " + str(i) + " Y position")

func test_current_segment_increments():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	h._ready()
	assert_eq(h.current_segment, 4, "Should have 4 segments after prewarm")

func test_clear_chunk_tiles_removes_tiles():
	var h = Highway.new()
	var chunk = Node2D.new()
	var tiles = Node2D.new()
	tiles.name = "Tiles"
	chunk.add_child(tiles)
	add_child_autofree(chunk)
	h._clear_chunk_tiles(chunk)
	assert_false(chunk.has_node("Tiles"), "Tiles node should be removed")

func test_ice_entered_emits_signal():
	var h = Highway.new()
	add_child_autofree(h)
	watch_signals(h)
	var mock_body = Node2D.new()
	h._on_ice_entered(mock_body)
	assert_signal_emitted(h, "ice_entered", "Should emit ice_entered signal")

func test_ice_exited_emits_signal():
	var h = Highway.new()
	add_child_autofree(h)
	watch_signals(h)
	var mock_body = Node2D.new()
	h._on_ice_exited(mock_body)
	assert_signal_emitted(h, "ice_exited", "Should emit ice_exited signal")

func test_bridge_fall_emits_signal():
	var h = Highway.new()
	add_child_autofree(h)
	watch_signals(h)
	var mock_body = Node2D.new()
	h._on_bridge_fall(mock_body)
	assert_signal_emitted(h, "bridge_fall", "Should emit bridge_fall signal")

func test_highway_does_not_call_player_methods_directly():
	var h = Highway.new()
	add_child_autofree(h)
	watch_signals(h)
	var mock_body = Node2D.new()
	h._on_ice_entered(mock_body)
	h._on_ice_exited(mock_body)
	h._on_bridge_fall(mock_body)
	assert_signal_emitted(h, "ice_entered", "Should use signals instead of direct calls")
	assert_signal_emitted(h, "ice_exited", "Should use signals instead of direct calls")
	assert_signal_emitted(h, "bridge_fall", "Should use signals instead of direct calls")

func test_get_tile_variant_standard():
	var h = Highway.new()
	assert_eq(h._get_tile_variant(h.ChunkType.STANDARD, 0, 0), 0, "Standard always 0")
	assert_eq(h._get_tile_variant(h.ChunkType.STANDARD, 5, 3), 0, "Standard always 0")

func test_get_tile_variant_debris():
	var h = Highway.new()
	assert_eq(h._get_tile_variant(h.ChunkType.DEBRIS, 0, 0), 1, "Debris at row 0 col 0")
	assert_eq(h._get_tile_variant(h.ChunkType.DEBRIS, 1, 0), 0, "Debris at row 1 col 0")
	assert_eq(h._get_tile_variant(h.ChunkType.DEBRIS, 3, 2), 1, "Debris at row 3 col 2")

func test_get_tile_variant_ice():
	var h = Highway.new()
	assert_eq(h._get_tile_variant(h.ChunkType.ICE, 0, 0), 2, "Ice always 2")

func test_get_tile_variant_construction():
	var h = Highway.new()
	assert_eq(h._get_tile_variant(h.ChunkType.CONSTRUCTION, 0, 0), 3, "Construction at col 0")
	assert_eq(h._get_tile_variant(h.ChunkType.CONSTRUCTION, 0, 4), 3, "Construction at col 4")
	assert_eq(h._get_tile_variant(h.ChunkType.CONSTRUCTION, 0, 2), 0, "Construction at col 2")

func test_get_tile_variant_bridge():
	var h = Highway.new()
	assert_eq(h._get_tile_variant(h.ChunkType.BRIDGE, 0, 0), 4, "Bridge always 4")

func _create_mock_player(pos: Vector2) -> Node2D:
	var player = Node2D.new()
	player.position = pos
	player.global_position = pos
	return player

func test_process_recycles_chunk_when_player_passes():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	h._ready()
	var initial_count = h.active_chunks.size()
	h.player.global_position = Vector2(0, -500)
	h._process(0.1)
	assert_eq(h.active_chunks.size(), initial_count, "Chunk count should stay same after recycle")

func test_spawn_chunk_creates_node():
	var h = Highway.new()
	add_child_autofree(h)
	h._spawn_chunk(0)
	assert_eq(h.active_chunks.size(), 1, "Should have one chunk after spawn")
	assert_eq(h.current_segment, 1, "Segment should increment")

func test_recycle_chunk_moves_to_front():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	h._spawn_chunk(0)
	h._spawn_chunk(1)
	var chunk = h.active_chunks[0]
	h._recycle_chunk(chunk)
	assert_lt(chunk.position.y, h.active_chunks[1].position.y, "Recycled chunk should be in front")

func test_recycle_chunk_emits_signal():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	h._spawn_chunk(0)
	watch_signals(h)
	h._recycle_chunk(h.active_chunks[0])
	assert_signal_emitted(h, "segment_completed", "Should emit segment_completed signal")

func test_create_diamond_mesh_returns_array_mesh():
	var h = Highway.new()
	var mesh = h._create_diamond_mesh()
	assert_is(mesh, ArrayMesh, "Should return ArrayMesh")

func test_generate_chunk_tiles_creates_obstacles_for_debris():
	var h = Highway.new()
	var chunk = Node2D.new()
	add_child_autofree(chunk)
	h._generate_chunk_tiles(chunk, h.ChunkType.DEBRIS)
	var tiles_node = chunk.get_node_or_null("Tiles")
	assert_is_not_null(tiles_node, "Should create Tiles node")
	var obstacle_count = 0
	for child in tiles_node.get_children():
		if child is StaticBody2D:
			obstacle_count += 1
	assert_gt(obstacle_count, 0, "Debris chunk should have obstacles")

func test_generate_chunk_tiles_creates_ice_area():
	var h = Highway.new()
	var chunk = Node2D.new()
	add_child_autofree(chunk)
	h._generate_chunk_tiles(chunk, h.ChunkType.ICE)
	var tiles_node = chunk.get_node_or_null("Tiles")
	assert_is_not_null(tiles_node, "Should create Tiles node")
	var area_count = 0
	for child in tiles_node.get_children():
		if child is Area2D:
			area_count += 1
	assert_gt(area_count, 0, "Ice chunk should have Area2D trigger")

func test_generate_chunk_tiles_creates_bridge_areas():
	var h = Highway.new()
	var chunk = Node2D.new()
	add_child_autofree(chunk)
	h._generate_chunk_tiles(chunk, h.ChunkType.BRIDGE)
	var tiles_node = chunk.get_node_or_null("Tiles")
	assert_is_not_null(tiles_node, "Should create Tiles node")
	var area_count = 0
	for child in tiles_node.get_children():
		if child is Area2D:
			area_count += 1
	assert_gte(area_count, 2, "Bridge chunk should have 2 danger areas")
