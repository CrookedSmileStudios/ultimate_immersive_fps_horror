class_name WheelInteraction
extends RotatableInteraction

"""
WheelInteraction handles the rotation and interaction logic for a rotatable wheel object in the game. 

Features include:
- Player-driven rotation using mouse input for smooth movement.
- Optional fixed kickback when the player releases the wheel, simulating a ratchet and pawl system.
- Audio feedback for both rotation and kickback events.

Use this class for interactive wheels or valves.
"""

## Sound effect to play when the wheel kickbacks
@export var kickback_sound_effect: AudioStreamOggVorbis = preload("res://assets/sound_effects/wheel_kickback.ogg")
var kickback_audio_player: AudioStreamPlayer3D

## Determines how far the wheel should kickback after the player lets go, as if it is a ratchet and pawl system
## Set to 0.0 for no kickback (similar to a valve behavior)
@export var wheel_kick_intensity: float = 0.05

## True if the player has stopped interacting and the wheel is kicking back
var wheel_kickback_triggered: bool = false

## Keeps track of how far the wheel has to go to complete its kickback
var wheel_kickback: float = 0.0

## Refernce to the player camera for the player's spinning motion
var camera: Camera3D

## Keeps track of the previous mouse position to handle wheel spin
var previous_mouse_position: Vector2

## Runs once, after the node and all its children have entered the scene tree and are ready
func _ready() -> void:
	super()
	# Initialize Rotations
	object_ref = get_parent()
	starting_rotation = object_ref.rotation.z
	camera = get_tree().get_current_scene().find_child("Camera3D", true, false)

	# Initialize Audio
	kickback_audio_player = AudioStreamPlayer3D.new()
	kickback_audio_player.stream = kickback_sound_effect
	add_child(kickback_audio_player)
	
	# Initialize Rotatable Variables
	creak_velocity_threshold = 0.0001
	fade_speed = 5.0
	volume_scale = 1000.0
	smoothing_coefficient = 8.0
	
## Runs once, as soon as the node is added to the scene tree
func _enter_tree() -> void:
	# Initialize Audio
	movement_sound = preload("res://assets/sound_effects/wheel_spin.ogg")

## Runs once, when the player FIRST clicks on an object to interact with
func pre_interact() -> void:
	super()
	previous_mouse_position = get_viewport().get_mouse_position()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	
## Run every frame while the player is interacting with this object
func interact() -> void:
	super()
	
## Alternate interaction using secondary button
func aux_interact() -> void:
	super()
	
## Runs once, when the player LAST interacts with an object
func post_interact() -> void:
	super()
	wheel_kickback = -wheel_kick_intensity
	
func _process(delta: float) -> void:
	if is_interacting:
		_play_movement_sounds(delta)
	else:
		_stop_movement_sounds(delta)
	if abs(wheel_kickback) > 0.0001:
		current_angle += wheel_kickback
		wheel_kickback = lerp(wheel_kickback, 0.0, delta * 6.0)
		
		var min_wheel_rotation = starting_rotation / 0.1
		var max_wheel_rotation = maximum_rotation / 0.1
		current_angle = clamp(current_angle, min_wheel_rotation, max_wheel_rotation)
		angular_velocity = current_angle - previous_angle
		print(angular_velocity)
		
		object_ref.rotation.z = current_angle * 0.1
		var percentage: float = get_rotation_percentage()
		notify_nodes(percentage)
		
		# Detect start of kickback (player just released the wheel)
		if not is_interacting and not wheel_kickback_triggered and abs(wheel_kickback) > 0.01:
			wheel_kickback_triggered = true

			kickback_audio_player.stop()   # reset to avoid overlap
			kickback_audio_player.volume_db = -0.0
			kickback_audio_player.play()
	else:
		wheel_kickback_triggered = false
	
	angular_velocity = current_angle - previous_angle
	previous_angle = current_angle

## Called every frame the player is giving input to the door (moving the mouse)
func _input(event: InputEvent) -> void:
	if is_interacting:
		if event is InputEventMouseMotion:
			var mouse_position: Vector2 = event.position
			if calculate_cross_product(mouse_position) > 0:
				current_angle += 0.1
			else:
				current_angle -= 0.1
				
			object_ref.rotation.z = current_angle *.1
			object_ref.rotation.z = clamp(object_ref.rotation.z, starting_rotation, maximum_rotation)
			var percentage: float = get_rotation_percentage()
				
			previous_mouse_position = mouse_position
			
			# Clamp internal wheel_rotation using derived limits
			var min_wheel_rotation = starting_rotation / 0.1
			var max_wheel_rotation = maximum_rotation / 0.1
			current_angle = clamp(current_angle, min_wheel_rotation, max_wheel_rotation)

			notify_nodes(percentage)
		
## Uses mouse position to determine if the player is moving their mouse in a clockwise or counter-clockwise motion
func calculate_cross_product(_mouse_position: Vector2) -> float:
	var center_position = camera.unproject_position(object_ref.global_transform.origin)
	var vector_to_previous = previous_mouse_position - center_position
	var vector_to_current = _mouse_position - center_position
	var cross_product = vector_to_current.x * vector_to_previous.y - vector_to_current.y * vector_to_previous.x
	return cross_product
	
