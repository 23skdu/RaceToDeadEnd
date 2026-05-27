extends Node2D

signal segment_completed(segment: int)
signal ice_entered(body: Node)
signal ice_exited(body: Node)
signal bridge_fall(body: Node)

const CHUNK_HEIGHT: int = 10
const CHUNK_WIDTH: int = 14
const TILE_SIZE: Vector2i = Vector2i(48, 24)
const CHUNK_PIXEL_HEIGHT: int = 240
const PREWARM_CHUNKS: int = 8
const DESPAWN_CHUNKS_BEHIND: int = 3

const LANE_COUNT: int = 8
const SHOULDER_COLUMNS: int = 3
const LANE_START_COL: int = 3
const LANE_END_COL: int = 10
const HALF_CHUNK: float = (CHUNK_WIDTH - 1) / 2.0

enum ChunkType { STANDARD, DEBRIS, ICE, CONSTRUCTION, BRIDGE }

var chunk_weights: Dictionary = {
	ChunkType.STANDARD: Constants.CHUNK_WEIGHT_STANDARD_BASE,
	ChunkType.DEBRIS: Constants.CHUNK_WEIGHT_DEBRIS_BASE,
	ChunkType.ICE: Constants.CHUNK_WEIGHT_ICE_BASE,
	ChunkType.CONSTRUCTION: Constants.CHUNK_WEIGHT_CONSTRUCTION_BASE,
	ChunkType.BRIDGE: Constants.CHUNK_WEIGHT_BRIDGE_BASE,
}

var active_chunks: Array[Node2D] = []
var current_segment: int = 0
var player: Node = null
var white_texture: Texture2D

var _chunk_buffers: Dictionary = {}
var _buffer_in_use: Dictionary = {}

static var _diamond_mesh_cache: ArrayMesh = null
static var _diamond_mesh_lane_cache: ArrayMesh = null
static var _diamond_mesh_shoulder_cache: ArrayMesh = null
static var _rect_mesh_cache: Dictionary = {}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	white_texture = ImageTexture.create_from_image(img)
	
	_rng.seed = hash("highway_seed")
	
	for i in range(-3, PREWARM_CHUNKS - 3):
		_spawn_chunk(i)

func _process(_delta: float) -> void:
	if not player:
		return
	var player_y = to_local(player.global_position).y
	var threshold = CHUNK_PIXEL_HEIGHT * DESPAWN_CHUNKS_BEHIND
	for chunk in active_chunks:
		if chunk.position.y - player_y > threshold:
			_recycle_chunk(chunk)

func _spawn_chunk(offset: int) -> void:
	var chunk = Node2D.new()
	var chunk_type = _pick_chunk_type()
	if offset < 2:
		chunk_type = ChunkType.STANDARD
	chunk.position.y = -offset * CHUNK_PIXEL_HEIGHT
	chunk.set_meta("chunk_type", chunk_type)
	chunk.set_meta("segment", current_segment)
	
	var tiles = _reserve_tiles(chunk_type)
	chunk.add_child(tiles)
	
	active_chunks.append(chunk)
	add_child(chunk)
	current_segment += 1

func _recycle_chunk(chunk: Node2D) -> void:
	var lowest_y = INF
	for c in active_chunks:
		if c.position.y < lowest_y:
			lowest_y = c.position.y
	chunk.position.y = lowest_y - CHUNK_PIXEL_HEIGHT
	var new_type = _pick_chunk_type()
	chunk.set_meta("chunk_type", new_type)
	chunk.set_meta("segment", current_segment)
	
	var old_tiles = _get_tiles_node(chunk)
	if old_tiles:
		chunk.remove_child(old_tiles)
		_mark_buffer_free(old_tiles)
	
	var new_tiles = _reserve_tiles(new_type)
	chunk.add_child(new_tiles)
	
	current_segment += 1
	segment_completed.emit(current_segment)

