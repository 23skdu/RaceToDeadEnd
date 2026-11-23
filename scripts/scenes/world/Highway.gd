extends Node2D

const RoadmapWorld = preload("res://scripts/utils/RoadmapWorld.gd")

signal segment_completed(segment: int)
signal ice_entered(body: Node)
signal ice_exited(body: Node)
signal bridge_fall(body: Node)

const CHUNK_HEIGHT: int = 14
const CHUNK_WIDTH: int = 14
const TILE_SIZE: Vector2i = Vector2i(48, 24)
const CHUNK_PIXEL_HEIGHT: int = int(CHUNK_HEIGHT * TILE_SIZE.y)
const PREWARM_CHUNKS: int = 10
const DESPAWN_CHUNKS_BEHIND: int = 4

const LANE_COUNT: int = 4
const SHOULDER_COLUMNS: int = 5
const LANE_START_COL: int = 5
const LANE_END_COL: int = 8
const HALF_CHUNK: float = (CHUNK_WIDTH - 1) / 2.0

# Tile atlas entries (single row, four columns).
const TILE_LANE: int = 0
const TILE_GUARDRAIL: int = 1
const TILE_ICE: int = 2
const TILE_HAZARD: int = 3
const TILE_ATLAS_WIDTH: int = 4

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
var lane_tilemap: TileMapLayer = null
var use_tilemap_highway: bool = true

func setup_lane_tilemap() -> void:
	if not is_instance_valid(lane_tilemap):
		lane_tilemap = get_node_or_null("LaneTileMap")
	if not is_instance_valid(lane_tilemap):
		lane_tilemap = TileMapLayer.new()
		lane_tilemap.name = "LaneTileMap"
		add_child(lane_tilemap)
	# Runtime atlas: lane marking, guardrail, ice patch, hazard overlay.
	var tileset := TileSet.new()
	tileset.tile_size = TILE_SIZE
	var source := TileSetAtlasSource.new()
	var atlas := Image.create(TILE_SIZE.x * TILE_ATLAS_WIDTH, TILE_SIZE.y, false, Image.FORMAT_RGBA8)
	var colors: Array[Color] = [
		Color(1.0, 1.0, 0.8, 0.55),
		Color(0.9, 0.9, 0.6, 0.9),
		Color(0.5, 0.85, 1.0, 0.4),
		Color(1.0, 0.35, 0.1, 0.85),
	]
	for i in TILE_ATLAS_WIDTH:
		atlas.fill_rect(Rect2i(i * TILE_SIZE.x, 0, TILE_SIZE.x, TILE_SIZE.y), colors[i])
	source.texture = ImageTexture.create_from_image(atlas)
	source.texture_region_size = TILE_SIZE
	for i in TILE_ATLAS_WIDTH:
		source.create_tile(Vector2i(i, 0))
	tileset.add_source(source, 0)
	var terrain_set := 0
	tileset.add_terrain_set(terrain_set)
	tileset.set_terrain_set_mode(terrain_set, TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES)
	tileset.add_terrain(terrain_set, 0)
	lane_tilemap.tile_set = tileset
	lane_tilemap.z_index = -1

var _chunk_buffers: Dictionary = {}
var _buffer_in_use: Dictionary = {}
var _tile_cells: Dictionary = {}

## Enable/disable the TileMapLayer highway at runtime and repopulate live chunks.
func set_tilemap_highway_enabled(enabled: bool) -> void:
	use_tilemap_highway = enabled
	if not is_instance_valid(lane_tilemap):
		setup_lane_tilemap()
	if not use_tilemap_highway:
		clear_tilemap()
	for chunk in active_chunks:
		if use_tilemap_highway:
			var chunk_type := int(chunk.get_meta("chunk_type", ChunkType.STANDARD))
			_populate_chunk_tiles(chunk, chunk_type)
		_refresh_chunk_visibility(chunk)

## Remove every cell owned by the highway tilemap.
func clear_tilemap() -> void:
	if not is_instance_valid(lane_tilemap):
		return
	for coords in _tile_cells.keys():
		lane_tilemap.erase_cell(coords)
	_tile_cells.clear()

func _clear_chunk_tilemap(chunk: Node2D) -> void:
	var cells: Array = chunk.get_meta("tilemap_cells", [])
	for coords in cells:
		if is_instance_valid(lane_tilemap):
			lane_tilemap.erase_cell(coords)
		_tile_cells.erase(coords)
	chunk.set_meta("tilemap_cells", [])

func _place_tile(x_pos: float, y_cell: int, tile_index: int, cells: Array[Vector2i]) -> void:
	if not is_instance_valid(lane_tilemap):
		return
	var x_cell := int(floor((x_pos + 640.0) / float(TILE_SIZE.x)))
	var coords := Vector2i(x_cell, y_cell)
	lane_tilemap.set_cell(coords, 0, Vector2i(tile_index, 0), 0)
	_tile_cells[coords] = tile_index
	cells.append(coords)

