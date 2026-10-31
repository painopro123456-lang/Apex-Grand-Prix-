extends Node3D
class_name RealCircuit

# Track centerlines and asymmetric edge widths are sourced from TUMFTM's
# OpenStreetMap-derived racetrack database. Coordinates are local metres.
@export var circuit_id: String = "Austin"

var circuit_name: String = ""
var country: String = ""
var start_position: Vector3 = Vector3.ZERO
var start_heading: float = 0.0
var lap_length_m: float = 0.0
var points: PackedVector2Array = PackedVector2Array()
var left_widths: PackedFloat32Array = PackedFloat32Array()
var right_widths: PackedFloat32Array = PackedFloat32Array()
var road_width_average: float = 13.0
var _racing_line: MeshInstance3D
var _racing_line_material: ShaderMaterial
var _racing_mesh: ArrayMesh
var _racing_path: PackedVector2Array = PackedVector2Array()
var _racing_target_speeds: PackedFloat32Array = PackedFloat32Array()
var _racing_cumulative_distances: PackedFloat32Array = PackedFloat32Array()
const RACING_LINE_LOOKAHEAD_M: float = 240.0

func _ready() -> void:
	_load_geometry()
	if points.size() < 20:
		push_error("Circuit geometry is missing or invalid: " + circuit_id)
		return
	_calculate_track_metrics()
	_build_ground()
	_build_road()
	_build_road_collision()
	_build_kerbs()
	_build_runoff_and_barriers()
	_build_start_line()
	_build_grid_boxes()
	_build_racing_line()

func _load_geometry() -> void:
	var path := "res://data/circuits/%s.csv" % circuit_id
	if not FileAccess.file_exists(path):
		push_error("Missing circuit data: " + path)
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Unable to open circuit data: " + path)
		return
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		var fields := line.split(",")
		if fields.size() < 4:
			continue
		points.append(Vector2(fields[0].to_float(), fields[1].to_float()))
		right_widths.append(maxf(4.0, fields[2].to_float()))
		left_widths.append(maxf(4.0, fields[3].to_float()))

func _calculate_track_metrics() -> void:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for p in points:
		bounds = bounds.expand(p)
	var center := bounds.get_center()
	for i in range(points.size()):
		points[i] -= center
	for i in range(points.size()):
		var next := points[(i + 1) % points.size()]
		lap_length_m += points[i].distance_to(next)
		road_width_average += left_widths[i] + right_widths[i]
	road_width_average = (road_width_average - 13.0) / float(points.size())
	var first_tangent := (points[1] - points[0]).normalized()
	start_heading = atan2(-first_tangent.x, -first_tangent.y)
	var grid_offset := _normal_at(0) * 3.0 - first_tangent * 7.0
	start_position = Vector3(points[0].x + grid_offset.x, 1.0, points[0].y + grid_offset.y)

func _normal_at(index: int) -> Vector2:
	var before := points[(index - 1 + points.size()) % points.size()]
	var after := points[(index + 1) % points.size()]
	var tangent := (after - before).normalized()
	return Vector2(-tangent.y, tangent.x)

func _build_ground() -> void:
	var bounds := Rect2(points[0], Vector2.ZERO)
	for p in points:
		bounds = bounds.expand(p)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = bounds.size + Vector2(260.0, 260.0)
	ground.mesh = plane
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color("#263b2b")
	mat.roughness = 1.0
	ground.material_override = mat
	ground.position = Vector3(bounds.get_center().x, -0.32, bounds.get_center().y)
	add_child(ground)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(plane.size.x, 0.5, plane.size.y)
	shape.shape = box
	body.position = ground.position
	body.add_child(shape)
	add_child(body)

