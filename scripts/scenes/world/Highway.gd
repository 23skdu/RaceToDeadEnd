extends Node2D

signal segment_completed(segment: int)
signal ice_entered(body: Node)
signal ice_exited(body: Node)
signal bridge_fall(body: Node)

const CHUNK_HEIGHT: int = 10
const CHUNK_WIDTH: int = 10
const TILE_SIZE: Vector2i = Vector2i(48, 24)
const CHUNK_PIXEL_HEIGHT: int = 240
const PREWARM_CHUNKS: int = 5
const DESPAWN_CHUNKS_BEHIND: int = 1

const LANE_COUNT: int = 6
const SHOULDER_COLUMNS: int = 2
const LANE_START_COL: int = 2
const LANE_END_COL: int = 7

enum ChunkType { STANDARD, DEBRIS, ICE, CONSTRUCTION, BRIDGE }

var chunk_weights: Dictionary = {
	ChunkType.STANDARD: 40,
	ChunkType.DEBRIS: 20,
	ChunkType.ICE: 10,
	ChunkType.CONSTRUCTION: 15,
	ChunkType.BRIDGE: 15,
}

var active_chunks: Array[Node2D] = []
var current_segment: int = 0
var player: Node = null
var white_texture: Texture2D

func _ready() -> void:
	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	white_texture = ImageTexture.create_from_image(img)
	
	for i in PREWARM_CHUNKS:
		_spawn_chunk(i)

func _process(_delta: float) -> void:
	if not player:
		return
	var player_y = player.global_position.y
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
	_generate_chunk_tiles(chunk, chunk_type)
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
	_clear_chunk_tiles(chunk)
	_generate_chunk_tiles(chunk, new_type)
	current_segment += 1
	segment_completed.emit(current_segment)

func _pick_chunk_type() -> ChunkType:
	var tier = GameManager.difficulty_tier
	var adjusted_weights = chunk_weights.duplicate()
	var hazard_increase = mini(tier - 1, 10) * 2
	adjusted_weights[ChunkType.STANDARD] = maxi(40 - hazard_increase * 2, 15)
	adjusted_weights[ChunkType.DEBRIS] = mini(20 + hazard_increase, 35)
	adjusted_weights[ChunkType.ICE] = mini(10 + hazard_increase, 25)
	adjusted_weights[ChunkType.CONSTRUCTION] = mini(15 + hazard_increase, 30)
	adjusted_weights[ChunkType.BRIDGE] = mini(15 + hazard_increase, 30)
	
	var total = 0
	for w in adjusted_weights.values():
		total += w
	var roll = randi() % total
	var cumulative = 0
	for type in adjusted_weights:
		cumulative += adjusted_weights[type]
		if roll < cumulative:
			return type
	return ChunkType.STANDARD

