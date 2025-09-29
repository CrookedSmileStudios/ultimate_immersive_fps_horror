class_name CollectableInteraction
extends AbstractInteraction

"""
CollectableInteraction handles objects that the player can pick up in the world.  
It extends AbstractInteraction to reuse common interaction logic while adding 
pickup-specific behavior like sound effects when the item is picked up, emitting 
an `item_collected` signal to notify inventory systems, preventing further interaction 
while the item is being collected, and removing the item from the scene once the 
collection is complete

This class is suitable for any item the player can grab and add to their inventory 
or trigger collection events.
"""

## Sound effect to play when the player collects this item
@export var collect_item_sound_effect: AudioStreamOggVorbis = preload("res://assets/sound_effects/handleCoins2.ogg")
var collect_item_audio_player: AudioStreamPlayer3D

## Notify the player / inventory manager that this item was picked up
signal item_collected(item: Node)


## Runs once, after the node and all its children have entered the scene tree and are ready
func _ready() -> void:
	super()
	# Initialize Audio
	collect_item_audio_player = AudioStreamPlayer3D.new()
	collect_item_audio_player.stream = collect_item_sound_effect
	add_child(collect_item_audio_player)

## Runs once, when the player FIRST clicks on an object to interact with
func pre_interact() -> void:
	super()
	
## Run every frame while the player is interacting with this object
func interact() -> void:
	super()
	
	if not can_interact:
		return
		
	emit_signal("item_collected", get_parent())
	await _play_collect_item_sound_effect()
	get_parent().queue_free()
	
## Alternate interaction using secondary button
func aux_interact() -> void:
	super()
	
## Runs once, when the player LAST interacts with an object
func post_interact() -> void:
	super()
	
## Play the collection sound effect
func _play_collect_item_sound_effect() -> void:
	collect_item_audio_player.play()
	
	# The collectible needs to finish playing its sound before it can call queue_free(), otherwise the sound effect cuts off
	# Therefore we just want to set the object to be invisible and not interactable
	get_parent().visible = false
	self.can_interact = false
	
	await collect_item_audio_player.finished