func _build_road() -> void:
	var vertices := PackedVector3Array()
	var indices := PackedInt32Array()
	for i in range(points.size()):
		var center := points[i]
		var normal := _normal_at(i)
		var left := center + normal * left_widths[i]
		var right := center - normal * right_widths[i]
		vertices.append(Vector3(left.x, 0.025, left.y))
		vertices.append(Vector3(right.x, 0.025, right.y))
		var next := (i + 1) % points.size()
		var a := i * 2
		var b := next * 2
		indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var road := MeshInstance3D.new()
	road.name = "RealCircuitAsphalt"
	road.mesh = mesh
	var asphalt := StandardMaterial3D.new()
	asphalt.albedo_color = Color("#20242a")
	asphalt.roughness = 0.94
	asphalt.metallic = 0.02
	road.material_override = asphalt
	add_child(road)

func _build_road_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "RoadCollision"
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var tangent := (b - a).normalized()
		var strip := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(left_widths[i] + right_widths[i], 0.5, a.distance_to(b) + 0.4)
		strip.shape = shape
		strip.position = Vector3((a.x + b.x) * 0.5, -0.2, (a.y + b.y) * 0.5)
		strip.rotation.y = atan2(tangent.x, tangent.y)
		body.add_child(strip)
	add_child(body)

func _build_kerbs() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.8, 0.16, 1.0)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = mesh
	multi.instance_count = points.size() * 2
	var index := 0
	for i in range(points.size()):
		var tangent := (points[(i + 1) % points.size()] - points[i]).normalized()
		var yaw := atan2(tangent.x, tangent.y)
		var normal := _normal_at(i)
		for side in [-1.0, 1.0]:
			var edge: Vector2 = points[i] + normal * (left_widths[i] if side > 0.0 else -right_widths[i])
			var pos := Vector3(edge.x, 0.11, edge.y)
			multi.set_instance_transform(index, Transform3D(Basis(Vector3.UP, yaw), pos))
			multi.set_instance_color(index, Color("#d71920") if (i / 2) % 2 == 0 else Color("#eeeeea"))
			index += 1
	var kerbs := MultiMeshInstance3D.new()
	kerbs.multimesh = multi
	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.roughness = 0.86
	kerbs.material_override = material
	add_child(kerbs)

func _build_runoff_and_barriers() -> void:
	var barrier_mat := StandardMaterial3D.new()
	barrier_mat.albedo_color = Color("#aeb6c0")
	barrier_mat.metallic = 0.25
	barrier_mat.roughness = 0.55
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var tangent := (b - a).normalized()
		var normal := _normal_at(i)
		for side in [-1.0, 1.0]:
			var width := left_widths[i] if side > 0.0 else right_widths[i]
			var edge: Vector2 = a + normal * width * side
			var barrier_center: Vector2 = edge + normal * side * 13.0
			var wall := StaticBody3D.new()
			var visual := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.8, 1.1, a.distance_to(b) + 0.5)
			visual.mesh = box
			visual.material_override = barrier_mat
			wall.add_child(visual)
			var collider := CollisionShape3D.new()
			var collision := BoxShape3D.new()
			collision.size = box.size
			collider.shape = collision
			wall.add_child(collider)
			wall.position = Vector3(barrier_center.x, 0.55, barrier_center.y)
			wall.rotation.y = atan2(tangent.x, tangent.y)
			add_child(wall)

func _build_start_line() -> void:
	var tangent := (points[1] - points[0]).normalized()
	var normal := _normal_at(0)
	var width := left_widths[0] + right_widths[0]
	var line := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.04, 0.7)
	line.mesh = mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = Color.WHITE
	line.material_override = material
	line.position = Vector3(points[0].x, 0.07, points[0].y)
	line.rotation.y = atan2(tangent.x, tangent.y)
	add_child(line)

func _build_grid_boxes() -> void:
	var tangent := (points[1] - points[0]).normalized()
	var normal := _normal_at(0)
	var mark_mat := StandardMaterial3D.new()
	mark_mat.albedo_color = Color("#f0f0ed")
	for slot in range(20):
		var mark := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(2.4, 0.035, 1.1)
		mark.mesh = mesh
		mark.material_override = mark_mat
		var row := float(slot / 2)
		var side := -1.0 if slot % 2 == 0 else 1.0
		var p := points[0] - tangent * (7.0 + row * 5.5) + normal * side * 3.0
		mark.position = Vector3(p.x, 0.065, p.y)
		mark.rotation.y = atan2(tangent.x, tangent.y)
		add_child(mark)