func _reserve_tiles(chunk_type: ChunkType) -> Node2D:
	if not _chunk_buffers.has(chunk_type):
		_chunk_buffers[chunk_type] = []
		_buffer_in_use[chunk_type] = []
	
	var buffers: Array = _chunk_buffers[chunk_type]
	var in_use: Array = _buffer_in_use[chunk_type]
	
	for i in buffers.size():
		if not in_use[i]:
			in_use[i] = true
			_reconnect_chunk_signals(buffers[i], chunk_type)
			return buffers[i]
	
	var tiles = Node2D.new()
	tiles.name = "Tiles"
	tiles.set_y_sort_enabled(true)
	_build_tiles_into(tiles, chunk_type)
	buffers.append(tiles)
	in_use.append(true)
	_reconnect_chunk_signals(tiles, chunk_type)
	return tiles

func _mark_buffer_free(tiles_node: Node2D) -> void:
	for chunk_type in _chunk_buffers:
		var buffers: Array = _chunk_buffers[chunk_type]
		var in_use: Array = _buffer_in_use[chunk_type]
		for i in buffers.size():
			if buffers[i] == tiles_node:
				in_use[i] = false
				return

func _reconnect_chunk_signals(tiles_node: Node2D, chunk_type: ChunkType) -> void:
	if chunk_type == ChunkType.ICE:
		for child in tiles_node.get_children():
			if child is Area2D:
				if not child.body_entered.is_connected(_on_ice_entered):
					child.body_entered.connect(_on_ice_entered)
				if not child.body_exited.is_connected(_on_ice_exited):
					child.body_exited.connect(_on_ice_exited)
	elif chunk_type == ChunkType.BRIDGE:
		for child in tiles_node.get_children():
			if child is Area2D:
				if not child.body_entered.is_connected(_on_bridge_fall):
					child.body_entered.connect(_on_bridge_fall)

func _pick_chunk_type() -> ChunkType:
	var tier = GameManager.difficulty_tier
	var hazard_increase = mini(tier - 1, Constants.CHUNK_HAZARD_CAP) * Constants.CHUNK_HAZARD_STEP
	var w_standard = maxi(int(Constants.CHUNK_WEIGHT_STANDARD_BASE) - hazard_increase, int(Constants.CHUNK_WEIGHT_STANDARD_MIN))
	var w_debris = mini(int(Constants.CHUNK_WEIGHT_DEBRIS_BASE) + hazard_increase, int(Constants.CHUNK_WEIGHT_DEBRIS_MAX))
	var w_ice = mini(int(Constants.CHUNK_WEIGHT_ICE_BASE) + hazard_increase, int(Constants.CHUNK_WEIGHT_ICE_MAX))
	var w_construction = mini(int(Constants.CHUNK_WEIGHT_CONSTRUCTION_BASE) + hazard_increase, int(Constants.CHUNK_WEIGHT_CONSTRUCTION_MAX))
	var w_bridge = mini(int(Constants.CHUNK_WEIGHT_BRIDGE_BASE) + hazard_increase, int(Constants.CHUNK_WEIGHT_BRIDGE_MAX))
	var total = w_standard + w_debris + w_ice + w_construction + w_bridge
	var roll = _rng.randi() % int(total)
	if roll < w_standard:
		return ChunkType.STANDARD
	roll -= w_standard
	if roll < w_debris:
		return ChunkType.DEBRIS
	roll -= w_debris
	if roll < w_ice:
		return ChunkType.ICE
	roll -= w_ice
	if roll < w_construction:
		return ChunkType.CONSTRUCTION
	return ChunkType.BRIDGE

func _generate_chunk_tiles(chunk: Node2D, chunk_type: ChunkType) -> void:
	var chunk_local = Node2D.new()
	chunk_local.name = "Tiles"
	chunk_local.set_y_sort_enabled(true)
	_build_tiles_into(chunk_local, chunk_type)
	chunk.add_child(chunk_local)

