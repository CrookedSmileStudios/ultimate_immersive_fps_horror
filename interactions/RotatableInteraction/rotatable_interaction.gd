class_name RotatableInteraction
extends AbstractInteraction

"""
RotatableInteraction is an intermediary interaction class that defines rotation 
related properties and setup.  

This class does not implement the full rotation behavior itself; child classes 
should handle the actual rotation logic and interaction mechanics.  Use this as 
a base for doors, wheels, switches, or any other rotatable objects in the game.
"""

## Default sound effect for when the rotatable object is being rotated
@export var movement_sound: AudioStreamOggVorbis
var movement_audio_player: AudioStreamPlayer3D

## Maximum rotation (in degrees) in which the object can rotate.
@export var maximum_rotation: float

## Rotation of the object when the game first launches. Most likely zero, but will dynamically be set.
var starting_rotation: float = 0.0

## Current angle of the rotatable object
var current_angle: float = 0.0

## Previous angle of the rotatable object on the last frame
var previous_angle: float = 0.0

## How fast the rotatable object is moving on a given frame
var angular_velocity: float = 0.0

## How fast the rotatable object must be moving to produce a sound
var creak_velocity_threshold: float

## How fast the rotatable objects sound fades in or out
var fade_speed: float

## How louad the rotatable objects is
var volume_scale: float

## How smooth the rotatable object rotates
var smoothing_coefficient: float

## True if the player is interacting with the object. Can't be replaced with the defualt 
## is_interacting because this is manually tracked across frames so we can determine if
## the player was interacting on the previous frame
var input_active: bool = false


## Runs once, after the node and all its children have entered the scene tree and are ready
func _ready() -> void:
	super()
	maximum_rotation = deg_to_rad(rad_to_deg(starting_rotation)+maximum_rotation)
	
	# Initialize Audio
	movement_audio_player = AudioStreamPlayer3D.new()
	movement_audio_player.stream = movement_sound
	add_child(movement_audio_player)

## Runs once, when the player FIRST clicks on an object to interact with
func pre_interact() -> void:
	super()
	lock_camera = true
	previous_angle = current_angle
	
## Run every frame while the player is interacting with this object
func interact() -> void:
	super()
	_play_movement_sounds(get_process_delta_time())
	
## Alternate interaction using secondary button
func aux_interact() -> void:
	super()
	
## Runs once, when the player LAST interacts with an object
func post_interact() -> void:
	super()
	# Child classes should handle snapping/kickback logic
	
## Returns a float value from 0.0 to 100.0 telling how rotated a given object is
## between its starting rotation and its maximum rotation
func get_rotation_percentage() -> float:
	return (object_ref.rotation.z - starting_rotation) / (maximum_rotation - starting_rotation)
	
## Plays the main movement sound effect and adjusts its volume over time
func _play_movement_sounds(delta: float) -> void:
	# Velocity determines souhnd level. Sound level must be positive, even if the true velocity is negative
	var velocity = abs(angular_velocity)
	
	# Only make sound if velocity passes threshold
	var target_volume: float = 0.0
	if velocity > creak_velocity_threshold:
		target_volume = clamp((velocity - creak_velocity_threshold) * volume_scale, 0.0, 1.5)

	# Start sound if not already playing
	if movement_audio_player and not movement_audio_player.playing and target_volume > 0.0:
		movement_audio_player.volume_db = -15.0
		movement_audio_player.play()

	# Smooth fade in/out
	if movement_audio_player.playing:
		var current_vol = db_to_linear(movement_audio_player.volume_db)
		var new_vol = lerp(current_vol, target_volume, delta * fade_speed)
		movement_audio_player.volume_db = linear_to_db(clamp(new_vol, 0.0, 1.5))

		# Auto-stop if faded out
		if new_vol < 0.001 and target_volume == 0.0:
			movement_audio_player.stop()
			
## Forces movement sound to fade out quickly
func _stop_movement_sounds(delta: float) -> void:
	if movement_audio_player and movement_audio_player.playing:
		var current_vol = db_to_linear(movement_audio_player.volume_db)
		var new_vol = lerp(current_vol, 0.0, delta * fade_speed)
		movement_audio_player.volume_db = linear_to_db(clamp(new_vol, 0.0, 1.0))

		# Stop completely once inaudible
		if new_vol < 0.001:
			movement_audio_player.stop()
			
