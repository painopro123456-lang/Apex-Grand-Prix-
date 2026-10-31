extends Node3D
class_name OvalCircuit

@export var half_length: float = 112.0
@export var half_width: float = 68.0
@export var road_width: float = 18.0
@export var segments: int = 180

var start_position: Vector3 = Vector3(0, 0.15, -half_width)
var start_heading: float = 0.0

func _ready() -> void:
	_build_ground()
	_build_road()
	_build_track_markings()
	_build_curbs()
	_build_barriers()
	_build_grid_marks()

func _center_at(t: float) -> Vector3:
	var angle := t * TAU
	return Vector3(cos(angle) * half_length, 0.0, sin(angle) * half_width)

func _side_at(t: float) -> Vector3:
	var angle := t * TAU
	var normal := Vector3(cos(angle) / half_length, 0.0, sin(angle) / half_width).normalized()
	return normal

func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(650, 480)
	ground.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.075, 0.19, 0.105)
	material.roughness = 1.0
	ground.material_override = material
	ground.position.y = -0.28
	add_child(ground)

	var body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(650, 0.5, 480)
	collision.shape = shape
	body.position.y = -0.55
	body.add_child(collision)
	add_child(body)

func _build_road() -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	var half_road := road_width * 0.5
	for i in range(segments + 1):
		var t := float(i) / float(segments)
		var center := _center_at(t)
		var side := _side_at(t)
		vertices.append(center - side * half_road + Vector3.UP * 0.02)
		vertices.append(center + side * half_road + Vector3.UP * 0.02)
		if i < segments:
			var a := i * 2
			indices.append_array(PackedInt32Array([a, a + 2, a + 1, a + 1, a + 2, a + 3]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var road := MeshInstance3D.new()
	road.mesh = mesh
	var asphalt_shader := Shader.new()
	asphalt_shader.code = """
shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;
varying vec3 track_world_position;
void vertex() {
    track_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
float hash21(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}
void fragment() {
    vec2 cell = floor(track_world_position.xz * 5.0);
    float grain = hash21(cell) * 0.075;
    float variation = sin(track_world_position.x * 0.17) * sin(track_world_position.z * 0.13) * 0.012;
    vec3 asphalt = vec3(0.073, 0.080, 0.091) + grain + variation;
    ALBEDO = asphalt;
    ROUGHNESS = 0.94;
}
"""
	var asphalt := ShaderMaterial.new()
	asphalt.shader = asphalt_shader
	road.material_override = asphalt
	add_child(road)

	var road_body := StaticBody3D.new()
	var road_collision := CollisionShape3D.new()
	road_collision.shape = mesh.create_trimesh_shape()
	road_body.add_child(road_collision)
	add_child(road_body)


func _build_curbs() -> void:
	var curb_mesh := BoxMesh.new()
	curb_mesh.size = Vector3(2.5, 0.16, 1.15)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = curb_mesh
	multimesh.instance_count = segments * 2
	var instance := 0
	for i in range(segments):
		var t := float(i) / float(segments)
		var next_t := float(i + 1) / float(segments)
		var center := _center_at(t)
		var side := _side_at(t)
		var tangent := (_center_at(next_t) - center).normalized()
		var yaw := atan2(tangent.x, tangent.z)
		for side_sign in [-1.0, 1.0]:
			var curb_position := center + side * (road_width * 0.5 + 0.75) * side_sign
			var basis := Basis(Vector3.UP, yaw)
			multimesh.set_instance_transform(instance, Transform3D(basis, curb_position + Vector3.UP * 0.1))
			var stripe_color := Color(0.82, 0.045, 0.055) if (i / 3) % 2 == 0 else Color(0.92, 0.92, 0.9)
			multimesh.set_instance_color(instance, stripe_color)
			instance += 1
	var curbs := MultiMeshInstance3D.new()
	curbs.multimesh = multimesh
	var curb_material := StandardMaterial3D.new()
	curb_material.vertex_color_use_as_albedo = true
	curb_material.roughness = 0.86
	curbs.material_override = curb_material
	add_child(curbs)

func _build_barriers() -> void:
	for side_sign in [-1.0, 1.0]:
		for i in range(segments):
			var t0 := float(i) / float(segments)
			var t1 := float(i + 1) / float(segments)
			var p0 := _center_at(t0) + _side_at(t0) * road_width * 0.5 * side_sign
			var p1 := _center_at(t1) + _side_at(t1) * road_width * 0.5 * side_sign
			var midpoint := (p0 + p1) * 0.5
			var length := p0.distance_to(p1) + 0.25
			var wall := StaticBody3D.new()
			var visual := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.9, 1.15, length)
			visual.mesh = box
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.72, 0.74, 0.78)
			mat.metallic = 0.28
			visual.material_override = mat
			wall.add_child(visual)
			var collider := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = box.size
			collider.shape = shape
			wall.add_child(collider)
			wall.position = midpoint + Vector3.UP * 0.55
			wall.rotation.y = atan2(p1.x - p0.x, p1.z - p0.z)
			add_child(wall)

func _build_grid_marks() -> void:
	var line := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(road_width * 0.92, 0.035, 0.65)
	line.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.92, 0.93, 0.94)
	line.material_override = mat
	line.position = Vector3(half_length, 0.06, 0.0)
	line.rotation.y = 0.0
	add_child(line)

	for slot in range(20):
		var mark := MeshInstance3D.new()
		var mark_mesh := BoxMesh.new()
		mark_mesh.size = Vector3(2.4, 0.035, 1.1)
		mark.mesh = mark_mesh
		var mark_mat := StandardMaterial3D.new()
		mark_mat.albedo_color = Color(0.88, 0.89, 0.9)
		mark.material_override = mark_mat
		mark.position = Vector3(half_length - 3.2 if slot % 2 == 0 else half_length + 3.2, 0.065, -5.0 - float(slot / 2) * 4.5)
		add_child(mark)

func _build_track_markings() -> void:
	var line_mesh := BoxMesh.new()
	line_mesh.size = Vector3(0.22, 0.035, 2.4)
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = line_mesh
	multimesh.instance_count = segments * 2
	var index := 0
	for i in range(segments):
		var t := float(i) / float(segments)
		var next_t := float(i + 1) / float(segments)
		var center := _center_at(t)
		var tangent := (_center_at(next_t) - center).normalized()
		var yaw := atan2(tangent.x, tangent.z)
		for side_sign in [-1.0, 1.0]:
			var point := center + _side_at(t) * (road_width * 0.5 - 0.28) * side_sign
			multimesh.set_instance_transform(index, Transform3D(Basis(Vector3.UP, yaw), point + Vector3.UP * 0.055))
			index += 1
	var markings := MultiMeshInstance3D.new()
	markings.multimesh = multimesh
	var paint := StandardMaterial3D.new()
	paint.albedo_color = Color(0.88, 0.89, 0.87)
	paint.roughness = 0.82
	markings.material_override = paint
	add_child(markings)
