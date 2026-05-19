extends Node2D

signal segment_completed(segment: int)

const CHUNK_HEIGHT: int = 10
const CHUNK_WIDTH: int = 5
const TILE_SIZE: Vector2i = Vector2i(64, 32)
const CHUNK_PIXEL_HEIGHT: int = 320
const PREWARM_CHUNKS: int = 4
const DESPAWN_CHUNKS_BEHIND: int = 1

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

func _ready() -> void:
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
			break

func _spawn_chunk(offset: int) -> void:
	var chunk = Node2D.new()
	var chunk_type = _pick_chunk_type()
	# First chunk should be standard to give player time to start
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
	var total_weight = 0
	for w in chunk_weights.values():
		total_weight += w
	var roll = randi() % total_weight
	var cumulative = 0
	for type in chunk_weights:
		cumulative += chunk_weights[type]
		if roll < cumulative:
			return type
	return ChunkType.STANDARD

func _generate_chunk_tiles(chunk: Node2D, chunk_type: ChunkType) -> void:
	var chunk_local = Node2D.new()
	chunk_local.name = "Tiles"
	
	var half_w = TILE_SIZE.x / 2.0
	var half_h = TILE_SIZE.y / 2.0
	
	# 1. Spawn base tile textures / shapes
	for row in CHUNK_HEIGHT:
		for col in CHUNK_WIDTH:
			var tile_variant = _get_tile_variant(chunk_type, row, col)
			
			# Generate isometric coordinate stacked offset
			var x_pos = (col - 2) * TILE_SIZE.x
			if row % 2 == 1:
				x_pos += half_w
			var y_pos = row * TILE_SIZE.y
			
			# Create Polygon2D diamond
			var tile = Polygon2D.new()
			tile.polygon = PackedVector2Array([
				Vector2(0, -half_h),
				Vector2(half_w, 0),
				Vector2(0, half_h),
				Vector2(-half_w, 0)
			])
			tile.position = Vector2(x_pos, y_pos)
			
			# Assign colors for futuristic styling
			if col == 0 or col == CHUNK_WIDTH - 1:
				# Shoulders / Margins
				if chunk_type == ChunkType.BRIDGE:
					tile.color = Color(0.02, 0.02, 0.06) # Abyss
				elif chunk_type == ChunkType.CONSTRUCTION:
					tile.color = Color(0.7, 0.5, 0.0) # Warning Yellow
				else:
					tile.color = Color(0.05, 0.18, 0.08) # Cyber Green
			else:
				# Main highway lanes
				if chunk_type == ChunkType.ICE:
					tile.color = Color(0.2, 0.6, 0.9, 0.6) # Sleek glowing ice blue
				else:
					tile.color = Color(0.12, 0.12, 0.16) # Dark asphalt grey
					
			chunk_local.add_child(tile)
			
			# Spawn Collidable obstacles
			if tile_variant == 1 or tile_variant == 3:
				var obstacle = StaticBody2D.new()
				obstacle.collision_layer = 1
				obstacle.collision_mask = 1
				obstacle.position = tile.position
				obstacle.add_to_group("obstacles")
				
				var col_poly = CollisionPolygon2D.new()
				col_poly.polygon = tile.polygon
				obstacle.add_child(col_poly)
				
				# Standout elevated visual diamond representation
				var visual = Polygon2D.new()
				var sf = 0.6
				visual.polygon = PackedVector2Array([
					Vector2(0, -half_h * sf),
					Vector2(half_w * sf, 0),
					Vector2(0, half_h * sf),
					Vector2(-half_w * sf, 0)
				])
				visual.color = Color(1.0, 0.35, 0.15) if tile_variant == 1 else Color(1.0, 0.75, 0.0)
				obstacle.add_child(visual)
				
				chunk_local.add_child(obstacle)

	# 2. Spawn Side Guardrails / Glowing Laser borders
	for row in CHUNK_HEIGHT:
		var y_pos = row * TILE_SIZE.y
		# Left laser line
		var left_rail = Line2D.new()
		left_rail.width = 3.0
		left_rail.default_color = Color(1.0, 0.0, 0.5) if chunk_type != ChunkType.BRIDGE else Color(0.0, 0.8, 1.0)
		left_rail.points = PackedVector2Array([
			Vector2(-96, y_pos - half_h),
			Vector2(-96 + half_w, y_pos)
		] if row % 2 == 1 else [
			Vector2(-128, y_pos - half_h),
			Vector2(-128 + half_w, y_pos)
		])
		chunk_local.add_child(left_rail)
		
		# Right laser line
		var right_rail = Line2D.new()
		right_rail.width = 3.0
		right_rail.default_color = Color(1.0, 0.0, 0.5) if chunk_type != ChunkType.BRIDGE else Color(0.0, 0.8, 1.0)
		right_rail.points = PackedVector2Array([
			Vector2(96, y_pos - half_h),
			Vector2(96 + half_w, y_pos)
		] if row % 2 == 1 else [
			Vector2(64, y_pos - half_h),
			Vector2(64 + half_w, y_pos)
		])
		chunk_local.add_child(right_rail)

	# 3. Ice Trigger Areas
	if chunk_type == ChunkType.ICE:
		var ice_area = Area2D.new()
		ice_area.collision_layer = 0
		ice_area.collision_mask = 1
		var ice_col = CollisionPolygon2D.new()
		ice_col.polygon = PackedVector2Array([
			Vector2(-96, 0),
			Vector2(96, 0),
			Vector2(96, CHUNK_PIXEL_HEIGHT),
			Vector2(-96, CHUNK_PIXEL_HEIGHT)
		])
		ice_area.add_child(ice_col)
		ice_area.body_entered.connect(_on_ice_entered)
		ice_area.body_exited.connect(_on_ice_exited)
		chunk_local.add_child(ice_area)

	# 4. Bridge Danger Areas (Death/Fall detection on side margins)
	if chunk_type == ChunkType.BRIDGE:
		# Left bridge side Area2D
		var left_bridge = Area2D.new()
		left_bridge.collision_layer = 0
		left_bridge.collision_mask = 1
		var left_col = CollisionPolygon2D.new()
		left_col.polygon = PackedVector2Array([
			Vector2(-160, 0),
			Vector2(-96, 0),
			Vector2(-96, CHUNK_PIXEL_HEIGHT),
			Vector2(-160, CHUNK_PIXEL_HEIGHT)
		])
		left_bridge.add_child(left_col)
		left_bridge.body_entered.connect(_on_bridge_fall)
		chunk_local.add_child(left_bridge)
		
		# Right bridge side Area2D
		var right_bridge = Area2D.new()
		right_bridge.collision_layer = 0
		right_bridge.collision_mask = 1
		var right_col = CollisionPolygon2D.new()
		right_col.polygon = PackedVector2Array([
			Vector2(96, 0),
			Vector2(160, 0),
			Vector2(160, CHUNK_PIXEL_HEIGHT),
			Vector2(96, CHUNK_PIXEL_HEIGHT)
		])
		right_bridge.add_child(right_col)
		right_bridge.body_entered.connect(_on_bridge_fall)
		chunk_local.add_child(right_bridge)

	chunk.add_child(chunk_local)

