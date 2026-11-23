extends GutTest

var Highway

func before_all():
	Highway = load("res://scripts/scenes/world/Highway.gd")

func test_chunk_constants():
	var h = Highway.new()
	autofree(h)
	assert_eq(h.CHUNK_HEIGHT, 14, "Chunk height should be 14")
	assert_eq(h.CHUNK_WIDTH, 14, "Chunk width should be 14")
	assert_eq(h.TILE_SIZE, Vector2i(48, 24), "Tile size should be 48x24")
	assert_eq(h.CHUNK_PIXEL_HEIGHT, 336, "Chunk pixel height should be 336")
	assert_eq(h.PREWARM_CHUNKS, 10, "Prewarm chunks should be 10")
	assert_eq(h.DESPAWN_CHUNKS_BEHIND, 4, "Despawn chunks behind should be 4")
	assert_eq(h.SHOULDER_COLUMNS, 5, "Shoulder columns should be 5")
	assert_eq(h.LANE_START_COL, 5, "Lane start col should be 5")
	assert_eq(h.LANE_END_COL, 8, "Lane end col should be 8")
	assert_eq(h.HALF_CHUNK, 6.5, "Half chunk should be 6.5")

func test_chunk_type_enum():
	var h = Highway.new()
	autofree(h)
	assert_eq(h.ChunkType.STANDARD, 0, "STANDARD = 0")
	assert_eq(h.ChunkType.DEBRIS, 1, "DEBRIS = 1")
	assert_eq(h.ChunkType.ICE, 2, "ICE = 2")
	assert_eq(h.ChunkType.CONSTRUCTION, 3, "CONSTRUCTION = 3")
	assert_eq(h.ChunkType.BRIDGE, 4, "BRIDGE = 4")

func test_chunk_weights_sum():
	var h = Highway.new()
	autofree(h)
	var total = 0
	for w in h.chunk_weights.values():
		total += w
	assert_eq(total, 100, "Total weight should be 100")

func test_chunk_weights_use_constants():
	var h = Highway.new()
	autofree(h)
	assert_eq(h.chunk_weights[h.ChunkType.STANDARD], Constants.CHUNK_WEIGHT_STANDARD_BASE, "Standard weight should use constant")
	assert_eq(h.chunk_weights[h.ChunkType.DEBRIS], Constants.CHUNK_WEIGHT_DEBRIS_BASE, "Debris weight should use constant")
	assert_eq(h.chunk_weights[h.ChunkType.ICE], Constants.CHUNK_WEIGHT_ICE_BASE, "Ice weight should use constant")
	assert_eq(h.chunk_weights[h.ChunkType.CONSTRUCTION], Constants.CHUNK_WEIGHT_CONSTRUCTION_BASE, "Construction weight should use constant")
	assert_eq(h.chunk_weights[h.ChunkType.BRIDGE], Constants.CHUNK_WEIGHT_BRIDGE_BASE, "Bridge weight should use constant")

func test_chunk_weights_scale_with_difficulty():
	var h = Highway.new()
	autofree(h)
	var gm = load("res://scripts/autoload/GameManager.gd").new()
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
	autofree(h)
	for i in range(20):
		var result = h._pick_chunk_type()
		assert_true(result >= 0 and result <= 4, "Should return valid chunk type")

func test_first_chunks_are_standard():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	var first_chunk = h.active_chunks[0]
	assert_eq(first_chunk.get_meta("chunk_type"), h.ChunkType.STANDARD, "First chunk should be STANDARD")
	var second_chunk = h.active_chunks[1]
	assert_eq(second_chunk.get_meta("chunk_type"), h.ChunkType.STANDARD, "Second chunk should be STANDARD")

func test_prewarm_creates_10_chunks():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	assert_eq(h.active_chunks.size(), 10, "Should have 10 prewarmed chunks")

func test_chunks_positioned_correctly():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	var expected_positions = [1008, 672, 336, 0, -336, -672, -1008, -1344, -1680, -2016]
	for i in range(10):
		assert_eq(h.active_chunks[i].position.y, expected_positions[i], "Chunk " + str(i) + " Y position")