func _populate_chunk_tiles(chunk: Node2D, chunk_type: int) -> void:
	if not use_tilemap_highway or not is_instance_valid(lane_tilemap):
		return
	_clear_chunk_tilemap(chunk)
	var cells: Array[Vector2i] = []
	var origin_y := int(round(chunk.position.y))
	for row in CHUNK_HEIGHT:
		var y_cell := int((origin_y + row * TILE_SIZE.y) / TILE_SIZE.y)
		# Lane separator markings.
		for boundary in range(1, LANE_COUNT):
			_place_tile(-240.0 + float(boundary) * 120.0, y_cell, TILE_LANE, cells)
		# Guardrails on both shoulders.
		_place_tile(-240.0, y_cell, TILE_GUARDRAIL, cells)
		_place_tile(240.0, y_cell, TILE_GUARDRAIL, cells)
		if chunk_type == ChunkType.ICE:
			for lane in LANE_COUNT:
				_place_tile(Constants.LANE_POSITIONS[lane], y_cell, TILE_ICE, cells)
		elif chunk_type == ChunkType.DEBRIS and row % 4 == 0:
			_place_tile(Constants.LANE_POSITIONS[3], y_cell, TILE_HAZARD, cells)
		elif chunk_type == ChunkType.CONSTRUCTION and row % 2 == 0:
			_place_tile(-520.0, y_cell, TILE_HAZARD, cells)
			_place_tile(520.0, y_cell, TILE_HAZARD, cells)
	chunk.set_meta("tilemap_cells", cells)

func _refresh_chunk_visibility(chunk: Node2D) -> void:
	var tiles := _get_tiles_node(chunk)
	if not is_instance_valid(tiles):
		return
	for child in tiles.get_children():
		if child is Line2D and (child.name == "LeftRail" or child.name == "RightRail"):
			child.visible = not use_tilemap_highway
		elif child is MultiMeshInstance2D and (
			child.name == "LaneMultiMesh" or child.name == "EdgeMarking" or child.name == "StripeMarking"
		):
			child.visible = not use_tilemap_highway

func _attach_occluder(parent: Node2D, kind: String, size: Vector2, pos: Vector2, node_name: String) -> void:
	if not SettingsManager or not SettingsManager.is_feature_enabled(RoadmapWorld.FEATURE_LIGHTING, true):
		return
	var occluder := RoadmapWorld.make_light_occluder(kind, size)
	occluder.name = node_name
	occluder.position = pos
	parent.add_child(occluder)


static var _diamond_mesh_cache: ArrayMesh = null
static var _diamond_mesh_lane_cache: ArrayMesh = null
static var _diamond_mesh_shoulder_cache: ArrayMesh = null
static var _bridge_structure_mesh_cache: ArrayMesh = null
static var _rect_mesh_cache: Dictionary = {}
static var _decor_mesh_cache: Dictionary = {}
static var _obstacle_mesh_cache: Dictionary = {}

var _theme_colors: Dictionary = {
	"lane_color": Color(0.18, 0.18, 0.22),
	"shoulder_color": Color(0.76, 0.64, 0.42),
	"stripe_color": Color(1.0, 1.0, 0.8),
	"guardrail_color": Constants.GUARDRAIL_COLOR,
}
var _theme_lane_texture: Texture2D = null

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	white_texture = ImageTexture.create_from_image(img)
	lane_tilemap = get_node_or_null("LaneTileMap")
	if SettingsManager:
		use_tilemap_highway = SettingsManager.is_feature_enabled(RoadmapWorld.FEATURE_TILEMAP_HIGHWAY, true)
	setup_lane_tilemap()

	if PackManager:
		if PackManager.has_method("get_custom_theme_color"):
			for key in _theme_colors.keys():
				var col = PackManager.get_custom_theme_color(key)
				if col != null:
					_theme_colors[key] = col
		if PackManager.has_method("get_custom_theme_texture"):
			_theme_lane_texture = PackManager.get_custom_theme_texture("highway_lane")
		if PackManager.has_signal("theme_color_loaded") and not PackManager.theme_color_loaded.is_connected(_on_theme_color_loaded):
			PackManager.theme_color_loaded.connect(_on_theme_color_loaded)
		if PackManager.has_signal("theme_texture_loaded") and not PackManager.theme_texture_loaded.is_connected(_on_theme_texture_loaded):
			PackManager.theme_texture_loaded.connect(_on_theme_texture_loaded)

	if GameManager and GameManager.get("daily_run_active"):
		_rng.seed = int(GameManager.get("daily_seed"))
	else:
		_rng.seed = hash("highway_seed")

	for i in range(-3, PREWARM_CHUNKS - 3):
		_spawn_chunk(i)

func _on_theme_color_loaded(key: String, color: Color) -> void:
	_theme_colors[key] = color
	_rebuild_active_chunks()

