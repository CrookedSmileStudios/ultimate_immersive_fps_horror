class_name GrabbableInteraction
extends AbstractInteraction

"""
GrabbableInteraction handles objects that the player can pick up, carry, and throw.
It extends AbstractInteraction to reuse common interaction logic while adding
pickup-specific behavior such as following the player’s hand, applying physics-based
movement, and playing collision sound effects when the object hits other surfaces.

This class is suitable for any interactable object that should respond to grab-and-throw
mechanics in the game world.
"""

## Sound effect to play when a grabbable objects collides with something
@export var collision_sound_effect: AudioStreamOggVorbis = preload("res://assets/sound_effects/impactPlank_medium_003.ogg")
var collision_audio_player: AudioStreamPlayer3D

## Represents where the players hand is in 3D space
var player_hand: Marker3D

## Cache's the velocity of the object on the previous frame
var last_velocity: Vector3 = Vector3.ZERO

## Threshold to determine if a collision was strong enough to warrant a sound effect
var contact_velocity_threshold: float = 1.0


## Runs once, after the node and all its children have entered the scene tree and are ready
func _ready() -> void:
	super()
	# Initialize Audio
	collision_audio_player = AudioStreamPlayer3D.new()
	collision_audio_player.stream = collision_sound_effect
	add_child(collision_audio_player)
	
	# Connect the body entered signal to the fire_collision method
	# Ensure contacts are reported so proper collision can be calculated
	object_ref.connect("body_entered", Callable(self, "_fire_collision"))
	object_ref.contact_monitor = true
	object_ref.max_contacts_reported = 1

## Runs once, when the player FIRST clicks on an object to interact with
func pre_interact() -> void:
	super()
	
## Run every frame while the player is interacting with this object
func interact() -> void:
	super()
	
	if not can_interact:
		return
		
	# Slowly move the object towards the players hand.
	var rigid_body_3d: RigidBody3D = object_ref as RigidBody3D
	if rigid_body_3d:
		rigid_body_3d.set_linear_velocity((_calculate_object_distance())*(5/rigid_body_3d.mass))

## Alternate interaction using secondary button
func aux_interact() -> void:
	super()
	
	if not can_interact:
		return
	
	# Throw the object in the opposite direction the player is facing
	var rigid_body_3d: RigidBody3D = object_ref as RigidBody3D
	if rigid_body_3d:
		var throw_direction: Vector3 = -player_hand.global_transform.basis.z.normalized()
		var throw_strength: float = (20.0/rigid_body_3d.mass)
		rigid_body_3d.set_linear_velocity(throw_direction*throw_strength)
		
		# Prevent the player from being able to immediately grab the object out of the air
		can_interact = false
		await get_tree().create_timer(0.5).timeout
		can_interact = true

## Called 60 frames per second
func _physics_process(_delta: float) -> void:
	last_velocity = object_ref.linear_velocity
	
## Runs once, when the player LAST interacts with an object
func post_interact() -> void:
	super()
	
## Called once, defines where objects the player grabs should float towards
func set_player_hand_position(hand: Marker3D) -> void:
	player_hand = hand
	
## Fires when a default object collides with something in the world
func _fire_collision(_node: Node) -> void:
	var impact_strength = (last_velocity - object_ref.linear_velocity).length()
	if impact_strength > contact_velocity_threshold:
		_play_collision_sound_effect()
		
## Play the collision sound effect
func _play_collision_sound_effect() -> void:
	collision_audio_player.play()
	await collision_audio_player.finished
	
## Calculate a vector from the objects current position to the players hand.
func _calculate_object_distance() -> Vector3:
	return (player_hand.global_transform.origin)-(object_ref.global_transform.origin)
