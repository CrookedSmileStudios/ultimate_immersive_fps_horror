class_name EquippableInteraction
extends CollectableInteraction

"""
ConsumableInteraction handles objects that the player can pick up in the world.  
It extends AbstractInteraction to reuse common interaction logic while adding 
pickup-specific behavior like sound effects when the item is picked up, emitting 
an `item_collected` signal to notify inventory systems, preventing further interaction 
while the item is being collected, and removing the item from the scene once the 
collection is complete

This class is suitable for any item the player can grab and add to their inventory 
or trigger collection events.
"""

## Notify the player / inventory manager that this item was picked up
signal item_collected(item: Node)

## Runs once, after the node and all its children have entered the scene tree and are ready
func _ready() -> void:
	super()
	# Initialize Audio
	collect_audio_player = AudioStreamPlayer3D.new()
	collect_sound_effect = load("res://assets/sound_effects/handleCoins2.ogg")
	# TODO: Make this spawn where the item is being picked up from
	collect_audio_player.stream = collect_sound_effect
	add_child(collect_audio_player)

## Runs once, when the player FIRST clicks on an object to interact with
func pre_interact() -> void:
	super()
	
## Run every frame while the player is interacting with this object
func interact() -> void:
	super()
	
	if not can_interact:
		return
	
	await _play_collect_sound_effect()
	emit_signal("item_collected", get_parent())
	
## Alternate interaction using secondary button
func aux_interact() -> void:
	super()
	
## Runs once, when the player LAST interacts with an object
func post_interact() -> void:
	get_parent().visible = false
	super()
	