func _generate_chunk_tiles_into(parent: Node2D, chunk_type: ChunkType) -> void:
	parent.name = "Tiles"
	parent.set_y_sort_enabled(true)
	_build_tiles_into(parent, chunk_type)

func _build_tiles_into(chunk_local: Node2D, chunk_type: ChunkType) -> void:
	var half_w = TILE_SIZE.x / 2.0
	var half_h = TILE_SIZE.y / 2.0
	
	var bg_color: Color
	match chunk_type:
		ChunkType.BRIDGE:
			bg_color = Color(0.08, 0.08, 0.14)
		ChunkType.CONSTRUCTION:
			bg_color = Color(0.7, 0.5, 0.0)
		ChunkType.ICE:
			bg_color = Color(0.5, 0.8, 0.95, 0.35)
		_:
			bg_color = Color(0.76, 0.64, 0.42)
	var bg = Polygon2D.new()
	var bg_half_w = 640.0
	bg.polygon = PackedVector2Array([
		Vector2(-bg_half_w, -half_h),
		Vector2(bg_half_w, -half_h),
		Vector2(bg_half_w, CHUNK_PIXEL_HEIGHT + half_h),
		Vector2(-bg_half_w, CHUNK_PIXEL_HEIGHT + half_h),
	])
	bg.color = bg_color
	chunk_local.add_child(bg)
	
	var lane_polygons = []
	var shoulder_polygons = []
	var stripe_positions = []
	var desert_decorations = []
	var obstacle_positions = []
	
	for row in CHUNK_HEIGHT:
		for col in CHUNK_WIDTH:
			var tile_variant = _get_tile_variant(chunk_type, row, col)
			
			var x_pos: float = 0.0
			if col < LANE_START_COL:
				var sh_col_w = 160.0 / 3.0
				x_pos = -640.0 + col * sh_col_w + sh_col_w / 2.0
				if row % 2 == 1:
					x_pos += sh_col_w / 2.0
					if x_pos >= -480.0:
						x_pos -= 160.0
			elif col > LANE_END_COL:
				var sh_col_w = 160.0 / 3.0
				var right_col_idx = col - 11
				x_pos = 480.0 + right_col_idx * sh_col_w + sh_col_w / 2.0
				if row % 2 == 1:
					x_pos += sh_col_w / 2.0
					if x_pos >= 640.0:
						x_pos -= 160.0
			else:
				var lane_idx = col - 3
				var lane_w = 120.0
				x_pos = -480.0 + lane_idx * lane_w + lane_w / 2.0
				if row % 2 == 1:
					x_pos += lane_w / 2.0
					if x_pos >= 480.0:
						x_pos -= 960.0
						
			var y_pos = row * TILE_SIZE.y
			
			if col < LANE_START_COL or col > LANE_END_COL:
				if chunk_type == ChunkType.BRIDGE:
					var tile_color = Color(0.12, 0.11, 0.10)
					shoulder_polygons.append({"pos": Vector2(x_pos, y_pos), "color": tile_color})
				elif chunk_type == ChunkType.CONSTRUCTION:
					var tile_color = Color(0.7, 0.5, 0.0)
					shoulder_polygons.append({"pos": Vector2(x_pos, y_pos), "color": tile_color})
				elif chunk_type == ChunkType.ICE:
					var tile_color = Color(0.65, 0.88, 0.95, 0.45)
					shoulder_polygons.append({"pos": Vector2(x_pos, y_pos), "color": tile_color})
				else:
					var tile_color = Color(0.76, 0.64, 0.42)
					shoulder_polygons.append({"pos": Vector2(x_pos, y_pos), "color": tile_color})
					
					if _rng.randf() < 0.03:
						var decor_type = _rng.randi() % 4
						desert_decorations.append({"pos": Vector2(x_pos, y_pos), "type": decor_type})
			else:
				if chunk_type == ChunkType.ICE:
					var tile_color = Color(0.45, 0.85, 1.0, 0.7)
					if _rng.randf() < 0.15:
						tile_color = Color(0.8, 0.95, 1.0, 0.85)
					lane_polygons.append({"pos": Vector2(x_pos, y_pos), "color": tile_color})
				elif chunk_type == ChunkType.BRIDGE:
					var tile_color = Color(0.35, 0.32, 0.30)
					lane_polygons.append({"pos": Vector2(x_pos, y_pos), "color": tile_color})
				else:
					var tile_color = Color(0.18, 0.18, 0.22)
					lane_polygons.append({"pos": Vector2(x_pos, y_pos), "color": tile_color})
					
					if col > LANE_START_COL and col <= LANE_END_COL and (col - LANE_START_COL) % 2 == 0:
						if row % 2 == 0:
							var stripe_x = -480.0 + (col - LANE_START_COL) * 120.0
							stripe_positions.append({"pos": Vector2(stripe_x, y_pos)})
			
			if tile_variant == 1 or tile_variant == 3:
				obstacle_positions.append({
					"pos": Vector2(x_pos, y_pos),
					"color": Color(1.0, 0.35, 0.15) if tile_variant == 1 else Color(1.0, 0.75, 0.0)
				})
	
	if lane_polygons.size() > 0:
		var lane_merged = MultiMeshInstance2D.new()
		lane_merged.texture = white_texture
		var multimesh = MultiMesh.new()
		multimesh.mesh = _create_diamond_mesh_lane()
		multimesh.instance_count = lane_polygons.size()
		for i in lane_polygons.size():
			multimesh.set_instance_transform_2d(i, Transform2D(0.0, lane_polygons[i]["pos"]))
		lane_merged.multimesh = multimesh
		lane_merged.modulate = lane_polygons[0]["color"]
		chunk_local.add_child(lane_merged)
		
		var edge_marking_color = Color(0.9, 0.9, 0.5, 0.6)
		var edge_marking = MultiMeshInstance2D.new()
		edge_marking.texture = white_texture
		var emesh = MultiMesh.new()
		emesh.mesh = _create_rect_mesh(Vector2(2, half_h * 0.9))
		var edge_positions: Array[Vector2] = []
		for row in CHUNK_HEIGHT:
			var y_pos = row * TILE_SIZE.y + half_h
			edge_positions.append(Vector2(-480.0, y_pos))
			edge_positions.append(Vector2(480.0, y_pos))
		emesh.instance_count = edge_positions.size()
		for i in edge_positions.size():
			emesh.set_instance_transform_2d(i, Transform2D(0.0, edge_positions[i]))
		edge_marking.multimesh = emesh
		edge_marking.modulate = edge_marking_color
		chunk_local.add_child(edge_marking)
	
	if shoulder_polygons.size() > 0:
		var shoulder_merged = MultiMeshInstance2D.new()
		shoulder_merged.texture = white_texture
		var multimesh = MultiMesh.new()
		multimesh.mesh = _create_diamond_mesh_shoulder()
		multimesh.instance_count = shoulder_polygons.size()
		for i in shoulder_polygons.size():
			multimesh.set_instance_transform_2d(i, Transform2D(0.0, shoulder_polygons[i]["pos"]))
		shoulder_merged.multimesh = multimesh
		shoulder_merged.modulate = shoulder_polygons[0]["color"]
		chunk_local.add_child(shoulder_merged)
	
	if stripe_positions.size() > 0:
		var stripe_mmi = MultiMeshInstance2D.new()
		stripe_mmi.texture = white_texture
		var smesh = MultiMesh.new()
		smesh.mesh = _create_rect_mesh(Vector2(4, half_h * 1.2))
		smesh.instance_count = stripe_positions.size()
		for i in stripe_positions.size():
			smesh.set_instance_transform_2d(i, Transform2D(0.0, stripe_positions[i]["pos"]))
		stripe_mmi.multimesh = smesh
		stripe_mmi.modulate = Color(1.0, 1.0, 0.8)
		chunk_local.add_child(stripe_mmi)
	
	for decor in desert_decorations:
		var decor_node = _create_desert_decoration(decor["type"])
		if decor_node:
			decor_node.position = decor["pos"]
			chunk_local.add_child(decor_node)
			
			if decor["type"] == 2 or decor["type"] == 3:
				var crash_obstacle = StaticBody2D.new()
				crash_obstacle.collision_layer = 1
				crash_obstacle.collision_mask = 1
				crash_obstacle.position = decor["pos"]
				crash_obstacle.add_to_group("deadly_obstacles")
				
				var col_shape = CollisionShape2D.new()
				var rect_shape = RectangleShape2D.new()
				rect_shape.size = Vector2(20, 20)
				col_shape.shape = rect_shape
				crash_obstacle.add_child(col_shape)
				
				chunk_local.add_child(crash_obstacle)
	
	for obs in obstacle_positions:
		var obstacle = StaticBody2D.new()
		obstacle.collision_layer = 1
		obstacle.collision_mask = 1
		obstacle.position = obs["pos"]
		obstacle.add_to_group("obstacles")
		
		var col_poly = CollisionPolygon2D.new()
		var sf = 0.85
		col_poly.polygon = PackedVector2Array([
			Vector2(0, -half_h * sf),
			Vector2(half_w * sf, 0),
			Vector2(0, half_h * sf),
			Vector2(-half_w * sf, 0)
		])
		obstacle.add_child(col_poly)
		
		var visual = Polygon2D.new()
		visual.polygon = col_poly.polygon
		visual.color = obs["color"]
		obstacle.add_child(visual)
		
		var highlight = Polygon2D.new()
		highlight.polygon = PackedVector2Array([
			Vector2(0, -half_h * sf * 0.5),
			Vector2(half_w * sf * 0.5, 0),
			Vector2(0, half_h * sf * 0.5),
			Vector2(-half_w * sf * 0.5, 0)
		])
		highlight.color = Color(1.0, 1.0, 1.0, 0.5)
		obstacle.add_child(highlight)
		
		chunk_local.add_child(obstacle)
	
	if lane_polygons.size() > 0 and chunk_type != ChunkType.ICE and chunk_type != ChunkType.BRIDGE:
		var crack_mmi = MultiMeshInstance2D.new()
		crack_mmi.texture = white_texture
		var cmesh = MultiMesh.new()
		cmesh.mesh = _create_rect_mesh(Vector2(1, half_h * 0.3))
		var crack_positions: Array[Vector2] = []
		for row in CHUNK_HEIGHT:
			for col in range(LANE_START_COL + 1, LANE_END_COL):
				var lane_cx = -480.0 + (col - 3) * 120.0 + 60.0
				var y_pos = row * TILE_SIZE.y + half_h * 0.5
				if _rng.randf() < 0.12:
					var x_offset = _rng.randf_range(-120.0 * 0.35, 120.0 * 0.35)
					crack_positions.append(Vector2(lane_cx + x_offset, y_pos))
		if crack_positions.size() > 0:
			cmesh.instance_count = crack_positions.size()
			for i in crack_positions.size():
				cmesh.set_instance_transform_2d(i, Transform2D(0.0, crack_positions[i]))
			crack_mmi.multimesh = cmesh
			crack_mmi.modulate = Color(0.0, 0.0, 0.0, 0.15)
			chunk_local.add_child(crack_mmi)

	var left_rail_x = -480.0
	var right_rail_x = 480.0
	
	var left_rail = Line2D.new()
	left_rail.name = "LeftRail"
	left_rail.width = Constants.GUARDRAIL_WIDTH
	left_rail.default_color = Constants.GUARDRAIL_COLOR if chunk_type != ChunkType.BRIDGE else Constants.BRIDGE_GUARDRAIL_COLOR
	var left_points = PackedVector2Array()
	for row in CHUNK_HEIGHT + 1:
		var y_pos = row * TILE_SIZE.y
		left_points.append(Vector2(left_rail_x, y_pos))
	left_rail.points = left_points
	chunk_local.add_child(left_rail)
	
	var right_rail = Line2D.new()
	right_rail.name = "RightRail"
	right_rail.width = Constants.GUARDRAIL_WIDTH
	right_rail.default_color = Constants.GUARDRAIL_COLOR if chunk_type != ChunkType.BRIDGE else Constants.BRIDGE_GUARDRAIL_COLOR
	var right_points = PackedVector2Array()
	for row in CHUNK_HEIGHT + 1:
		var y_pos = row * TILE_SIZE.y
		right_points.append(Vector2(right_rail_x, y_pos))
	right_rail.points = right_points
	chunk_local.add_child(right_rail)
	
	if chunk_type != ChunkType.BRIDGE and chunk_type != ChunkType.ICE:
		var post_color = Color(0.5, 0.5, 0.5, 0.7)
		var post_mmi = MultiMeshInstance2D.new()
		post_mmi.texture = white_texture
		var pmesh = MultiMesh.new()
		pmesh.mesh = _create_rect_mesh(Vector2(2, 6))
		var post_positions: Array[Vector2] = []
		for row in range(0, CHUNK_HEIGHT + 1, 2):
			var y_pos = row * TILE_SIZE.y + half_h
			post_positions.append(Vector2(left_rail_x, y_pos))
			post_positions.append(Vector2(right_rail_x, y_pos))
		pmesh.instance_count = post_positions.size()
		for i in post_positions.size():
			pmesh.set_instance_transform_2d(i, Transform2D(0.0, post_positions[i]))
		post_mmi.multimesh = pmesh
		post_mmi.modulate = post_color
		chunk_local.add_child(post_mmi)
	
	if chunk_type == ChunkType.ICE:
		var ice_area = Area2D.new()
		ice_area.collision_layer = 0
		ice_area.collision_mask = 1
		var ice_col = CollisionPolygon2D.new()
		ice_col.polygon = PackedVector2Array([
			Vector2(left_rail_x, 0),
			Vector2(right_rail_x, 0),
			Vector2(right_rail_x, CHUNK_PIXEL_HEIGHT),
			Vector2(left_rail_x, CHUNK_PIXEL_HEIGHT)
		])
		ice_area.add_child(ice_col)
		ice_area.body_entered.connect(_on_ice_entered)
		ice_area.body_exited.connect(_on_ice_exited)
		chunk_local.add_child(ice_area)
	
	if chunk_type == ChunkType.BRIDGE:
		var beam_every = 3
		for beam_row in range(0, CHUNK_HEIGHT + 1, beam_every):
			var beam_y = beam_row * TILE_SIZE.y
			var beam = Line2D.new()
			beam.width = 6.0
			beam.default_color = Color(0.08, 0.08, 0.12)
			beam.points = PackedVector2Array([
				Vector2(left_rail_x - 12, beam_y),
				Vector2(right_rail_x + 12, beam_y)
			])
			chunk_local.add_child(beam)
			var beam_highlight = Line2D.new()
			beam_highlight.width = 2.0
			beam_highlight.default_color = Color(0.06, 0.06, 0.1)
			beam_highlight.points = PackedVector2Array([
				Vector2(left_rail_x - 12, beam_y + 2),
				Vector2(right_rail_x + 12, beam_y + 2)
			])
			chunk_local.add_child(beam_highlight)
		
		var bridge_width = 160.0
		var left_bridge = Area2D.new()
		left_bridge.collision_layer = 0
		left_bridge.collision_mask = 1
		var left_col = CollisionPolygon2D.new()
		left_col.polygon = PackedVector2Array([
			Vector2(left_rail_x - bridge_width, 0),
			Vector2(left_rail_x, 0),
			Vector2(left_rail_x, CHUNK_PIXEL_HEIGHT),
			Vector2(left_rail_x - bridge_width, CHUNK_PIXEL_HEIGHT)
		])
		left_bridge.add_child(left_col)
		left_bridge.body_entered.connect(_on_bridge_fall)
		chunk_local.add_child(left_bridge)
		
		var right_bridge = Area2D.new()
		right_bridge.collision_layer = 0
		right_bridge.collision_mask = 1
		var right_col = CollisionPolygon2D.new()
		right_col.polygon = PackedVector2Array([
			Vector2(right_rail_x, 0),
			Vector2(right_rail_x + bridge_width, 0),
			Vector2(right_rail_x + bridge_width, CHUNK_PIXEL_HEIGHT),
			Vector2(right_rail_x, CHUNK_PIXEL_HEIGHT)
		])
		right_bridge.add_child(right_col)
		right_bridge.body_entered.connect(_on_bridge_fall)
		chunk_local.add_child(right_bridge)