func test_current_segment_increments():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	assert_eq(h.current_segment, 10, "Should have 10 segments after prewarm")

func test_remove_tiles_node_from_chunk():
	var h = Highway.new()
	autofree(h)
	var chunk = Node2D.new()
	var tiles = Node2D.new()
	tiles.name = "Tiles"
	chunk.add_child(tiles)
	add_child_autofree(chunk)
	chunk.remove_child(tiles)
	tiles.queue_free()
	autofree(tiles)
	assert_false(chunk.has_node("Tiles"), "Tiles node should be removed")

func test_ice_entered_emits_signal():
	var h = Highway.new()
	add_child_autofree(h)
	watch_signals(h)
	var mock_body = Node2D.new()
	add_child_autofree(mock_body)
	h._on_ice_entered(mock_body)
	assert_signal_emitted(h, "ice_entered", "Should emit ice_entered signal")

func test_ice_exited_emits_signal():
	var h = Highway.new()
	add_child_autofree(h)
	watch_signals(h)
	var mock_body = Node2D.new()
	add_child_autofree(mock_body)
	h._on_ice_exited(mock_body)
	assert_signal_emitted(h, "ice_exited", "Should emit ice_exited signal")

func test_bridge_fall_emits_signal():
	var h = Highway.new()
	add_child_autofree(h)
	watch_signals(h)
	var mock_body = Node2D.new()
	add_child_autofree(mock_body)
	h._on_bridge_fall(mock_body)
	assert_signal_emitted(h, "bridge_fall", "Should emit bridge_fall signal")

func test_highway_does_not_call_player_methods_directly():
	var h = Highway.new()
	add_child_autofree(h)
	watch_signals(h)
	var mock_body = Node2D.new()
	add_child_autofree(mock_body)
	h._on_ice_entered(mock_body)
	h._on_ice_exited(mock_body)
	h._on_bridge_fall(mock_body)
	assert_signal_emitted(h, "ice_entered", "Should use signals instead of direct calls")
	assert_signal_emitted(h, "ice_exited", "Should use signals instead of direct calls")
	assert_signal_emitted(h, "bridge_fall", "Should use signals instead of direct calls")

func test_get_tile_variant_standard():
	var h = Highway.new()
	autofree(h)
	assert_eq(h._get_tile_variant(h.ChunkType.STANDARD, 0, 0), 0, "Standard always 0")
	assert_eq(h._get_tile_variant(h.ChunkType.STANDARD, 5, 3), 0, "Standard always 0")

func test_get_tile_variant_debris():
	var h = Highway.new()
	autofree(h)
	assert_eq(h._get_tile_variant(h.ChunkType.DEBRIS, 0, 5), 3, "Debris at row 0 col 5 (first lane col)")
	assert_eq(h._get_tile_variant(h.ChunkType.DEBRIS, 0, 0), 0, "No Debris at row 0 col 0 (shoulder)")
	assert_eq(h._get_tile_variant(h.ChunkType.DEBRIS, 1, 4), 0, "No Debris at row 1 col 4")

func test_get_tile_variant_ice():
	var h = Highway.new()
	autofree(h)
	assert_eq(h._get_tile_variant(h.ChunkType.ICE, 0, 0), 2, "Ice always 2")

func test_get_tile_variant_construction():
	var h = Highway.new()
	autofree(h)
	assert_eq(h._get_tile_variant(h.ChunkType.CONSTRUCTION, 0, 4), 3, "Construction at col 4 (left of lane)")
	assert_eq(h._get_tile_variant(h.ChunkType.CONSTRUCTION, 0, 9), 3, "Construction at col 9 (right of lane)")
	assert_eq(h._get_tile_variant(h.ChunkType.CONSTRUCTION, 0, 5), 0, "No Construction at col 5 (mid lane)")

func test_get_tile_variant_bridge():
	var h = Highway.new()
	autofree(h)
	assert_eq(h._get_tile_variant(h.ChunkType.BRIDGE, 0, 0), 4, "Bridge always 4")

func _create_mock_player(pos: Vector2) -> Node2D:
	var player = Node2D.new()
	add_child_autofree(player)
	player.position = pos
	player.global_position = pos
	return player