func _on_theme_texture_loaded(key: String, tex: Texture2D) -> void:
	if key == "highway_lane":
		_theme_lane_texture = tex
		_rebuild_active_chunks()

func _rebuild_active_chunks() -> void:
	for chunk in active_chunks:
		if is_instance_valid(chunk):
			var old_tiles = _get_tiles_node(chunk)
			if old_tiles:
				chunk.remove_child(old_tiles)
				old_tiles.queue_free()
	for chunk_type in _chunk_buffers:
		for tiles in _chunk_buffers[chunk_type]:
			if is_instance_valid(tiles) and tiles.get_parent() == null:
				tiles.queue_free()
	_chunk_buffers.clear()
	_buffer_in_use.clear()
	clear_tilemap()
	for chunk in active_chunks:
		if is_instance_valid(chunk):
			var chunk_type: ChunkType = chunk.get_meta("chunk_type", ChunkType.STANDARD)
			chunk.add_child(_reserve_tiles(chunk_type))
			_populate_chunk_tiles(chunk, int(chunk_type))
			_refresh_chunk_visibility(chunk)

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
	_populate_chunk_tiles(chunk, int(chunk_type))
	_refresh_chunk_visibility(chunk)
	current_segment += 1

func _recycle_chunk(chunk: Node2D) -> void:
	var lowest_y = INF
	for c in active_chunks:
		if c.position.y < lowest_y:
			lowest_y = c.position.y
	_clear_chunk_tilemap(chunk)
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
	_populate_chunk_tiles(chunk, int(new_type))
	_refresh_chunk_visibility(chunk)

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
	for child in tiles_node.get_children():
		if child is StaticBody2D and (child.is_in_group("obstacles") or child.is_in_group("deadly_obstacles")):
			child.visible = true
			child.collision_layer = 1
			child.collision_mask = 1
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
			bg_color = _theme_colors.get("shoulder_color", Color(0.76, 0.64, 0.42))
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
				var sh_col_w = 400.0 / 5.0
				x_pos = -640.0 + col * sh_col_w + sh_col_w / 2.0
				if row % 2 == 1:
					x_pos += sh_col_w / 2.0
					if x_pos >= -240.0:
						x_pos -= 400.0
			elif col > LANE_END_COL:
				var sh_col_w = 400.0 / 5.0
				var right_col_idx = col - (LANE_END_COL + 1)
				x_pos = 240.0 + right_col_idx * sh_col_w + sh_col_w / 2.0
				if row % 2 == 1:
					x_pos += sh_col_w / 2.0
					if x_pos >= 640.0:
						x_pos -= 400.0
			else:
				var lane_idx = col - LANE_START_COL
				var lane_w = 120.0
				x_pos = -240.0 + lane_idx * lane_w + lane_w / 2.0
				if row % 2 == 1:
					x_pos += lane_w / 2.0
					if x_pos >= 240.0:
						x_pos -= 480.0

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
					var tile_color: Color = _theme_colors.get("shoulder_color", Color(0.76, 0.64, 0.42))
					shoulder_polygons.append({"pos": Vector2(x_pos, y_pos), "color": tile_color})

					if _rng.randf() < 0.12:
						var decor_type = _pick_side_decoration_type()
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
					var tile_color: Color = _theme_colors.get("lane_color", Color(0.18, 0.18, 0.22))
					lane_polygons.append({"pos": Vector2(x_pos, y_pos), "color": tile_color})

					if col > LANE_START_COL and col <= LANE_END_COL and (col - LANE_START_COL) % 2 == 0:
						if row % 2 == 0:
							var stripe_x = -240.0 + (col - LANE_START_COL) * 120.0
							stripe_positions.append({"pos": Vector2(stripe_x, y_pos)})

			if tile_variant == 1 or tile_variant == 3:
				obstacle_positions.append({
					"pos": Vector2(x_pos, y_pos),
					"type": "barrel" if tile_variant == 3 else "rock",
					"color": Color(1.0, 0.35, 0.15) if tile_variant == 1 else Color(1.0, 0.75, 0.0)
				})

	if lane_polygons.size() > 0:
		var lane_merged = MultiMeshInstance2D.new()
		lane_merged.name = "LaneMultiMesh"
		lane_merged.texture = _theme_lane_texture if _theme_lane_texture else white_texture
		var multimesh = MultiMesh.new()
		multimesh.mesh = _create_diamond_mesh_lane()
		multimesh.use_colors = true
		multimesh.instance_count = lane_polygons.size()
		for i in lane_polygons.size():
			multimesh.set_instance_transform_2d(i, Transform2D(0.0, lane_polygons[i]["pos"]))
			multimesh.set_instance_color(i, lane_polygons[i]["color"])
		lane_merged.multimesh = multimesh
		lane_merged.modulate = Color.WHITE
		chunk_local.add_child(lane_merged)

		var edge_marking_color = Color(0.9, 0.9, 0.5, 0.6)
		var edge_marking = MultiMeshInstance2D.new()
		edge_marking.name = "EdgeMarking"
		edge_marking.texture = white_texture
		var emesh = MultiMesh.new()
		emesh.mesh = _create_rect_mesh(Vector2(2, half_h * 0.9))
		var edge_positions: Array[Vector2] = []
		for row in CHUNK_HEIGHT:
			var y_pos = row * TILE_SIZE.y + half_h
			edge_positions.append(Vector2(-240.0, y_pos))
			edge_positions.append(Vector2(240.0, y_pos))
		emesh.instance_count = edge_positions.size()
		for i in edge_positions.size():
			emesh.set_instance_transform_2d(i, Transform2D(0.0, edge_positions[i]))
		edge_marking.multimesh = emesh
		edge_marking.modulate = edge_marking_color
		chunk_local.add_child(edge_marking)

	if shoulder_polygons.size() > 0:
		var shoulder_merged = MultiMeshInstance2D.new()
		shoulder_merged.name = "ShoulderMultiMesh"
		shoulder_merged.texture = white_texture
		var multimesh = MultiMesh.new()
		multimesh.mesh = _create_diamond_mesh_shoulder()
		multimesh.use_colors = true
		multimesh.instance_count = shoulder_polygons.size()
		for i in shoulder_polygons.size():
			multimesh.set_instance_transform_2d(i, Transform2D(0.0, shoulder_polygons[i]["pos"]))
			multimesh.set_instance_color(i, shoulder_polygons[i]["color"])
		shoulder_merged.multimesh = multimesh
		shoulder_merged.modulate = Color.WHITE
		chunk_local.add_child(shoulder_merged)

	if stripe_positions.size() > 0:
		var stripe_mmi = MultiMeshInstance2D.new()
		stripe_mmi.name = "StripeMarking"
		stripe_mmi.texture = white_texture
		var smesh = MultiMesh.new()
		smesh.mesh = _create_rect_mesh(Vector2(4, half_h * 1.2))
		smesh.instance_count = stripe_positions.size()
		for i in stripe_positions.size():
			smesh.set_instance_transform_2d(i, Transform2D(0.0, stripe_positions[i]["pos"]))
		stripe_mmi.multimesh = smesh
		stripe_mmi.modulate = _theme_colors.get("stripe_color", Color(1.0, 1.0, 0.8))
		chunk_local.add_child(stripe_mmi)

	var decor_positions: Dictionary = {}
	var crash_obstacle_positions: Array[Vector2] = []
	for decor in desert_decorations:
		var type = decor["type"]
		if not decor_positions.has(type):
			decor_positions[type] = []
		decor_positions[type].append(decor["pos"])
		if type == 2 or type == 3:
			crash_obstacle_positions.append(decor["pos"])

	for type in decor_positions:
		var positions = decor_positions[type]
		var mmi = MultiMeshInstance2D.new()
		mmi.texture = white_texture
		var mm = MultiMesh.new()
		mm.mesh = _get_decor_mesh(type)
		mm.instance_count = positions.size()
		for i in positions.size():
			mm.set_instance_transform_2d(i, Transform2D(0.0, positions[i]))
		mmi.multimesh = mm
		chunk_local.add_child(mmi)

	for pos in crash_obstacle_positions:
		var crash_obstacle = StaticBody2D.new()
		crash_obstacle.collision_layer = 1
		crash_obstacle.collision_mask = 1
		crash_obstacle.position = pos
		crash_obstacle.add_to_group("deadly_obstacles")

		var col_shape = CollisionShape2D.new()
		var rect_shape = RectangleShape2D.new()
		rect_shape.size = Vector2(20, 20)
		col_shape.shape = rect_shape
		crash_obstacle.add_child(col_shape)
		_attach_occluder(crash_obstacle, "obstacle", Vector2(20, 20), Vector2.ZERO, "CrashOccluder")
		chunk_local.add_child(crash_obstacle)

	var obs_positions: Dictionary = {}
	for obs in obstacle_positions:
		var type = obs["type"]
		if not obs_positions.has(type):
			obs_positions[type] = []
		obs_positions[type].append(obs["pos"])

	for type in obs_positions:
		var positions = obs_positions[type]
		var mmi = MultiMeshInstance2D.new()
		mmi.texture = white_texture
		var mm = MultiMesh.new()
		mm.mesh = _get_obstacle_mesh(type)
		mm.instance_count = positions.size()
		for i in positions.size():
			mm.set_instance_transform_2d(i, Transform2D(0.0, positions[i]))
		mmi.multimesh = mm
		chunk_local.add_child(mmi)

		for pos in positions:
			var obstacle = StaticBody2D.new()
			obstacle.collision_layer = 1
			obstacle.collision_mask = 1
			obstacle.position = pos
			obstacle.add_to_group("obstacles")

			var col_shape = CollisionShape2D.new()
			var circle = CircleShape2D.new()
			circle.radius = 12.0
			col_shape.shape = circle
			obstacle.add_child(col_shape)
			_attach_occluder(obstacle, "circle" if type == "barrel" else "obstacle", Vector2(24, 24), Vector2.ZERO, "ObstacleOccluder")
			chunk_local.add_child(obstacle)

	if lane_polygons.size() > 0 and chunk_type != ChunkType.ICE and chunk_type != ChunkType.BRIDGE:
		var crack_positions: Array[Vector2] = []
		for row in CHUNK_HEIGHT:
			for col in range(LANE_START_COL + 1, LANE_END_COL):
				var lane_cx = -240.0 + (col - LANE_START_COL) * 120.0 + 60.0
				var y_pos = row * TILE_SIZE.y + half_h * 0.5
				if _rng.randf() < 0.12:
					var x_offset = _rng.randf_range(-120.0 * 0.35, 120.0 * 0.35)
					crack_positions.append(Vector2(lane_cx + x_offset, y_pos))
		if crack_positions.size() > 0:
			var crack_mmi = MultiMeshInstance2D.new()
			crack_mmi.texture = white_texture
			var cmesh = MultiMesh.new()
			cmesh.mesh = _create_rect_mesh(Vector2(1, half_h * 0.3))
			cmesh.instance_count = crack_positions.size()
			for i in crack_positions.size():
				cmesh.set_instance_transform_2d(i, Transform2D(0.0, crack_positions[i]))
			crack_mmi.multimesh = cmesh
			crack_mmi.modulate = Color(0.0, 0.0, 0.0, 0.15)
			chunk_local.add_child(crack_mmi)

	var left_rail_x = -240.0
	var right_rail_x = 240.0

	var rail_color: Color = _theme_colors.get("guardrail_color", Constants.GUARDRAIL_COLOR) if chunk_type != ChunkType.BRIDGE else Constants.BRIDGE_GUARDRAIL_COLOR
	var left_rail = Line2D.new()
	left_rail.name = "LeftRail"
	left_rail.width = Constants.GUARDRAIL_WIDTH
	left_rail.default_color = rail_color
	var left_points = PackedVector2Array()
	for row in CHUNK_HEIGHT + 1:
		var y_pos = row * TILE_SIZE.y
		left_points.append(Vector2(left_rail_x, y_pos))
	left_rail.points = left_points
	chunk_local.add_child(left_rail)

	var right_rail = Line2D.new()
	right_rail.name = "RightRail"
	right_rail.width = Constants.GUARDRAIL_WIDTH
	right_rail.default_color = rail_color
	var right_points = PackedVector2Array()
	for row in CHUNK_HEIGHT + 1:
		var y_pos = row * TILE_SIZE.y
		right_points.append(Vector2(right_rail_x, y_pos))
	right_rail.points = right_points
	chunk_local.add_child(right_rail)

	_attach_occluder(chunk_local, "guardrail", Vector2(Constants.GUARDRAIL_WIDTH * 2.0, CHUNK_PIXEL_HEIGHT), Vector2(left_rail_x, CHUNK_PIXEL_HEIGHT * 0.5), "LeftRailOccluder")
	_attach_occluder(chunk_local, "guardrail", Vector2(Constants.GUARDRAIL_WIDTH * 2.0, CHUNK_PIXEL_HEIGHT), Vector2(right_rail_x, CHUNK_PIXEL_HEIGHT * 0.5), "RightRailOccluder")

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
		var bridge_mesh_inst = MeshInstance2D.new()
		bridge_mesh_inst.name = "BridgeStructureMesh"
		bridge_mesh_inst.mesh = _get_bridge_structure_mesh()
		chunk_local.add_child(bridge_mesh_inst)

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