func _create_rect_mesh(size: Vector2) -> ArrayMesh:
	var key = Vector2(size.x, size.y)
	if _rect_mesh_cache.has(key):
		return _rect_mesh_cache[key]
	var mesh = ArrayMesh.new()
	var half_w = size.x / 2.0
	var half_h = size.y / 2.0
	var vertices = PackedVector2Array([
		Vector2(-half_w, -half_h),
		Vector2(half_w, -half_h),
		Vector2(half_w, half_h),
		Vector2(-half_w, half_h)
	])
	var uvs = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(1.0, 0.0),
		Vector2(1.0, 1.0),
		Vector2(0.0, 1.0)
	])
	var indices = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_rect_mesh_cache[key] = mesh
	return mesh

func _create_diamond_mesh() -> ArrayMesh:
	if _diamond_mesh_cache:
		return _diamond_mesh_cache
	var mesh = ArrayMesh.new()
	var half_w = TILE_SIZE.x / 2.0
	var half_h = TILE_SIZE.y / 2.0
	var vertices = PackedVector2Array([
		Vector2(0, -half_h),
		Vector2(half_w, 0),
		Vector2(0, half_h),
		Vector2(-half_w, 0)
	])
	var uvs = PackedVector2Array([
		Vector2(0.5, 0.0),
		Vector2(1.0, 0.5),
		Vector2(0.5, 1.0),
		Vector2(0.0, 0.5)
	])
	var indices = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_diamond_mesh_cache = mesh
	return mesh