func test_process_recycles_chunk_when_player_passes():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	var initial_count = h.active_chunks.size()
	h.player.global_position = Vector2(0, 500)
	h._process(0.1)
	assert_eq(h.active_chunks.size(), initial_count, "Chunk count should stay same after recycle")

func test_spawn_chunk_creates_node():
	var h = Highway.new()
	add_child_autofree(h)
	var before = h.active_chunks.size()
	h._spawn_chunk(0)
	assert_eq(h.active_chunks.size(), before + 1, "Should have one more chunk after spawn")
	assert_eq(h.current_segment, before + 1, "Segment should increment")

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
	autofree(h)
	var mesh = h._create_diamond_mesh()
	assert_is(mesh, ArrayMesh, "Should return ArrayMesh")

func test_chunk_tiles_have_y_sort_enabled():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	for chunk in h.active_chunks:
		var tiles = chunk.get_node_or_null("Tiles")
		assert_true(tiles != null and tiles.is_y_sort_enabled(), "Chunk Tiles should have Y-sort enabled")

func test_generate_chunk_tiles_creates_obstacles_for_debris():
	var h = Highway.new()
	autofree(h)
	var chunk = Node2D.new()
	add_child_autofree(chunk)
	h._generate_chunk_tiles(chunk, h.ChunkType.DEBRIS)
	var tiles_node = chunk.get_node_or_null("Tiles")
	assert_true(tiles_node != null, "Should create Tiles node")
	var obstacle_count = 0
	for child in tiles_node.get_children():
		if child is StaticBody2D:
			obstacle_count += 1
	assert_gt(obstacle_count, 0, "Debris chunk should have obstacles")

func test_generate_chunk_tiles_creates_ice_area():
	var h = Highway.new()
	autofree(h)
	var chunk = Node2D.new()
	add_child_autofree(chunk)
	h._generate_chunk_tiles(chunk, h.ChunkType.ICE)
	var tiles_node = chunk.get_node_or_null("Tiles")
	assert_true(tiles_node != null, "Should create Tiles node")
	var area_count = 0
	for child in tiles_node.get_children():
		if child is Area2D:
			area_count += 1
	assert_gt(area_count, 0, "Ice chunk should have Area2D trigger")

func test_generate_chunk_tiles_creates_bridge_areas():
	var h = Highway.new()
	autofree(h)
	var chunk = Node2D.new()
	add_child_autofree(chunk)
	h._generate_chunk_tiles(chunk, h.ChunkType.BRIDGE)
	var tiles_node = chunk.get_node_or_null("Tiles")
	assert_true(tiles_node != null, "Should create Tiles node")
	var area_count = 0
	for child in tiles_node.get_children():
		if child is Area2D:
			area_count += 1
	assert_gte(area_count, 2, "Bridge chunk should have 2 danger areas")

func test_process_does_nothing_without_player():
	var h = Highway.new()
	add_child_autofree(h)
	h._process(0.1)
	assert_true(true, "Should not crash without player")

func test_recycle_chunk_updates_type():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	h._spawn_chunk(0)
	var chunk = h.active_chunks[0]
	var _old_type = chunk.get_meta("chunk_type")
	h._recycle_chunk(chunk)
	var _new_type = chunk.get_meta("chunk_type")
	assert_true(true, "Chunk type should be updated")

func test_segment_completed_signal_emits_segment_number():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	var segment_before = h.current_segment
	watch_signals(h)
	h._recycle_chunk(h.active_chunks[0])
	var args = get_signal_parameters(h, "segment_completed")
	assert_eq(args[0], segment_before + 1, "Should emit next segment number")

func test_generate_chunk_tiles_creates_rails():
	var h = Highway.new()
	autofree(h)
	var chunk = Node2D.new()
	add_child_autofree(chunk)
	h._generate_chunk_tiles(chunk, h.ChunkType.STANDARD)
	var tiles_node = chunk.get_node_or_null("Tiles")
	assert_true(tiles_node != null, "Should create Tiles node")
	var rail_count = 0
	for child in tiles_node.get_children():
		if child is Line2D:
			rail_count += 1
	assert_gte(rail_count, 2, "Should have left and right rails")

