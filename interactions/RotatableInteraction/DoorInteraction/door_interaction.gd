class_name DoorInteraction
extends RotatableInteraction

"""
DoorInteraction handles all player interaction logic for hinged doors.

Features:
- Supports locked and unlocked states, including a small "wiggle" motion and
  locked sound feedback when the player attempts to open a locked door.
- Tracks door velocity and applies smoothing for realistic swing motion.
- Plays creaking sounds when the door is moved past a velocity threshold, with
  dynamic volume scaling based on movement speed.
- Plays a shut/impact sound when the door returns to the closed position.
- Resets state cleanly when a door is unlocked, ensuring it snaps back to
  starting rotation without carrying over unintended velocity.

Use this class for standard hinged doors that open on a pivot.
"""

## Defines the point where the door will rotate around
@export var pivot_point: Node3D

@export var unlock_key_name: String

## True if the door is locked, false otherwise
@export var is_locked: bool = false

## True if the pivot is on the right side of the door, the movement rotation should flip
@export var flip_pivot: bool = false

@export var reverse_input_direction: bool = false

## Sound effect to play when the door shuts
@export var shut_sound_effect: AudioStreamOggVorbis = preload("res://assets/sound_effects/DoorClose2.ogg")
var shut_audio_player: AudioStreamPlayer3D

## Sound effect to play when the door is locked and the player interacts with the door
@export var locked_sound_effect: AudioStreamOggVorbis = preload("res://assets/sound_effects/DoorLocked.ogg")
var locked_audio_player: AudioStreamPlayer3D

## True if the player is interacting with the front of the door, false if its the back
var is_front: bool
## True if the doors rotation is past a certain threshold
var door_opened: bool = false
## how far the door must be opened to count as "opened"
var shut_angle_threshold: float = 0.2
## how close to starting_rotation counts as "closed"
var shut_snap_range: float = 0.05
## True if the door was locked on the previous frame, false otherwise
var was_just_unlocked: bool = false

## Runs once, after the node and all its children have entered the scene tree and are ready
func _ready() -> void:
	super()
	# Initialize Rotations
	starting_rotation = pivot_point.rotation.y
	
	if flip_pivot:
		maximum_rotation = starting_rotation - abs(maximum_rotation)
	else:
		maximum_rotation = starting_rotation + abs(maximum_rotation)
	
	# Initialize Audio
	shut_audio_player = AudioStreamPlayer3D.new()
	shut_audio_player.stream = shut_sound_effect
	add_child(shut_audio_player)
	
	locked_audio_player = AudioStreamPlayer3D.new()
	locked_audio_player.stream = locked_sound_effect
	add_child(locked_audio_player)
	
	# Initialize Rotatable Variables
	creak_velocity_threshold = 0.005
	fade_speed = 1.0
	volume_scale = 1000.0
	smoothing_coefficient = 80.0

## Runs once, as soon as the node is added to the scene tree
func _enter_tree() -> void:
	# Initialize Audio
	movement_sound = preload("res://assets/sound_effects/DoorCreak.ogg")

## Runs once, when the player FIRST clicks on an object to interact with
func pre_interact() -> void:
	super()
	
## Run every frame while the player is interacting with this object
func interact() -> void:
	super()
	
## Alternate interaction using secondary button
func aux_interact() -> void:
	super()
	
## Runs once, when the player LAST interacts with an object
func post_interact() -> void:
	super()
	
func _process(delta: float) -> void:
	if was_just_unlocked:
		angular_velocity = 0.0
		input_active = false
		current_angle = starting_rotation
		pivot_point.rotation.y = starting_rotation
		was_just_unlocked = false
	else:
		if not input_active:
			angular_velocity = lerp(angular_velocity, 0.0, delta * 4.0)
		
		current_angle += angular_velocity

		if is_locked:
			var lock_wiggle: float = 0.02
			if flip_pivot:
				current_angle = clamp(current_angle, starting_rotation - lock_wiggle, starting_rotation)
			else:
				current_angle = clamp(current_angle, starting_rotation, starting_rotation + lock_wiggle)
			pivot_point.rotation.y = current_angle
			
			if input_active and not locked_audio_player.playing and not previous_angle == current_angle:
				locked_audio_player.play()
				input_active = false
		else:
			if flip_pivot:
				current_angle = clamp(current_angle, maximum_rotation, starting_rotation)
			else:
				current_angle = clamp(current_angle, starting_rotation, maximum_rotation)
			pivot_point.rotation.y = current_angle
			input_active = false

			if previous_angle == current_angle:
				_stop_movement_sounds(delta)
			else:
				_play_movement_sounds(delta)
			
		previous_angle = current_angle
		
	if abs(current_angle - starting_rotation) > shut_angle_threshold:
		door_opened = true
	
	# If the door was previosuly opened and the player is now shutting it
	if door_opened and abs(current_angle - starting_rotation) < shut_snap_range:
		allow_movement_sound = false
		angular_velocity = 0.0
		movement_audio_player.stop()
		shut_audio_player.stop()
		shut_audio_player.play()
		door_opened = false

## Called every frame the player is giving input to the door (moving the mouse)
func _input(event: InputEvent) -> void:
	if is_interacting:
		if event is InputEventMouseMotion:
			input_active = true
			allow_movement_sound = true
			var delta: float = -event.relative.y * 0.001
			if not is_front:
				delta = -delta
			if flip_pivot:
				delta = -delta  # flip input for pivot being on bottom right
			if reverse_input_direction:
				delta = -delta
				
			# Simulate resistance to small motions
			if abs(delta) < 0.01:
				delta *= 0.25
			# Smooth velocity blending
			angular_velocity = lerp(angular_velocity, delta, 1.0 / smoothing_coefficient)

## True if we are looking at the front of an object, false otherwise
func set_direction(_normal: Vector3) -> void:
	if _normal.z > 0:
		is_front = true
	else:
		is_front = false
		
## Unlocks the door and sets necessary variables
func unlock() -> void:
	is_locked = false
	was_just_unlocked = true
	
	angular_velocity = 0.0
	input_active = false
	current_angle = starting_rotation
	pivot_point.rotation.y = starting_rotation

## Plays the secondary impact sound effect or the door shutting
func _play_door_shut_sound(volume_db: float = 0.0) -> void:
	allow_movement_sound = false

	angular_velocity = 0.0

	movement_audio_player.stop()
	shut_audio_player.stop()
	shut_audio_player.volume_db = volume_db
	shut_audio_player.play()

func use_item(item_data: ItemData) -> bool:
	if item_data.item_name == unlock_key_name:
		is_locked = false
		return true
	else:
		return false
