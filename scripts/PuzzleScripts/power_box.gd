extends Area3D

## A list of nodes that interacting with this interactable could affect. The nodes in this array should have their own script attached
## that has an "execute" method that you can call using the provided notify_nodes(percentage: float) method.
@export var nodes_to_affect: Array[Node]

@export var light: OmniLight3D

@export var snap_offset: Vector3 = Vector3.ZERO
var snapped_object: RigidBody3D = null
var is_being_held: bool = false

func _ready() -> void:
	connect("body_entered", Callable(self, "_on_body_entered"))
	connect("body_exited", Callable(self, "_on_body_exited"))

func _on_body_entered(body: Node) -> void:
	if body is RigidBody3D:
		# Only snap if not currently held
		if not is_being_held:
			snap_object(body)

func _on_body_exited(body: Node) -> void:
	if body == snapped_object:
		release_object()

func snap_object(body: RigidBody3D) -> void:
	snapped_object = body

	# Stop gravity from dragging it down but allow player to grab
	snapped_object.gravity_scale = 0.0

	# Reset velocities
	snapped_object.linear_velocity = Vector3.ZERO
	snapped_object.angular_velocity = Vector3.ZERO

	# Align upright
	var upright_basis = Basis.IDENTITY
	upright_basis.y = Vector3.UP
	snapped_object.global_transform.basis = upright_basis

func release_object() -> void:
	if snapped_object:
		snapped_object.gravity_scale = 1.0
		snapped_object = null
		is_being_held = false

func _physics_process(delta: float) -> void:
	var percentage = 0.0
	if snapped_object:
		percentage = 100.0
		light.visible = true
		# Smoothly hold at center if not being grabbed
		var target_pos = global_transform.origin + snap_offset
		var current_pos = snapped_object.global_transform.origin
		snapped_object.global_transform.origin = current_pos.lerp(target_pos, 10.0 * delta)
		
		# Check if player is currently grabbing the object
		if snapped_object.find_child("GrabbableInteraction").is_interacting:
			is_being_held = true
		else:
			is_being_held = false
			# Reset rotation to upright
			snapped_object.rotation_degrees = Vector3.ZERO
	else:
		light.visible = false
		percentage = 0.0
		
	notify_nodes(percentage)
	
## Iterates over a list of nodes that can be interacted with and executes their respective logic
func notify_nodes(percentage: float) -> void:
	for node in nodes_to_affect:
		if node and node.has_method("execute"):
			node.call("execute", percentage)