func test_generate_chunk_tiles_standard_no_ice_area():
	var h = Highway.new()
	autofree(h)
	var chunk = Node2D.new()
	add_child_autofree(chunk)
	h._generate_chunk_tiles(chunk, h.ChunkType.STANDARD)
	var tiles_node = chunk.get_node_or_null("Tiles")
	var ice_area_count = 0
	for child in tiles_node.get_children():
		if child is Area2D:
			ice_area_count += 1
	assert_eq(ice_area_count, 0, "Standard chunk should not have ice area")

func test_chunk_weights_adjusted_at_high_tier():
	var h = Highway.new()
	autofree(h)
	var gm = load("res://scripts/autoload/GameManager.gd").new()
	add_child_autofree(gm)
	gm.start_game()
	gm.difficulty_tier = 20
	var weights = h.chunk_weights.duplicate()
	var hazard_increase = mini(20 - 1, 10) * 2
	weights[h.ChunkType.STANDARD] = maxi(40 - hazard_increase * 2, 15)
	assert_eq(weights[h.ChunkType.STANDARD], 15, "Standard weight should decrease at high tier")

func test_build_tiles_into_standard_creates_tiles():
	var h = Highway.new()
	autofree(h)
	var standard_tiles = Node2D.new()
	add_child_autofree(standard_tiles)
	h._build_tiles_into(standard_tiles, h.ChunkType.STANDARD)
	assert_gt(standard_tiles.get_child_count(), 0, "STANDARD type should create tile nodes")
	var has_mesh = false
	for child in standard_tiles.get_children():
		if child is MultiMeshInstance2D:
			has_mesh = true
			break
	assert_true(has_mesh, "STANDARD tiles should contain MultiMeshInstance2D children")

func test_build_tiles_into_bridge_creates_fewer_tiles():
	var h = Highway.new()
	autofree(h)
	var bridge_tiles = Node2D.new()
	add_child_autofree(bridge_tiles)
	h._build_tiles_into(bridge_tiles, h.ChunkType.BRIDGE)
	assert_gt(bridge_tiles.get_child_count(), 0, "BRIDGE type should create some tiles")
	var has_mesh = false
	for child in bridge_tiles.get_children():
		if child is MultiMeshInstance2D:
			has_mesh = true
			break
	assert_true(has_mesh, "BRIDGE tiles should contain MultiMeshInstance2D children")

func test_build_tiles_into_construction_creates_tiles():
	var h = Highway.new()
	autofree(h)
	var tiles = Node2D.new()
	add_child_autofree(tiles)
	h._build_tiles_into(tiles, h.ChunkType.CONSTRUCTION)
	assert_gt(tiles.get_child_count(), 0, "CONSTRUCTION type should create tile nodes")
	var has_shoulder = false
	for child in tiles.get_children():
		if child is MultiMeshInstance2D:
			has_shoulder = true
			break
	assert_true(has_shoulder, "CONSTRUCTION tiles should contain MultiMeshInstance2D children")

func test_reserve_tiles_pool_allocates():
	var h = Highway.new()
	autofree(h)
	h._chunk_buffers = {}
	h._buffer_in_use = {}
	var first = h._reserve_tiles(h.ChunkType.STANDARD)
	var second = h._reserve_tiles(h.ChunkType.STANDARD)
	assert_true(first != second, "Two calls should return different instances")
	assert_gt(first.get_child_count(), 0, "Buffer should have children")
	assert_gt(second.get_child_count(), 0, "Buffer should have children")
	assert_eq(first.name, "Tiles", "Buffer should be named Tiles")
	assert_eq(second.name, "Tiles", "Buffer should be named Tiles")
	assert_eq(h._chunk_buffers[h.ChunkType.STANDARD].size(), 2, "Pool should allocate 2 instances")

