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

@onready var tile_map: TileMap = $TileMap
@onready var road_layer: TileMapLayer = $RoadLayer
@onready var decoration_layer: TileMapLayer = $DecorationLayer

func _ready() -> void:
	for i in PREWARM_CHUNKS:
		_spawn_chunk(i)

func _process(delta: float) -> void:
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
	chunk.position.y = -offset * CHUNK_PIXEL_HEIGHT
	chunk.set_meta("chunk_type", chunk_type)
	chunk.set_meta("segment", current_segment)
	_generate_chunk_tiles(chunk, chunk_type)
	active_chunks.append(chunk)
	add_child(chunk)
	current_segment += 1

func _recycle_chunk(chunk: Node2D) -> void:
	var highest_y = -INF
	for c in active_chunks:
		if c.position.y > highest_y:
			highest_y = c.position.y
	chunk.position.y = highest_y - CHUNK_PIXEL_HEIGHT
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
	for row in CHUNK_HEIGHT:
		for col in CHUNK_WIDTH:
			var tile_pos = _get_tile_variant(chunk_type, row, col)
			pass
	chunk.add_child(chunk_local)

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