func _racing_point(index: int, offset: float, offsets: PackedFloat32Array) -> Vector2:
	var normal := _normal_at(index)
	return points[index] + normal * offset

func _racing_local_cost(index: int, candidate_offset: float, offsets: PackedFloat32Array) -> float:
	var count := points.size()
	var previous_index := (index - 1 + count) % count
	var next_index := (index + 1) % count
	var previous := _racing_point(previous_index, offsets[previous_index], offsets)
	var current := _racing_point(index, candidate_offset, offsets)
	var next := _racing_point(next_index, offsets[next_index], offsets)
	var incoming := current - previous
	var outgoing := next - current
	var first_length := maxf(incoming.length(), 0.05)
	var second_length := maxf(outgoing.length(), 0.05)
	var chord_length := maxf((next - previous).length(), 0.05)
	var cross_value := absf(incoming.x * outgoing.y - incoming.y * outgoing.x)
	var curvature := 2.0 * cross_value / (first_length * second_length * chord_length)
	# Minimise distance while strongly discouraging sharp curvature. This
	# encourages a late-apex, wide-entry/wide-exit path instead of the centreline.
	return first_length + second_length + curvature * curvature * 110.0 * (first_length + second_length) * 0.5

func _calculate_fastest_racing_path() -> void:
	var count := points.size()
	_racing_path.clear()
	_racing_target_speeds.clear()
	_racing_cumulative_distances.clear()
	var offsets := PackedFloat32Array()
	offsets.resize(count)
	for i in range(count):
		offsets[i] = 0.0

	# Cyclic coordinate descent: each point is moved across the usable track
	# width to reduce total path length and cornering curvature.
	for iteration in range(9):
		for i in range(count):
			var min_offset := -right_widths[i] + 1.7
			var max_offset := left_widths[i] - 1.7
			if min_offset > max_offset:
				min_offset = 0.0
				max_offset = 0.0
			var best_offset := offsets[i]
			var best_cost := _racing_local_cost(i, best_offset, offsets)
			for sample in range(9):
				var candidate := lerpf(min_offset, max_offset, float(sample) / 8.0)
				var cost := _racing_local_cost(i, candidate, offsets)
				if cost < best_cost:
					best_cost = cost
					best_offset = candidate
			offsets[i] = best_offset

	for i in range(count):
		_racing_path.append(_racing_point(i, offsets[i], offsets))

	# Estimate corner speed from lateral grip, then propagate acceleration and
	# braking limits around the complete lap to create a usable speed profile.
	var segment_lengths := PackedFloat32Array()
	segment_lengths.resize(count)
	for i in range(count):
		segment_lengths[i] = maxf(_racing_path[i].distance_to(_racing_path[(i + 1) % count]), 0.1)
	for i in range(count):
		var previous := _racing_path[(i - 1 + count) % count]
		var current := _racing_path[i]
		var next := _racing_path[(i + 1) % count]
		var incoming := current - previous
		var outgoing := next - current
		var a := maxf(incoming.length(), 0.05)
		var b := maxf(outgoing.length(), 0.05)
		var chord := maxf((next - previous).length(), 0.05)
		var curvature := 2.0 * absf(incoming.x * outgoing.y - incoming.y * outgoing.x) / (a * b * chord)
		var target_mps := sqrt(12.5 / maxf(curvature, 0.00012))
		_racing_target_speeds.append(clampf(target_mps * 3.6, 42.0, 330.0))
	_racing_cumulative_distances.resize(count + 1)
	_racing_cumulative_distances[0] = 0.0
	for i in range(count):
		_racing_cumulative_distances[i + 1] = _racing_cumulative_distances[i] + segment_lengths[i]

	for pass_index in range(3):
		for step in range(count * 2):
			var i := step % count
			var previous_index := (i - 1 + count) % count
			var reachable := sqrt(pow(_racing_target_speeds[previous_index] / 3.6, 2.0) + 5.5 * segment_lengths[previous_index]) * 3.6
			_racing_target_speeds[i] = minf(_racing_target_speeds[i], reachable)
		for step in range(count * 2):
			var i := count - 1 - (step % count)
			var next_index := (i + 1) % count
			var reachable := sqrt(pow(_racing_target_speeds[next_index] / 3.6, 2.0) + 10.0 * segment_lengths[i]) * 3.6
			_racing_target_speeds[i] = minf(_racing_target_speeds[i], reachable)

