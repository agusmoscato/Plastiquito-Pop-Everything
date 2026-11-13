class_name BubbleMesh
extends RefCounted
## Malla de la burbuja: domo (medio elipsoide) un poco achatado, de pocos triángulos
## porque se dibujan cientos de miles con MultiMesh.


static func build(radius: float, height_ratio: float = 0.8, rings: int = 6, segments: int = 20) -> ArrayMesh:
	var height: float = radius * height_ratio
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	for i: int in range(rings + 1):
		var phi: float = (float(i) / float(rings)) * PI * 0.5
		var ring_radius: float = sin(phi) * radius
		var y: float = cos(phi) * height
		for j: int in range(segments + 1):
			var theta: float = (float(j) / float(segments)) * TAU
			var x: float = cos(theta) * ring_radius
			var z: float = sin(theta) * ring_radius
			verts.append(Vector3(x, y, z))
			normals.append(Vector3(x / (radius * radius), y / (height * height), z / (radius * radius)).normalized())
			uvs.append(Vector2(float(j) / float(segments), float(i) / float(rings)))
	var indices: PackedInt32Array = PackedInt32Array()
	var stride: int = segments + 1
	for i: int in rings:
		for j: int in segments:
			var a: int = i * stride + j
			var b: int = a + 1
			var c: int = a + stride
			var d: int = c + 1
			indices.append_array(PackedInt32Array([a, c, b, b, c, d]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh: ArrayMesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh
