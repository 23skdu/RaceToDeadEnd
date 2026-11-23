extends RefCounted
## Static geometry helpers for Highway chunk meshes.
## Extracted from Highway.gd to keep that script within the file-size lint limit.

const CHUNK_HEIGHT: int = 14
const TILE_SIZE: Vector2i = Vector2i(48, 24)
const CHUNK_PIXEL_HEIGHT: int = int(CHUNK_HEIGHT * TILE_SIZE.y)

static var _bridge_structure_mesh_cache: ArrayMesh = null


static func reset_caches() -> void:
	_bridge_structure_mesh_cache = null


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
			var p2 = pts[j + 1]
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