func _generate_chunk_tiles(chunk: Node2D, chunk_type: ChunkType) -> void:
	var chunk_local = Node2D.new()
	chunk_local.name = "Tiles"
	
	var half_w = TILE_SIZE.x / 2.0
	var half_h = TILE_SIZE.y / 2.0
	
	var lane_polygons = []
	var shoulder_polygons = []
	var stripe_positions = []
	var desert_decorations = []
	var obstacle_positions = []
	
	for row in CHUNK_HEIGHT:
		for col in CHUNK_WIDTH:
			var tile_variant = _get_tile_variant(chunk_type, row, col)
			
			var x_pos = (col - 4.5) * TILE_SIZE.x
			if row % 2 == 1:
				x_pos += half_w
			var y_pos = row * TILE_SIZE.y
			
			if col < LANE_START_COL or col > LANE_END_COL:
				if chunk_type == ChunkType.BRIDGE:
					var tile_color = Color(0.02, 0.02, 0.06)
					shoulder_polygons.append({"pos": Vector2(x_pos, y_pos), "color": tile_color})
				elif chunk_type == ChunkType.CONSTRUCTION:
					var tile_color = Color(0.7, 0.5, 0.0)
					shoulder_polygons.append({"pos": Vector2(x_pos, y_pos), "color": tile_color})
				else:
					var tile_color = Color(0.76, 0.64, 0.42)
					shoulder_polygons.append({"pos": Vector2(x_pos, y_pos), "color": tile_color})
					
					if col == 0 or col == CHUNK_WIDTH - 1:
						if randf() < 0.08:
							var decor_type = randi() % 4
							desert_decorations.append({"pos": Vector2(x_pos, y_pos), "type": decor_type})
			else:
				if chunk_type == ChunkType.ICE:
					var tile_color = Color(0.2, 0.6, 0.9, 0.6)
					lane_polygons.append({"pos": Vector2(x_pos, y_pos), "color": tile_color})
				else:
					var tile_color = Color(0.18, 0.18, 0.22)
					lane_polygons.append({"pos": Vector2(x_pos, y_pos), "color": tile_color})
					
					if col > LANE_START_COL and col <= LANE_END_COL and (col - LANE_START_COL) % 2 == 0:
						if row % 2 == 0:
							stripe_positions.append({"pos": Vector2(x_pos, y_pos)})
			
			if tile_variant == 1 or tile_variant == 3:
				obstacle_positions.append({
					"pos": Vector2(x_pos, y_pos),
					"color": Color(1.0, 0.35, 0.15) if tile_variant == 1 else Color(1.0, 0.75, 0.0)
				})
	
	if lane_polygons.size() > 0:
		var lane_merged = MultiMeshInstance2D.new()
		lane_merged.texture = white_texture
		var multimesh = MultiMesh.new()
		multimesh.mesh = _create_diamond_mesh()
		multimesh.instance_count = lane_polygons.size()
		for i in lane_polygons.size():
			multimesh.set_instance_transform_2d(i, Transform2D(0.0, lane_polygons[i]["pos"]))
		lane_merged.multimesh = multimesh
		lane_merged.modulate = lane_polygons[0]["color"]
		chunk_local.add_child(lane_merged)
	
	if shoulder_polygons.size() > 0:
		var shoulder_merged = MultiMeshInstance2D.new()
		shoulder_merged.texture = white_texture
		var multimesh = MultiMesh.new()
		multimesh.mesh = _create_diamond_mesh()
		multimesh.instance_count = shoulder_polygons.size()
		for i in shoulder_polygons.size():
			multimesh.set_instance_transform_2d(i, Transform2D(0.0, shoulder_polygons[i]["pos"]))
		shoulder_merged.multimesh = multimesh
		shoulder_merged.modulate = shoulder_polygons[0]["color"]
		chunk_local.add_child(shoulder_merged)
	
	for stripe in stripe_positions:
		var stripe_poly = Polygon2D.new()
		stripe_poly.polygon = PackedVector2Array([
			Vector2(-2, -half_h * 0.6),
			Vector2(2, -half_h * 0.6),
			Vector2(2, half_h * 0.6),
			Vector2(-2, half_h * 0.6)
		])
		stripe_poly.color = Color(1.0, 1.0, 0.8)
		stripe_poly.position = stripe["pos"]
		chunk_local.add_child(stripe_poly)
	
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
		var sf = 0.6
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
		
		chunk_local.add_child(obstacle)
	
	var left_rail_x = (LANE_START_COL - 4.5) * TILE_SIZE.x - half_w
	var right_rail_x = (LANE_END_COL - 4.5) * TILE_SIZE.x + half_w
	
	var left_rail = Line2D.new()
	left_rail.width = 3.0
	left_rail.default_color = Color(1.0, 1.0, 0.8) if chunk_type != ChunkType.BRIDGE else Color(0.0, 0.8, 1.0)
	var left_points = PackedVector2Array()
	for row in CHUNK_HEIGHT + 1:
		var y_pos = row * TILE_SIZE.y
		left_points.append(Vector2(left_rail_x, y_pos))
	left_rail.points = left_points
	chunk_local.add_child(left_rail)
	
	var right_rail = Line2D.new()
	right_rail.width = 3.0
	right_rail.default_color = Color(1.0, 1.0, 0.8) if chunk_type != ChunkType.BRIDGE else Color(0.0, 0.8, 1.0)
	var right_points = PackedVector2Array()
	for row in CHUNK_HEIGHT + 1:
		var y_pos = row * TILE_SIZE.y
		right_points.append(Vector2(right_rail_x, y_pos))
	right_rail.points = right_points
	chunk_local.add_child(right_rail)
	
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
		var bridge_width = 48.0
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
	
	chunk.add_child(chunk_local)

func _create_diamond_mesh() -> ArrayMesh:
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

func _clear_chunk_tiles(chunk: Node2D) -> void:
	for child in chunk.get_children():
		if child.name == "Tiles":
			chunk.remove_child(child)
			child.queue_free()
			break
