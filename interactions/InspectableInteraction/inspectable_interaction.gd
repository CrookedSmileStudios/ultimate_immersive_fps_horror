class_name InspectableInteraction
extends AbstractInteraction

"""
InspectableInteraction handles objects that the player can pick up and examine, such as notes or documents.  
It extends AbstractInteraction to reuse common interaction logic while adding inspection-specific behavior 
like playing a sound when the object is picked up for inspection put away after inspection, removing the 
object's collision and adjusting its rendering layer to prevent clipping with walls, emitting a 
`note_collected`  signal to notify the game that the object is being inspected, and preventing further
interaction while the object is being held by the player

This class is suitable for any inspectable object that the player can pick up to read, examine, or otherwise interact 
with without immediately adding it to their inventory.
"""

## Text content for a note
@export var content: String
## Sound effect to play when the player picks up this object to inspect
@export var pickup_sound_effect: AudioStreamOggVorbis = preload("res://assets/sound_effects/drawKnife2.ogg")
var pickup_audio_player: AudioStreamPlayer3D

## Sound effect to play when the player puts this object away to be done inspecting
@export var put_away_sound_effect: AudioStreamOggVorbis = preload("res://assets/sound_effects/drawKnife3.ogg")

## Notify the player that this is being picked up to be inspected
signal note_collected(note: Node3D)


## Runs once, after the node and all its children have entered the scene tree and are ready
func _ready() -> void:
	super()
	# Initialize Audio
	pickup_audio_player = AudioStreamPlayer3D.new()
	pickup_audio_player.stream = pickup_sound_effect
	add_child(pickup_audio_player)
	
	# Replace newline characters to ensure formatting displays as expected
	content = content.replace("\\n", "\n")

## Runs once, when the player FIRST clicks on an object to interact with
func pre_interact() -> void:
	super()
	
## Run every frame while the player is interacting with this object
func interact() -> void:
	super()
	
	if not can_interact:
		return
		
	# Change the mesh to render on layer 2; this prevents it from clipping with walls
	var mesh = get_parent().find_child("MeshInstance3D", true, false)
	if mesh:
		mesh.layers = 2
	
	# Remove collision from the note so it doesnt interfere with player movement
	var col = get_parent().find_child("CollisionShape3D", true, false)
	if col:
		col.get_parent().remove_child(col)
		col.queue_free()
	_play_pickup_sound_effect()
	emit_signal("note_collected", get_parent())
	
## Alternate interaction using secondary button
func aux_interact() -> void:
	super()
	
## Runs once, when the player LAST interacts with an object
func post_interact() -> void:
	super()
	
## Play the pickup to inspect sound effect
func _play_pickup_sound_effect() -> void:
	pickup_audio_player.play()
	
	# The inspectable is in the players hand, we dont want a strange situation where the player can still
	# interact with the object in this code.
	self.can_interact = false
	
	await pickup_audio_player.finished