func _on_ice_entered(body: Node) -> void:
	if body.has_method("set_slippery"):
		body.set_slippery(true)

func _on_ice_exited(body: Node) -> void:
	if body.has_method("set_slippery"):
		body.set_slippery(false)

func _on_bridge_fall(body: Node) -> void:
	if body.has_method("take_damage"):
		body.take_damage(2)
		# Safe repush positioning toward road center
		if body.position.x < 0:
			body.position.x = -32
			if "current_lane" in body:
				body.current_lane = 1
		else:
			body.position.x = 32
			if "current_lane" in body:
				body.current_lane = 2

func _get_tile_variant(chunk_type: ChunkType, row: int, col: int) -> int:
	match chunk_type:
		ChunkType.STANDARD:
			return 0
		ChunkType.DEBRIS:
			return 1 if row % 3 == 0 and col % 2 == 0 else 0
		ChunkType.ICE:
			return 2
		ChunkType.CONSTRUCTION:
			return 3 if col == 0 or col == CHUNK_WIDTH - 1 else 0
		ChunkType.BRIDGE:
			return 4
		_:
			return 0

func _clear_chunk_tiles(chunk: Node2D) -> void:
	for child in chunk.get_children():
		if child.name == "Tiles":
			child.queue_free()
			await child.tree_exited
