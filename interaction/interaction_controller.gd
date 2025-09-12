extends Node

@onready var interaction_controller: Node = %InteractionController
@onready var interaction_raycast: RayCast3D = %InteractionRaycast
@onready var player_camera: Camera3D = %Camera3D
@onready var hand: Marker3D = %Hand
@onready var note_hand: Marker3D = %NoteHand
@onready var default_reticle: TextureRect = %DefaultReticle
@onready var highlight_reticle: TextureRect = %HighlightReticle
@onready var interacting_reticle: TextureRect = %InteractingReticle
@onready var interactable_check: Area3D = $"../InteractableCheck"
@onready var note_overlay: Control = %NoteOverlay
@onready var note_content: RichTextLabel = %NoteContent

@onready var outline_material: Material = preload("res://materials/item_highlighter.tres")

var current_object: Object
var last_potential_object: Object
var interaction_component: Node
var note_interaction_component: Node

var is_note_overlay_display: bool = false

func _ready() -> void:
	interactable_check.body_entered.connect(_collectible_item_entered_range)
	interactable_check.body_exited.connect(_collectible_item_exited_range)
	default_reticle.position.x  = get_viewport().size.x / 2 - default_reticle.texture.get_size().x / 2
	default_reticle.position.y  = get_viewport().size.y / 2 - default_reticle.texture.get_size().y / 2
	highlight_reticle.position.x  = get_viewport().size.x / 2 - highlight_reticle.texture.get_size().x / 2
	highlight_reticle.position.y  = get_viewport().size.y / 2 - highlight_reticle.texture.get_size().y / 2
	interacting_reticle.position.x  = get_viewport().size.x / 2 - interacting_reticle.texture.get_size().x / 2
	interacting_reticle.position.y  = get_viewport().size.y / 2 - interacting_reticle.texture.get_size().y / 2

func _process(delta: float) -> void:
	# If on the previous frame, we were interacting with and object, lets keep interacting with it
	if current_object:
		if interaction_component:
			# Update reticle
			if interaction_component.is_interacting:
				default_reticle.visible = false
				highlight_reticle.visible = false
				interacting_reticle.visible = true
			
			# Limit interaction distance
			if player_camera.global_transform.origin.distance_to(current_object.global_transform.origin) > 3.0:
				interaction_component.postInteract()
				current_object = null
				_unfocus()
				return
			
			# Perform Interactions
			if Input.is_action_just_pressed("secondary"):
				interaction_component.auxInteract()
				current_object = null
				_unfocus()
			elif Input.is_action_pressed("primary"):
				interaction_component.interact()
			else:
				interaction_component.postInteract()
				current_object = null 
				_unfocus()
		else:
			current_object = null 
			_unfocus()
	else: #we werent interacting with something, lets see if we can.
		var potential_object: Object = interaction_raycast.get_collider()
		
		if potential_object and potential_object is Node:
			var node: Node = potential_object
			interaction_component = null
			while node:
				interaction_component = node.get_node_or_null("InteractionComponent")
				if interaction_component:
					break
				node = node.get_parent()
			if interaction_component:
				if interaction_component.can_interact == false:
					return
					
				last_potential_object = current_object
				_focus()
				if Input.is_action_just_pressed("primary"):
					current_object = potential_object
					interaction_component.preInteract(hand, current_object)
					
					if interaction_component.interaction_type == interaction_component.InteractionType.ITEM:
						interaction_component.connect("item_collected", Callable(self, "_on_item_collected"))
					
					if interaction_component.interaction_type == interaction_component.InteractionType.NOTE:
						interaction_component.connect("note_collected", Callable(self, "_on_note_collected"))
						
					if interaction_component.interaction_type == interaction_component.InteractionType.DOOR:
						interaction_component.set_direction(current_object.to_local(interaction_raycast.get_collision_point()))
			else: # If the object we just looked at cant be interacted with, call unfocus
				current_object = null
				_unfocus()
		else:
			_unfocus()
			
func _input(event: InputEvent) -> void:
	if is_note_overlay_display and event.is_action_pressed("primary"):
		note_overlay.visible = false
		is_note_overlay_display = false
		var children = note_hand.get_children()
		for child in children:
			#note_interaction_component.secondary_audio_player.play()
			if note_interaction_component.secondary_se:
				note_interaction_component.secondary_audio_player.play()
				child.visible = false
				await note_interaction_component.secondary_audio_player.finished
			child.queue_free()

## Determines if the object the player is interacting with should stop mouse camera movement
func isCameraLocked() -> bool:
	if interaction_component:
		if interaction_component.lock_camera and interaction_component.is_interacting:
			return true
	return false

## Called when the player is looking at an interactable objects
func _focus() -> void:
	default_reticle.visible = false
	highlight_reticle.visible = true
	interacting_reticle.visible = false
	
## Called when the player is NOT looking at an interactable objects
func _unfocus() -> void:
	default_reticle.visible = true
	highlight_reticle.visible = false
	interacting_reticle.visible = false

## Called when the player collects an item
func _on_item_collected(item: Node):
	# TODO: INVENTORY SYSTEM would handle storing this item here.
	print("Player Collected: ", item)
	
	
func _on_note_collected(note: Node3D):
	# Reparent Note to the Hand
	note.get_parent().remove_child(note)
	note_hand.add_child(note)
	note.transform.origin = note_hand.transform.origin
	note.position = Vector3(0.0,0.0,0.0)
	note.rotation_degrees = Vector3(90,10,0)
	note_overlay.visible = true
	is_note_overlay_display = true
	note_interaction_component = note.get_node_or_null("InteractionComponent")
	note_content.bbcode_enabled=true
	note_content.text = note_interaction_component.content

## Called when a collectible item is within range of the player
func _collectible_item_entered_range(body: Node3D) -> void:
	# TODO: Use Collision layers to ignore collisions with the player
	if body.name != "Player":
		var ic = body.get_node_or_null("InteractionComponent")
		if ic and ic.interaction_type == ic.InteractionType.ITEM:
			var mesh: MeshInstance3D = body.find_child("MeshInstance3D", true, false)
			mesh.material_overlay = outline_material

## Called when a collectible item is NO LONGER within range of the player
func _collectible_item_exited_range(body: Node3D) -> void:
	# TODO: Use Collision layers to ignore collisions with the player
	if body.name != "Player":
		var mesh: MeshInstance3D = body.find_child("MeshInstance3D", true, false)
		if mesh:
			mesh.material_overlay = null