func _build_racing_line() -> void:
	_calculate_fastest_racing_path()
	var count := _racing_path.size()
	if count < 3:
		return

	# Build one continuous, flat ribbon. Duplicate the first pair at the end
	# so progress values interpolate correctly across the start/finish seam.
	var vertices := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var half_width := 0.30
	var total_length := maxf(_racing_cumulative_distances[count], 1.0)
	for i in range(count + 1):
		var path_index := i % count
		var previous := _racing_path[(path_index - 1 + count) % count]
		var next := _racing_path[(path_index + 1) % count]
		var tangent := (next - previous).normalized()
		var normal := Vector2(-tangent.y, tangent.x)
		var point := _racing_path[path_index]
		var left := point + normal * half_width
		var right := point - normal * half_width
		vertices.append(Vector3(left.x, 0.19, left.y))
		vertices.append(Vector3(right.x, 0.19, right.y))
		var distance := _racing_cumulative_distances[i]
		var speed_value := _racing_target_speeds[path_index] / 330.0
		var progress_value := distance / total_length
		var vertex_data := Color(speed_value, progress_value, 0.0, 1.0)
		colors.append(vertex_data)
		colors.append(vertex_data)
		if i < count:
			var a := i * 2
			var b := (i + 1) * 2
			indices.append_array(PackedInt32Array([a, b, a + 1, a + 1, b, b + 1]))

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	_racing_mesh = ArrayMesh.new()
	_racing_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	var shader := Shader.new()
	shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_prepass_alpha;

uniform float progress_distance = 0.0;
uniform float lap_length = 1.0;
uniform float speed_kmh = 0.0;
uniform float lookahead_m = 240.0;

varying float target_speed;
varying float path_distance;

void vertex() {
	target_speed = COLOR.r * 330.0;
	path_distance = COLOR.g * lap_length;
}