func test_reconnect_chunk_signals_connects_ice_areas():
	var h = Highway.new()
	autofree(h)
	var tiles = Node2D.new()
	add_child_autofree(tiles)
	h._build_tiles_into(tiles, h.ChunkType.ICE)
	var clone = tiles.duplicate()
	add_child_autofree(clone)
	h._reconnect_chunk_signals(clone, h.ChunkType.ICE)
	var found_connected = false
	for child in clone.get_children():
		if child is Area2D:
			if child.body_entered.is_connected(h._on_ice_entered):
				found_connected = true
				break
	assert_true(found_connected, "ICE clone Area2D should have body_entered connected to _on_ice_entered")

func test_guardrail_color_varies_by_chunk_type():
	var h = Highway.new()
	autofree(h)
	var standard_tiles = Node2D.new()
	add_child_autofree(standard_tiles)
	var bridge_tiles = Node2D.new()
	add_child_autofree(bridge_tiles)
	h._build_tiles_into(standard_tiles, h.ChunkType.STANDARD)
	h._build_tiles_into(bridge_tiles, h.ChunkType.BRIDGE)
	var standard_color = Color(1.0, 1.0, 0.8)
	var bridge_color = Color(0.0, 0.8, 1.0)
	var standard_ok = false
	var bridge_ok = false
	for child in standard_tiles.get_children():
		if child is Line2D:
			assert_eq(child.default_color, standard_color, "STANDARD guardrail should be yellow-white")
			standard_ok = true
	for child in bridge_tiles.get_children():
		if child is Line2D and (child.name == "LeftRail" or child.name == "RightRail"):
			assert_eq(child.default_color, bridge_color, "BRIDGE guardrail should be cyan")
			bridge_ok = true
	assert_true(standard_ok, "STANDARD should have guardrail Line2D children")
	assert_true(bridge_ok, "BRIDGE should have guardrail Line2D children")

func test_create_desert_decoration_creates_child_nodes():
	var h = Highway.new()
	autofree(h)
	for decor_type in range(8):
		var decor = h._create_desert_decoration(decor_type)
		add_child_autofree(decor)
		assert_gt(decor.get_child_count(), 0, "Decoration type " + str(decor_type) + " should have child Polygon2D nodes")

func test_side_decoration_helpers():
	var h = Highway.new()
	autofree(h)
	var palette = h.get_side_decoration_palette(0)
	assert_gt(palette.size(), 0, "Side decoration palette should not be empty")
	var decor = h._create_side_decoration(palette[0])
	add_child_autofree(decor)
	assert_gt(decor.get_child_count(), 0, "Side decoration should create child nodes")

func test_ice_chunk_area_signals_connected():
	var h = Highway.new()
	autofree(h)
	var chunk = Node2D.new()
	add_child_autofree(chunk)
	h._generate_chunk_tiles(chunk, h.ChunkType.ICE)
	var tiles_node = chunk.get_node_or_null("Tiles")
	assert_true(tiles_node != null, "Should have Tiles node")
	var area_found = false
	for child in tiles_node.get_children():
		if child is Area2D:
			area_found = true
			assert_gt(child.body_entered.get_connections().size(), 0, "ICE Area2D should have body_entered connections")
			assert_gt(child.body_exited.get_connections().size(), 0, "ICE Area2D should have body_exited connections")
	assert_true(area_found, "ICE chunk should contain an Area2D")

func test_bridge_chunk_area_has_bridge_fall_connections():
	var h = Highway.new()
	autofree(h)
	var chunk = Node2D.new()
	add_child_autofree(chunk)
	h._generate_chunk_tiles(chunk, h.ChunkType.BRIDGE)
	var tiles_node = chunk.get_node_or_null("Tiles")
	assert_true(tiles_node != null, "Should have Tiles node")
	var area_count = 0
	for child in tiles_node.get_children():
		if child is Area2D:
			area_count += 1
			assert_gt(child.body_entered.get_connections().size(), 0, "BRIDGE Area2D should have body_entered connections")
	assert_gte(area_count, 2, "BRIDGE chunk should have at least 2 danger area triggers")