func _pick_side_decoration_type() -> int:
	var boss_level := 0
	if GameManager != null and GameManager.has_method("get"):
		boss_level = int(GameManager.get("bosses_killed"))
	var palette := _side_decoration_palette(boss_level)
	return palette[_rng.randi() % palette.size()]

func _side_decoration_palette(boss_level: int) -> Array[int]:
	match boss_level:
		0:
			return [0, 4, 6]
		1:
			return [1, 4, 5, 6]
		2:
			return [2, 3, 7, 6]
		3:
			return [3, 7, 2, 5]
		_:
			return [4, 5, 6, 7]

func get_side_decoration_palette(boss_level: int) -> Array[int]:
	return _side_decoration_palette(boss_level)

func _create_side_decoration(type: int) -> Node2D:
	return _create_desert_decoration(type)

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
		4:
			var bush = Polygon2D.new()
			bush.polygon = PackedVector2Array([
				Vector2(-7, 2), Vector2(-4, -6), Vector2(0, -8),
				Vector2(4, -6), Vector2(7, 2), Vector2(4, 6), Vector2(-4, 6)
			])
			bush.color = Color(0.18, 0.45, 0.18)
			decor.add_child(bush)
		5:
			var tree_trunk = Polygon2D.new()
			tree_trunk.polygon = PackedVector2Array([Vector2(-2, -2), Vector2(2, -2), Vector2(2, 8), Vector2(-2, 8)])
			tree_trunk.color = Color(0.35, 0.22, 0.12)
			decor.add_child(tree_trunk)
			var tree_top = Polygon2D.new()
			tree_top.polygon = PackedVector2Array([Vector2(0, -14), Vector2(8, -4), Vector2(4, 4), Vector2(-4, 4), Vector2(-8, -4)])
			tree_top.color = Color(0.12, 0.38, 0.12)
			decor.add_child(tree_top)
		6:
			var animal = Polygon2D.new()
			animal.polygon = PackedVector2Array([Vector2(-6, 0), Vector2(-2, -4), Vector2(4, -3), Vector2(6, 1), Vector2(3, 5), Vector2(-4, 4)])
			animal.color = Color(0.55, 0.4, 0.3)
			decor.add_child(animal)
			var eye = Polygon2D.new()
			eye.polygon = PackedVector2Array([Vector2(3, -2), Vector2(5, -2), Vector2(5, 0), Vector2(3, 0)])
			eye.color = Color(0.95, 0.2, 0.2)
			decor.add_child(eye)
		7:
			var barrel = Polygon2D.new()
			barrel.polygon = PackedVector2Array([Vector2(-5, -8), Vector2(5, -8), Vector2(6, 8), Vector2(-6, 8)])
			barrel.color = Color(0.9, 0.45, 0.1)
			decor.add_child(barrel)
			var stripe = Polygon2D.new()
			stripe.polygon = PackedVector2Array([Vector2(-5.2, -2), Vector2(5.2, -2), Vector2(5.4, 2), Vector2(-5.4, 2)])
			stripe.color = Color(0.95, 0.95, 0.98)
			decor.add_child(stripe)
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
			return 3 if row % 4 == 0 and col >= LANE_START_COL and col <= LANE_END_COL and (col - LANE_START_COL) % 3 == 0 else 0
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

