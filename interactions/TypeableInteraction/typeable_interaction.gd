class_name TypeableInteraction
extends AbstractInteraction

"""
KeypadInteraction handles keypad objects that the player can interact with to enter codes.  
It extends AbstractInteraction to reuse common interaction logic while adding keypad specific
 behavior, including pressing buttons with visual feedback, playing sound effects for button 
presses as well as for correct and incorrect codes, storing and validating entered codes against 
the correct combination, and triggering events or unlocking objects when the correct code is entered.

This class is suitable for any keypad or combination lock object in the game that requires code 
entry to activate or unlock linked objects.
"""

## The correct code of the keypad
@export var correct_code: Array[int] = [5,6,7,8,9]

## Sound effect to play when a button on the keypad is pressed
@export var button_press_sound_effect: AudioStreamOggVorbis = preload("res://assets/sound_effects/keypad_press.ogg")
var button_press_audio_player: AudioStreamPlayer3D

## Sound effect to play when the correct code is entered
@export var correct_code_sound_effect: AudioStreamOggVorbis = preload("res://assets/sound_effects/keypad_success.ogg")
var correct_code_audio_player: AudioStreamPlayer3D

## Sound effect to play when the wrong code is entered
@export var wrong_code_sound_effect: AudioStreamOggVorbis = preload("res://assets/sound_effects/keypad_failure.ogg")
var wrong_code_audio_player: AudioStreamPlayer3D

var buttons: Array[StaticBody3D]
var entered_code: Array[int]
var max_code_length: int = 5
var screen_label: Label3D
var target_button: Node3D


## Runs once, after the node and all its children have entered the scene tree and are ready
func _ready() -> void:
	super()
	# Initialize Audio
	button_press_audio_player = AudioStreamPlayer3D.new()
	button_press_audio_player.stream = button_press_sound_effect
	add_child(button_press_audio_player)
	correct_code_audio_player = AudioStreamPlayer3D.new()
	correct_code_audio_player.stream = correct_code_sound_effect
	add_child(correct_code_audio_player)
	wrong_code_audio_player = AudioStreamPlayer3D.new()
	wrong_code_audio_player.stream = wrong_code_sound_effect
	add_child(wrong_code_audio_player)
	
	# Initialize Screen
	screen_label = get_parent().get_node_or_null("%Screen")
	
	# Populate button array
	for node in get_parent().get_children():
		if node is StaticBody3D:
			buttons.append(node)

## Runs once, when the player FIRST clicks on an object to interact with
func pre_interact() -> void:
	super()
	
	# Button press should only happen one time per click
	_press_button(target_button)
	
## Run every frame while the player is interacting with this object
func interact() -> void:
	super()
	
## Alternate interaction using secondary button
func aux_interact() -> void:
	super()
	
## Runs once, when the player LAST interacts with an object
func post_interact() -> void:
	super()
	
## Caches the button we are trying to press
func set_target_button(target: Node3D) -> void:
	target_button = target

func _press_button(target: Node) -> void:
	if target == null:
		return
		
	if target in buttons:
		var tween := create_tween()
		tween.tween_property(target, "position:z", 0.02, 0.1)
		tween.tween_property(target, "position:z", 0.0, 0.1)
		
	button_press_audio_player.play()
	
	match target.name:
		"sbClear":
			entered_code.clear()
			screen_label.text = "-----"
			screen_label.modulate = Color.WHITE
			
		"sbOK":
			if entered_code == correct_code:
				screen_label.text = "ENTER"
				screen_label.modulate = Color.GREEN
				correct_code_audio_player.play()
				for node in nodes_to_affect:
					if node and node.has_method("unlock"):
						node.call("unlock")
			else:
				screen_label.text = "ERROR"
				screen_label.modulate = Color.RED
				wrong_code_audio_player.play()
				
			entered_code.clear()
			
		_:
			var num = str(target.name).substr(2).to_int()
			if entered_code.size() < max_code_length:
				entered_code.append(num)
				var text: String = ""
				for n in entered_code:
					text += str(n)
				screen_label.text = text
				screen_label.modulate = Color.WHITE
			else:
				print("Code is Full")