void fragment() {
	float ahead = mod(path_distance - progress_distance + lap_length, lap_length);
	float yellow_factor = smoothstep(target_speed - 10.0, target_speed - 2.0, speed_kmh)
		* (1.0 - smoothstep(target_speed + 2.0, target_speed + 10.0, speed_kmh));
	float red_factor = smoothstep(target_speed + 2.0, target_speed + 10.0, speed_kmh);
	vec3 green = vec3(0.18, 0.82, 0.38);
	vec3 yellow = vec3(1.0, 0.78, 0.16);
	vec3 red = vec3(1.0, 0.035, 0.025);
	vec3 line_color = mix(green, yellow, yellow_factor);
	line_color = mix(line_color, red, red_factor);
	if (ahead > lookahead_m) {
		line_color = green;
	}
	ALBEDO = line_color;\n\tALPHA = 0.62;\n\tEMISSION = line_color * (red_factor * 0.42 + yellow_factor * 0.08);
}
"""
	_racing_line_material = ShaderMaterial.new()
	_racing_line_material.shader = shader
	_racing_line_material.set_shader_parameter("lap_length", total_length)
	_racing_line_material.set_shader_parameter("progress_distance", 0.0)
	_racing_line_material.set_shader_parameter("speed_kmh", 0.0)
	_racing_line_material.set_shader_parameter("lookahead_m", RACING_LINE_LOOKAHEAD_M)

	_racing_line = MeshInstance3D.new()
	_racing_line.name = "RacingLineGuide"
	_racing_line.mesh = _racing_mesh
	_racing_line.material_override = _racing_line_material
	add_child(_racing_line)

func _get_racing_progress(car_position: Vector2) -> Vector2:
	# Project onto every path segment. Using the nearest vertex alone can jump
	# between samples on tight corners and incorrectly classify the next zone
	# as being almost a full lap ahead.
	var count := _racing_path.size()
	var best_distance_squared := INF
	var best_segment := 0
	var best_segment_fraction := 0.0
	for i in range(count):
		var a := _racing_path[i]
		var b := _racing_path[(i + 1) % count]
		var segment := b - a
		var fraction := clampf((car_position - a).dot(segment) / maxf(segment.length_squared(), 0.0001), 0.0, 1.0)
		var closest := a + segment * fraction
		var distance_squared := car_position.distance_squared_to(closest)
		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_segment = i
			best_segment_fraction = fraction
	var segment_distance := _racing_cumulative_distances[best_segment + 1] - _racing_cumulative_distances[best_segment]
	var progress_distance := _racing_cumulative_distances[best_segment] + segment_distance * best_segment_fraction
	return Vector2(float(best_segment), progress_distance)

func _get_racing_line_color_state(index: int, progress_distance: float, speed_kmh: float) -> int:
	var lap_distance := _racing_cumulative_distances[_racing_path.size()]
	var forward_distance := _racing_cumulative_distances[index] - progress_distance
	if forward_distance < 0.0:
		forward_distance += lap_distance
	if forward_distance > RACING_LINE_LOOKAHEAD_M:
		return 0
	var target_speed := _racing_target_speeds[index]
	if speed_kmh > target_speed + 8.0:
		return 2 # red / brake
	if speed_kmh > target_speed - 8.0:
		return 1 # yellow / lift
	return 0 # green / accelerate

func update_racing_line_feedback(world_position: Vector3, speed_kmh: float) -> void:
	if _racing_line_material == null or _racing_path.is_empty() or _racing_cumulative_distances.size() != _racing_path.size() + 1:
		return
	var progress := _get_racing_progress(Vector2(world_position.x, world_position.z))
	_racing_line_material.set_shader_parameter("progress_distance", progress.y)
	_racing_line_material.set_shader_parameter("speed_kmh", speed_kmh)


func set_racing_line_visible(enabled: bool) -> void:
	if is_instance_valid(_racing_line):
		_racing_line.visible = enabled

func has_crossed_start_line(previous: Vector3, current: Vector3) -> bool:
	var origin := points[0]
	var tangent := (points[1] - points[0]).normalized()
	var before := Vector2(previous.x - origin.x, previous.z - origin.y).dot(tangent)
	var after := Vector2(current.x - origin.x, current.z - origin.y).dot(tangent)
	var normal := _normal_at(0)
	var lateral := absf(Vector2(current.x - origin.x, current.z - origin.y).dot(normal))
	return before < 0.0 and after >= 0.0 and lateral <= road_width_average * 0.55

func get_lateral_track_distance(world_position: Vector3) -> float:
	var best := INF
	var lateral := 0.0
	for i in range(points.size()):
		var a := points[i]
		var b := points[(i + 1) % points.size()]
		var segment := b - a
		var t := clampf((Vector2(world_position.x, world_position.z) - a).dot(segment) / maxf(segment.length_squared(), 0.001), 0.0, 1.0)
		var nearest := a + segment * t
		var distance := Vector2(world_position.x, world_position.z).distance_squared_to(nearest)
		if distance < best:
			best = distance
			lateral = sqrt(distance)
	return lateral

func is_on_gravel(world_position: Vector3) -> bool:
	var distance := get_lateral_track_distance(world_position)
	return distance > road_width_average * 0.5 + 1.0 and distance < road_width_average * 0.5 + 16.0