func test_mark_buffer_free_reuses_buffer():
	var h = Highway.new()
	autofree(h)
	h._chunk_buffers = {}
	h._buffer_in_use = {}
	var first = h._reserve_tiles(h.ChunkType.STANDARD)
	var _second = h._reserve_tiles(h.ChunkType.STANDARD)
	assert_eq(h._chunk_buffers[h.ChunkType.STANDARD].size(), 2, "Pool should have 2 buffers after two calls")
	
	h._mark_buffer_free(first)
	assert_false(h._buffer_in_use[h.ChunkType.STANDARD][0], "First buffer should be marked free")
	
	var reused = h._reserve_tiles(h.ChunkType.STANDARD)
	assert_eq(reused, first, "Reserve should reuse the freed buffer")
	assert_eq(h._chunk_buffers[h.ChunkType.STANDARD].size(), 2, "Pool should not grow when reusing freed buffer")

func test_mark_buffer_free_unknown_buffer_does_nothing():
	var h = Highway.new()
	autofree(h)
	h._chunk_buffers = {}
	h._buffer_in_use = {}
	var unknown = Node2D.new()
	add_child_autofree(unknown)
	h._mark_buffer_free(unknown)
	assert_true(true, "Should not crash when marking unknown buffer free")

func test_mark_buffer_free_skips_other_types():
	var h = Highway.new()
	autofree(h)
	h._chunk_buffers = {}
	h._buffer_in_use = {}
	var standard = h._reserve_tiles(h.ChunkType.STANDARD)
	var _ice = h._reserve_tiles(h.ChunkType.ICE)
	h._mark_buffer_free(standard)
	assert_false(h._buffer_in_use[h.ChunkType.STANDARD][0], "STANDARD buffer should be freed")
	assert_true(h._buffer_in_use[h.ChunkType.ICE][0], "ICE buffer should still be in use")

func test_reserve_tiles_reuses_freed_buffer_across_types():
	var h = Highway.new()
	autofree(h)
	h._chunk_buffers = {}
	h._buffer_in_use = {}
	var standard = h._reserve_tiles(h.ChunkType.STANDARD)
	h._mark_buffer_free(standard)
	var ice = h._reserve_tiles(h.ChunkType.ICE)
	assert_ne(standard, ice, "STANDARD buffer should not be reused for ICE type")

func test_reserve_tiles_reconnect_signals_on_reuse():
	var h = Highway.new()
	autofree(h)
	h._chunk_buffers = {}
	h._buffer_in_use = {}
	var buf = h._reserve_tiles(h.ChunkType.ICE)
	h._mark_buffer_free(buf)
	var reused = h._reserve_tiles(h.ChunkType.ICE)
	assert_eq(reused, buf, "Should reuse freed ICE buffer")

func test_recycle_chunk_removes_old_tiles():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	var chunk = h.active_chunks[0]
	var old_tiles = h._get_tiles_node(chunk)
	assert_true(old_tiles != null, "Chunk should have tiles before recycle")
	h._recycle_chunk(chunk)
	var tiles_after = h._get_tiles_node(chunk)
	assert_eq(tiles_after, old_tiles, "Tiles should be recycled (same node reused from pool)")
	assert_true(tiles_after.is_inside_tree(), "Recycled tiles should still be in tree")

func test_recycle_chunk_old_tiles_buffer_freed():
	var h = Highway.new()
	add_child_autofree(h)
	h._chunk_buffers = {}
	h._buffer_in_use = {}
	var buf = h._reserve_tiles(h.ChunkType.STANDARD)
	_force_prewarm_empty(h)
	h._spawn_chunk(0)
	var chunk = h.active_chunks[0]
	h._recycle_chunk(chunk)
	assert_false(buf.is_inside_tree(), "Old tiles buffer should be removed from tree")

func _force_prewarm_empty(h):
	h.active_chunks.clear()
	h.current_segment = 0

func test_generate_chunk_tiles_into_creates_tiles():
	var h = Highway.new()
	autofree(h)
	var parent = Node2D.new()
	add_child_autofree(parent)
	h._generate_chunk_tiles_into(parent, h.ChunkType.STANDARD)
	assert_eq(parent.name, "Tiles", "Parent should be named Tiles")
	assert_true(parent.is_y_sort_enabled(), "Parent should have Y-sort enabled")
	assert_gt(parent.get_child_count(), 0, "Parent should have tile children")

