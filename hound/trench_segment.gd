extends Node3D

@export_range(1.0, 20.0, 0.5) var marking_spacing := 6.0
@export var marking_emission_energy := 2.0

const SEGMENT_START_Z := -187.0
const SEGMENT_END_Z := 8.0


func _ready() -> void:
	var marking_material := StandardMaterial3D.new()
	marking_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marking_material.albedo_color = Color(0.75, 0.85, 1.0)
	marking_material.emission_enabled = true
	marking_material.emission = Color(0.35, 0.55, 1.0)
	marking_material.emission_energy_multiplier = marking_emission_energy

	_create_floor_markings(marking_material)
	_create_wall_markings(marking_material)


func _create_floor_markings(material: Material) -> void:
	var positions: Array[Vector3] = []
	var z := SEGMENT_START_Z
	while z <= SEGMENT_END_Z:
		positions.append(Vector3(-3.25, -4.49, z))
		positions.append(Vector3(3.25, -4.49, z))
		z += marking_spacing

	var marking_mesh := BoxMesh.new()
	marking_mesh.size = Vector3(0.12, 0.02, 1.5)
	marking_mesh.material = material
	_add_multimesh("FloorMarkings", marking_mesh, positions)


func _create_wall_markings(material: Material) -> void:
	var positions: Array[Vector3] = []
	var z := SEGMENT_START_Z
	while z <= SEGMENT_END_Z:
		positions.append(Vector3(-9.49, 0.0, z))
		positions.append(Vector3(9.49, 0.0, z))
		z += marking_spacing

	var marking_mesh := BoxMesh.new()
	marking_mesh.size = Vector3(0.02, 0.3, 1.5)
	marking_mesh.material = material
	_add_multimesh("WallMarkings", marking_mesh, positions)


func _add_multimesh(
	node_name: String,
	mesh: Mesh,
	positions: Array[Vector3]
) -> void:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = positions.size()

	for index in positions.size():
		multimesh.set_instance_transform(
			index,
			Transform3D(Basis.IDENTITY, positions[index])
		)

	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	add_child(instance)