static func _node_to_mesh(node: Node2D) -> ArrayMesh:
	var vertices = PackedVector2Array()
	var colors = PackedColorArray()
	var indices = PackedInt32Array()
	_gather_polygons(node, Transform2D(), vertices, colors, indices)

	var mesh = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

static func _gather_polygons(node: Node, parent_xform: Transform2D, vertices: PackedVector2Array, colors: PackedColorArray, indices: PackedInt32Array) -> void:
	var local_xform = parent_xform
	if node is Node2D:
		local_xform = parent_xform * node.transform

	if node is Polygon2D:
		var start_idx = vertices.size()
		var poly = node.polygon
		var col = node.color
		for vertex in poly:
			vertices.append(local_xform * vertex)
			colors.append(col)
		var poly_indices = Geometry2D.triangulate_polygon(poly)
		for idx in poly_indices:
			indices.append(start_idx + idx)
	elif node is Line2D:
		var width = node.width
		var half_w = width / 2.0
		var col = node.default_color
		var pts = node.points
		for j in range(pts.size() - 1):
			var p1 = pts[j]
			var p2 = pts[j+1]
			var dir = (p2 - p1).normalized()
			var normal = Vector2(-dir.y, dir.x)

			var v1 = p1 - normal * half_w
			var v2 = p1 + normal * half_w
			var v3 = p2 + normal * half_w
			var v4 = p2 - normal * half_w

			var start_idx = vertices.size()
			vertices.append(local_xform * v1)
			vertices.append(local_xform * v2)
			vertices.append(local_xform * v3)
			vertices.append(local_xform * v4)

			for k in 4:
				colors.append(col)

			indices.append(start_idx + 0)
			indices.append(start_idx + 1)
			indices.append(start_idx + 2)
			indices.append(start_idx + 0)
			indices.append(start_idx + 2)
			indices.append(start_idx + 3)

	for child in node.get_children():
		_gather_polygons(child, local_xform, vertices, colors, indices)