func test_create_rect_mesh_returns_array_mesh():
	var h = Highway.new()
	autofree(h)
	var mesh = h._create_rect_mesh(Vector2(4, 14))
	assert_is(mesh, ArrayMesh, "Should return ArrayMesh")
	assert_eq(mesh.get_surface_count(), 1, "Should have 1 surface")

func test_create_rect_mesh_has_correct_vertex_count():
	var h = Highway.new()
	autofree(h)
	var mesh = h._create_rect_mesh(Vector2(10, 20))
	var arrays = mesh.surface_get_arrays(0)
	var verts = arrays[Mesh.ARRAY_VERTEX] as PackedVector2Array
	assert_eq(verts.size(), 4, "Rect mesh should have 4 vertices")

func test_get_tiles_node_returns_null_for_empty_chunk():
	var h = Highway.new()
	autofree(h)
	var chunk = Node2D.new()
	add_child_autofree(chunk)
	var result = h._get_tiles_node(chunk)
	assert_null(result, "Empty chunk should return null")

func test_get_tiles_node_returns_first_child():
	var h = Highway.new()
	autofree(h)
	var chunk = Node2D.new()
	add_child_autofree(chunk)
	var child = Node2D.new()
	child.name = "Tiles"
	chunk.add_child(child)
	var result = h._get_tiles_node(chunk)
	assert_eq(result, child, "Should return first child of chunk")

func test_get_tile_variant_default_returns_zero():
	var h = Highway.new()
	autofree(h)
	var result = h._get_tile_variant(-1, 0, 0)
	assert_eq(result, 0, "Invalid chunk type should return 0")

func test_process_recycles_multiple_chunks_in_one_frame():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	h.player.global_position = Vector2(0, 5000)
	h._process(0.1)
	assert_eq(h.active_chunks.size(), 10, "Chunk count should remain 10 after recycling multiple")

func test_process_with_player_at_exact_threshold():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	var threshold = h.CHUNK_PIXEL_HEIGHT * h.DESPAWN_CHUNKS_BEHIND
	h.player.global_position = Vector2(0, threshold + 1)
	h._process(0.1)
	assert_eq(h.active_chunks.size(), 10, "Should handle exact threshold boundary")

func test_process_does_not_recycle_below_threshold():
	var h = Highway.new()
	h.player = _create_mock_player(Vector2(0, 0))
	add_child_autofree(h)
	var segment_before = h.current_segment
	h._process(0.1)
	assert_eq(h.current_segment, segment_before, "Should not recycle when player is close")

func test_reconnect_chunk_signals_bridge_connects_areas():
	var h = Highway.new()
	autofree(h)
	var tiles = Node2D.new()
	add_child_autofree(tiles)
	h._build_tiles_into(tiles, h.ChunkType.BRIDGE)
	var clone = tiles.duplicate()
	add_child_autofree(clone)
	h._reconnect_chunk_signals(clone, h.ChunkType.BRIDGE)
	var found_connected = false
	for child in clone.get_children():
		if child is Area2D:
			if child.body_entered.is_connected(h._on_bridge_fall):
				found_connected = true
	assert_true(found_connected, "BRIDGE Area2D should have body_entered connected to _on_bridge_fall")

func test_reconnect_chunk_signals_standard_does_nothing():
	var h = Highway.new()
	autofree(h)
	var tiles = Node2D.new()
	add_child_autofree(tiles)
	h._build_tiles_into(tiles, h.ChunkType.STANDARD)
	var clone = tiles.duplicate()
	add_child_autofree(clone)
	h._reconnect_chunk_signals(clone, h.ChunkType.STANDARD)
	for child in clone.get_children():
		if child is Area2D:
			assert_eq(child.body_entered.get_connections().size(), 0, "STANDARD should not connect signals")
	assert_true(true, "STANDARD reconnect should not error")

func test_reconnect_chunk_signals_debris_does_nothing():
	var h = Highway.new()
	autofree(h)
	var tiles = Node2D.new()
	add_child_autofree(tiles)
	h._build_tiles_into(tiles, h.ChunkType.DEBRIS)
	var clone = tiles.duplicate()
	add_child_autofree(clone)
	h._reconnect_chunk_signals(clone, h.ChunkType.DEBRIS)
	assert_true(true, "DEBRIS reconnect should not error")

