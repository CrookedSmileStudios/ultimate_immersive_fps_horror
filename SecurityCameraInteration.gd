class_name SecurityCameraInteraction
extends RotatableInteraction

## Sound effect to play when the door shuts
@export var player_detected_sound_effect: AudioStreamOggVorbis = preload("res://assets/sound_effects/DoorClose2.ogg")
var shut_audio_player: AudioStreamPlayer3D

## Sound effect to play when the door is locked and the player interacts with the door
@export var alarm_sound_effect: AudioStreamOggVorbis = preload("res://assets/sound_effects/DoorLocked.ogg")
var locked_audio_player: AudioStreamPlayer3D

@export var is_hackable: bool = true
