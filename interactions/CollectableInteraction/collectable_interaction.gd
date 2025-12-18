class_name CollectableInteraction
extends AbstractInteraction

"""
CollectableInteraction is a base interaction component meant for objects
that can be picked up and stored in the player's inventory.  

This includes items like notes, consumables, keys, or any other
pickupable object in the world.  

It provides a place to store relevant action data (e.g., type, 
one-time use, modifiers) and can be attached to the item prefab
to define how the inventory should handle it when collected.
"""

## Sound effect to play when the player collects this item
@export var collect_sound_effect: AudioStreamOggVorbis
var collect_audio_player: AudioStreamPlayer3D

@export var item_data: ItemData

## Runs once, after the node and all its children have entered the scene tree and are ready
func _ready() -> void:
	super()

	collect_audio_player = AudioStreamPlayer3D.new()
	collect_audio_player.stream = collect_sound_effect
	add_child(collect_audio_player)
	
	var scene_path = get_parent().scene_file_path
	item_data.item_model_prefab = load(scene_path)

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

func _play_collect_sound_effect() -> void:
	if collect_audio_player:
		if collect_audio_player.stream:
			collect_audio_player.play()

	self.can_interact = false
	
	await collect_audio_player.finished