func _create_diamond_mesh_lane() -> ArrayMesh:
	if _diamond_mesh_lane_cache:
		return _diamond_mesh_lane_cache
	var mesh = ArrayMesh.new()
	var half_w = 120.0 / 2.0
	var half_h = TILE_SIZE.y / 2.0
	var vertices = PackedVector2Array([
		Vector2(0, -half_h),
		Vector2(half_w, 0),
		Vector2(0, half_h),
		Vector2(-half_w, 0)
	])
	var uvs = PackedVector2Array([
		Vector2(0.5, 0.0),
		Vector2(1.0, 0.5),
		Vector2(0.5, 1.0),
		Vector2(0.0, 0.5)
	])
	var indices = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_diamond_mesh_lane_cache = mesh
	return mesh

func _create_diamond_mesh_shoulder() -> ArrayMesh:
	if _diamond_mesh_shoulder_cache:
		return _diamond_mesh_shoulder_cache
	var mesh = ArrayMesh.new()
	var half_w = (160.0 / 3.0) / 2.0
	var half_h = TILE_SIZE.y / 2.0
	var vertices = PackedVector2Array([
		Vector2(0, -half_h),
		Vector2(half_w, 0),
		Vector2(0, half_h),
		Vector2(-half_w, 0)
	])
	var uvs = PackedVector2Array([
		Vector2(0.5, 0.0),
		Vector2(1.0, 0.5),
		Vector2(0.5, 1.0),
		Vector2(0.0, 0.5)
	])
	var indices = PackedInt32Array([0, 1, 2, 0, 2, 3])
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_diamond_mesh_shoulder_cache = mesh
	return mesh