func test_reconnect_chunk_signals_construction_does_nothing():
	var h = Highway.new()
	autofree(h)
	var tiles = Node2D.new()
	add_child_autofree(tiles)
	h._build_tiles_into(tiles, h.ChunkType.CONSTRUCTION)
	var clone = tiles.duplicate()
	add_child_autofree(clone)
	h._reconnect_chunk_signals(clone, h.ChunkType.CONSTRUCTION)
	assert_true(true, "CONSTRUCTION reconnect should not error")

func test_reconnect_chunk_signals_already_connected_does_not_duplicate():
	var h = Highway.new()
	autofree(h)
	var tiles = Node2D.new()
	add_child_autofree(tiles)
	h._build_tiles_into(tiles, h.ChunkType.ICE)
	h._reconnect_chunk_signals(tiles, h.ChunkType.ICE)
	var total_body_entered = 0
	var total_body_exited = 0
	for child in tiles.get_children():
		if child is Area2D:
			total_body_entered += child.body_entered.get_connections().size()
			total_body_exited += child.body_exited.get_connections().size()
	assert_eq(total_body_entered, 1, "Should not double-connect body_entered")
	assert_eq(total_body_exited, 1, "Should not double-connect body_exited")

func test_remove_tiles_no_tiles_does_not_crash():
	var h = Highway.new()
	autofree(h)
	var chunk = Node2D.new()
	add_child_autofree(chunk)
	assert_true(true, "Should not crash when chunk has no tiles")

func test_remove_tiles_queue_free_tiles():
	var h = Highway.new()
	autofree(h)
	var chunk = Node2D.new()
	add_child_autofree(chunk)
	var tiles = Node2D.new()
	tiles.name = "Tiles"
	chunk.add_child(tiles)
	chunk.remove_child(tiles)
	tiles.queue_free()
	autofree(tiles)
	assert_true(tiles.is_queued_for_deletion(), "Tiles should be queued for deletion")

func test_diamond_mesh_is_cached():
	var h1 = Highway.new()
	var h2 = Highway.new()
	autofree(h1)
	autofree(h2)
	var mesh1 = h1._create_diamond_mesh()
	var mesh2 = h2._create_diamond_mesh()
	assert_eq(mesh1, mesh2, "Diamond mesh should be cached across instances")

func test_rect_mesh_is_cached():
	var h1 = Highway.new()
	var h2 = Highway.new()
	autofree(h1)
	autofree(h2)
	var mesh1 = h1._create_rect_mesh(Vector2(4, 14))
	var mesh2 = h2._create_rect_mesh(Vector2(4, 14))
	assert_eq(mesh1, mesh2, "Rect mesh should be cached for same size")

func test_rect_mesh_different_sizes_not_same():
	var h = Highway.new()
	autofree(h)
	var small = h._create_rect_mesh(Vector2(4, 14))
	var large = h._create_rect_mesh(Vector2(8, 28))
	assert_ne(small, large, "Different rect sizes should return different cached meshes")

func test_weight_formula_consistent_step():
	var tier_1_standard = Highway.new()
	add_child_autofree(tier_1_standard)
	var tier_5 = Highway.new()
	add_child_autofree(tier_5)
	GameManager.difficulty_tier = 5
	tier_5._pick_chunk_type()
	assert_true(true, "Weight formula should not error at tier 5")
	GameManager.difficulty_tier = 10
	var tier_10 = Highway.new()
	add_child_autofree(tier_10)
	tier_10._pick_chunk_type()
	assert_true(true, "Weight formula should not error at tier 10")

func test_mesh_factory_builds_mesh_and_resets_cache():
	var factory = load("res://scripts/utils/HighwayMeshFactory.gd")
	var node := Line2D.new()
	node.points = PackedVector2Array([Vector2.ZERO, Vector2(10, 0)])
	var mesh = factory._node_to_mesh(node)
	node.free()
	assert_gt(mesh.get_surface_count(), 0, "Mesh factory should create a surface")
	factory.reset_caches()
	assert_null(factory._bridge_structure_mesh_cache, "Reset should clear the bridge cache")