func _get_decor_mesh(type: int) -> ArrayMesh:
	if _decor_mesh_cache.has(type):
		return _decor_mesh_cache[type]
	var temp_node = _create_desert_decoration(type)
	var mesh = _node_to_mesh(temp_node)
	temp_node.free()
	_decor_mesh_cache[type] = mesh
	return mesh

func _get_obstacle_mesh(type: String) -> ArrayMesh:
	if _obstacle_mesh_cache.has(type):
		return _obstacle_mesh_cache[type]

	var temp_obs = Node2D.new()
	if type == "barrel":
		var base = Polygon2D.new()
		base.polygon = PackedVector2Array([
			Vector2(-12, 11), Vector2(12, 11),
			Vector2(10, 14), Vector2(-10, 14)
		])
		base.color = Color(0.12, 0.12, 0.14)
		temp_obs.add_child(base)

		var body = Polygon2D.new()
		body.polygon = PackedVector2Array([
			Vector2(-10, -14), Vector2(10, -14),
			Vector2(11, 11), Vector2(-11, 11)
		])
		body.color = Color(1.0, 0.4, 0.0)
		temp_obs.add_child(body)

		var stripe1 = Polygon2D.new()
		stripe1.polygon = PackedVector2Array([
			Vector2(-10.2, -6), Vector2(10.2, -6),
			Vector2(10.5, -1), Vector2(-10.5, -1)
		])
		stripe1.color = Color(0.95, 0.95, 0.98)
		temp_obs.add_child(stripe1)

		var stripe2 = Polygon2D.new()
		stripe2.polygon = PackedVector2Array([
			Vector2(-10.6, 3), Vector2(10.6, 3),
			Vector2(10.9, 8), Vector2(-10.9, 8)
		])
		stripe2.color = Color(0.95, 0.95, 0.98)
		temp_obs.add_child(stripe2)

		var ridge = Line2D.new()
		ridge.width = 1.5
		ridge.default_color = Color(0.6, 0.25, 0.0)
		ridge.points = PackedVector2Array([Vector2(-10.4, 1), Vector2(10.4, 1)])
		temp_obs.add_child(ridge)

		var light_base = Polygon2D.new()
		light_base.polygon = PackedVector2Array([
			Vector2(-4, -14), Vector2(4, -14),
			Vector2(3, -19), Vector2(-3, -19)
		])
		light_base.color = Color(0.2, 0.2, 0.2)
		temp_obs.add_child(light_base)

		var bulb = Polygon2D.new()
		bulb.polygon = PackedVector2Array([
			Vector2(-2, -19), Vector2(2, -19),
			Vector2(3, -24), Vector2(0, -26), Vector2(-3, -24)
		])
		bulb.color = Color(1.0, 0.0, 0.1)
		temp_obs.add_child(bulb)

		var glow = Polygon2D.new()
		glow.polygon = PackedVector2Array([
			Vector2(0, -28), Vector2(6, -24), Vector2(0, -20), Vector2(-6, -24)
		])
		glow.color = Color(1.0, 0.2, 0.2, 0.5)
		temp_obs.add_child(glow)
	else:
		var rock_poly = Polygon2D.new()
		rock_poly.polygon = PackedVector2Array([
			Vector2(-14, 8), Vector2(-15, -2), Vector2(-8, -12),
			Vector2(4, -14), Vector2(13, -6), Vector2(15, 8),
			Vector2(5, 13), Vector2(-6, 13)
		])
		rock_poly.color = Color(0.48, 0.48, 0.5)
		temp_obs.add_child(rock_poly)

		var rock_shadow = Polygon2D.new()
		rock_shadow.polygon = PackedVector2Array([
			Vector2(0, -13), Vector2(4, -14), Vector2(13, -6),
			Vector2(15, 8), Vector2(5, 13), Vector2(-3, 6)
		])
		rock_shadow.color = Color(0.35, 0.35, 0.38)
		temp_obs.add_child(rock_shadow)

		var rock_lite = Polygon2D.new()
		rock_lite.polygon = PackedVector2Array([
			Vector2(-14, 8), Vector2(-15, -2), Vector2(-8, -12),
			Vector2(0, -13), Vector2(-5, 0)
		])
		rock_lite.color = Color(0.62, 0.62, 0.65)
		temp_obs.add_child(rock_lite)

		var crack = Line2D.new()
		crack.width = 1.5
		crack.default_color = Color(0.2, 0.2, 0.22)
		crack.points = PackedVector2Array([Vector2(-4, -12), Vector2(-2, -3), Vector2(3, 4)])
		temp_obs.add_child(crack)

		var crack2 = Line2D.new()
		crack2.width = 1.0
		crack2.default_color = Color(0.2, 0.2, 0.22)
		crack2.points = PackedVector2Array([Vector2(-2, -3), Vector2(-10, 2)])
		temp_obs.add_child(crack2)

	var mesh = _node_to_mesh(temp_obs)
	temp_obs.free()
	_obstacle_mesh_cache[type] = mesh
	return mesh