func _create_desert_decoration(type: int) -> Node2D:
	var decor = Node2D.new()
	match type:
		0:
			var cactus = Polygon2D.new()
			cactus.polygon = PackedVector2Array([
				Vector2(-3, -12),
				Vector2(3, -12),
				Vector2(3, 8),
				Vector2(-3, 8)
			])
			cactus.color = Color(0.2, 0.5, 0.2)
			decor.add_child(cactus)
			
			var arm1 = Polygon2D.new()
			arm1.polygon = PackedVector2Array([
				Vector2(0, -4),
				Vector2(8, -8),
				Vector2(8, -4),
				Vector2(0, 0)
			])
			arm1.color = Color(0.2, 0.5, 0.2)
			decor.add_child(arm1)
		1:
			var skull = Polygon2D.new()
			skull.polygon = PackedVector2Array([
				Vector2(-5, -5),
				Vector2(5, -5),
				Vector2(6, 0),
				Vector2(4, 5),
				Vector2(-4, 5),
				Vector2(-6, 0)
			])
			skull.color = Color(0.85, 0.8, 0.7)
			decor.add_child(skull)
			
			var eye1 = Polygon2D.new()
			eye1.polygon = PackedVector2Array([
				Vector2(-3, -3),
				Vector2(-1, -3),
				Vector2(-1, -1),
				Vector2(-3, -1)
			])
			eye1.color = Color(0.1, 0.1, 0.1)
			decor.add_child(eye1)
			
			var eye2 = Polygon2D.new()
			eye2.polygon = PackedVector2Array([
				Vector2(1, -3),
				Vector2(3, -3),
				Vector2(3, -1),
				Vector2(1, -1)
			])
			eye2.color = Color(0.1, 0.1, 0.1)
			decor.add_child(eye2)
		2:
			var rock = Polygon2D.new()
			rock.polygon = PackedVector2Array([
				Vector2(-8, -4),
				Vector2(6, -6),
				Vector2(10, 0),
				Vector2(4, 6),
				Vector2(-6, 4)
			])
			rock.color = Color(0.5, 0.4, 0.35)
			decor.add_child(rock)
		3:
			var rusted_car = Polygon2D.new()
			rusted_car.polygon = PackedVector2Array([
				Vector2(-10, -6),
				Vector2(10, -6),
				Vector2(12, 0),
				Vector2(10, 6),
				Vector2(-10, 6),
				Vector2(-12, 0)
			])
			rusted_car.color = Color(0.6, 0.3, 0.15)
			decor.add_child(rusted_car)
			
			var window = Polygon2D.new()
			window.polygon = PackedVector2Array([
				Vector2(-6, -4),
				Vector2(6, -4),
				Vector2(6, -1),
				Vector2(-6, -1)
			])
			window.color = Color(0.3, 0.3, 0.4)
			decor.add_child(window)
	return decor

func _on_ice_entered(body: Node) -> void:
	ice_entered.emit(body)

func _on_ice_exited(body: Node) -> void:
	ice_exited.emit(body)

func _on_bridge_fall(body: Node) -> void:
	bridge_fall.emit(body)

func _get_tile_variant(chunk_type: ChunkType, row: int, col: int) -> int:
	match chunk_type:
		ChunkType.STANDARD:
			return 0
		ChunkType.DEBRIS:
			return 1 if row % 4 == 0 and col >= LANE_START_COL and col <= LANE_END_COL and (col - LANE_START_COL) % 3 == 0 else 0
		ChunkType.ICE:
			return 2
		ChunkType.CONSTRUCTION:
			return 3 if col == LANE_START_COL - 1 or col == LANE_END_COL + 1 else 0
		ChunkType.BRIDGE:
			return 4
		_:
			return 0

func _get_tiles_node(chunk: Node2D) -> Node2D:
	if chunk.get_child_count() > 0:
		return chunk.get_child(0) as Node2D
	return null