static func _get_bridge_structure_mesh() -> ArrayMesh:
	if _bridge_structure_mesh_cache:
		return _bridge_structure_mesh_cache
	var temp := Node2D.new()
	var left_rail_x: float = -240.0
	var right_rail_x: float = 240.0
	for row in range(0, CHUNK_HEIGHT + 1, 2):
		var joint_y = row * TILE_SIZE.y
		var joint = Line2D.new()
		joint.width = 1.5
		joint.default_color = Color(0.05, 0.05, 0.07, 0.5)
		joint.points = PackedVector2Array([Vector2(-480, joint_y), Vector2(480, joint_y)])
		temp.add_child(joint)
	var truss_color = Color(0.25, 0.28, 0.35, 1.0)
	var truss_dark = Color(0.12, 0.14, 0.18, 1.0)
	for row in range(0, CHUNK_HEIGHT):
		var y1 = row * TILE_SIZE.y
		var y2 = (row + 1) * TILE_SIZE.y
		var lx1 = left_rail_x - 30
		var lx2 = left_rail_x - 5
		var lt1 = Line2D.new()
		lt1.width = 2.5
		lt1.default_color = truss_color
		lt1.points = PackedVector2Array([Vector2(lx1, y1), Vector2(lx2, y2)])
		temp.add_child(lt1)
		var lt2 = Line2D.new()
		lt2.width = 2.5
		lt2.default_color = truss_color
		lt2.points = PackedVector2Array([Vector2(lx2, y1), Vector2(lx1, y2)])
		temp.add_child(lt2)
		var rx1 = right_rail_x + 5
		var rx2 = right_rail_x + 30
		var rt1 = Line2D.new()
		rt1.width = 2.5
		rt1.default_color = truss_color
		rt1.points = PackedVector2Array([Vector2(rx1, y1), Vector2(rx2, y2)])
		temp.add_child(rt1)
		var rt2 = Line2D.new()
		rt2.width = 2.5
		rt2.default_color = truss_color
		rt2.points = PackedVector2Array([Vector2(rx2, y1), Vector2(rx1, y2)])
		temp.add_child(rt2)
		if row == 0:
			var left_edge = Line2D.new()
			left_edge.width = 4.0
			left_edge.default_color = truss_dark
			left_edge.points = PackedVector2Array([Vector2(lx1, 0), Vector2(lx1, CHUNK_PIXEL_HEIGHT)])
			temp.add_child(left_edge)
			var right_edge = Line2D.new()
			right_edge.width = 4.0
			right_edge.default_color = truss_dark
			right_edge.points = PackedVector2Array([Vector2(rx2, 0), Vector2(rx2, CHUNK_PIXEL_HEIGHT)])
			temp.add_child(right_edge)
	for py in [0.0, CHUNK_PIXEL_HEIGHT]:
		var lp = Polygon2D.new()
		lp.polygon = PackedVector2Array([
			Vector2(left_rail_x - 35, py - 6), Vector2(left_rail_x - 2, py - 6),
			Vector2(left_rail_x - 2, py + 6), Vector2(left_rail_x - 35, py + 6)
		])
		lp.color = Color(0.35, 0.35, 0.38)
		temp.add_child(lp)
		var rp = Polygon2D.new()
		rp.polygon = PackedVector2Array([
			Vector2(right_rail_x + 2, py - 6), Vector2(right_rail_x + 35, py - 6),
			Vector2(right_rail_x + 35, py + 6), Vector2(right_rail_x + 2, py + 6)
		])
		rp.color = Color(0.35, 0.35, 0.38)
		temp.add_child(rp)
	var left_cable = Line2D.new()
	left_cable.width = 1.0
	left_cable.default_color = Color(0.75, 0.85, 0.95, 0.7)
	left_cable.points = PackedVector2Array([Vector2(left_rail_x - 4, 0), Vector2(left_rail_x - 4, CHUNK_PIXEL_HEIGHT)])
	temp.add_child(left_cable)
	var right_cable = Line2D.new()
	right_cable.width = 1.0
	right_cable.default_color = Color(0.75, 0.85, 0.95, 0.7)
	right_cable.points = PackedVector2Array([Vector2(right_rail_x + 4, 0), Vector2(right_rail_x + 4, CHUNK_PIXEL_HEIGHT)])
	temp.add_child(right_cable)
	for beam_row in range(0, CHUNK_HEIGHT + 1, 3):
		var beam_y = beam_row * TILE_SIZE.y
		var beam = Line2D.new()
		beam.width = 5.0
		beam.default_color = Color(0.08, 0.08, 0.12)
		beam.points = PackedVector2Array([Vector2(left_rail_x - 12, beam_y), Vector2(right_rail_x + 12, beam_y)])
		temp.add_child(beam)
		var beam_highlight = Line2D.new()
		beam_highlight.width = 1.5
		beam_highlight.default_color = Color(0.2, 0.22, 0.28)
		beam_highlight.points = PackedVector2Array([Vector2(left_rail_x - 12, beam_y + 1), Vector2(right_rail_x + 12, beam_y + 1)])
		temp.add_child(beam_highlight)
	var mesh = _node_to_mesh(temp)
	temp.free()
	_bridge_structure_mesh_cache = mesh
	return mesh

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		clear_tilemap()
		for chunk_type in _chunk_buffers:
			for tiles in _chunk_buffers[chunk_type]:
				if is_instance_valid(tiles) and tiles.get_parent() == null:
					tiles.free()
		_chunk_buffers.clear()
		_buffer_in_use.clear()
