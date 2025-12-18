extends Node

@onready var interaction_controller: Node = %InteractionController
@onready var interaction_raycast: RayCast3D = %InteractionRaycast
@onready var player_camera: Camera3D = %Camera3D
@onready var hand: Marker3D = %Hand
@onready var note_hand: Marker3D = %NoteHand
@onready var item_hand: Marker3D = %ItemHand
@onready var default_reticle: TextureRect = %DefaultReticle
@onready var highlight_reticle: TextureRect = %HighlightReticle
@onready var interacting_reticle: TextureRect = %InteractingReticle
@onready var use_reticle: TextureRect = %UseReticle
@onready var interactable_check: Area3D = $"../InteractableCheck"
@onready var note_overlay: Control = %NoteOverlay
@onready var note_content: RichTextLabel = %NoteContent
@onready var inventory_controller: InventoryController = %InventoryController/InventoryUI
@onready var outline_material: Material = preload("res://materials/item_highlighter.tres")

signal invent_on_item_collected(item)
var item_equipped: bool = false
var equipped_item: Node3D
var equipped_item_ic: AbstractInteraction

@onready var sanity_controller: Node = %SanityController

var current_object: Object
var potential_object: Object
var interaction_component: Node
var note_interaction_component: Node
var note: Node3D

var is_note_overlay_display: bool = false

func _ready() -> void:
	interactable_check.body_entered.connect(_collectable_item_entered_range)
	interactable_check.body_exited.connect(_collectable_item_exited_range)
	invent_on_item_collected.connect(inventory_controller.pickup_item)
	default_reticle.position.x  = get_viewport().size.x / 2 - default_reticle.texture.get_size().x / 2
	default_reticle.position.y  = get_viewport().size.y / 2 - default_reticle.texture.get_size().y / 2
	highlight_reticle.position.x  = get_viewport().size.x / 2 - highlight_reticle.texture.get_size().x / 2
	highlight_reticle.position.y  = get_viewport().size.y / 2 - highlight_reticle.texture.get_size().y / 2
	interacting_reticle.position.x  = get_viewport().size.x / 2 - interacting_reticle.texture.get_size().x / 2
	interacting_reticle.position.y  = get_viewport().size.y / 2 - interacting_reticle.texture.get_size().y / 2
	use_reticle.position.x  = get_viewport().size.x / 2 - use_reticle.texture.get_size().x / 2
	use_reticle.position.y  = get_viewport().size.y / 2 - use_reticle.texture.get_size().y / 2

func _process(_delta: float) -> void:
	if inventory_controller.visible == false:
		# If on the previous frame, we were interacting with and object, lets keep interacting with it
		if current_object:
			if interaction_component:
				# Update reticle
				if interaction_component.is_interacting:
					default_reticle.visible = false
					highlight_reticle.visible = false
					interacting_reticle.visible = true
					use_reticle.visible = false
					
				# Limit interaction distance
				if player_camera.global_transform.origin.distance_to(interaction_raycast.get_collision_point()) > 5.0:
					interaction_component.post_interact()
					current_object = null
					_unfocus()
					return
				
				# Perform Interactions
				if Input.is_action_just_pressed("secondary"):
					interaction_component.aux_interact()
					current_object = null
					_unfocus()
				elif Input.is_action_pressed("primary"):
					interaction_component.interact()
				else:
					interaction_component.post_interact()
					current_object = null 
					_unfocus()
			else:
				current_object = null 
				_unfocus()
		else: #we werent interacting with something, lets see if we can.
			potential_object = interaction_raycast.get_collider()
			
			if potential_object and potential_object is Node:
				interaction_component = find_interaction_component(potential_object)
				if interaction_component:
					if interaction_component.can_interact == false:
						return
						
					_focus()
					if Input.is_action_just_pressed("primary"):
						current_object = potential_object
						
						if interaction_component is TypeableInteraction:
							interaction_component.set_target_button(current_object)
						
						interaction_component.pre_interact()
						
						if interaction_component is GrabbableInteraction:
							interaction_component.set_player_hand_position(hand)
				
						if interaction_component is ConsumableInteraction:
							if not interaction_component.is_connected("item_collected", Callable(self, "_on_item_collected")):
								interaction_component.connect("item_collected", Callable(self, "_on_item_collected"))
							
						if interaction_component is InspectableInteraction:
							if not interaction_component.is_connected("note_inspected", Callable(self, "on_note_inspected")):
								interaction_component.connect("note_inspected", Callable(self, "on_note_inspected"))
							
						if interaction_component is DoorInteraction:
							interaction_component.set_direction(current_object.to_local(interaction_raycast.get_collision_point()))
						
				else: # If the object we just looked at cant be interacted with, call unfocus
					current_object = null
					_unfocus()
			else:
				_unfocus()
	else:
		default_reticle.visible = false
		highlight_reticle.visible = false
		interacting_reticle.visible = false
		use_reticle.visible = false
		current_object = null
			
func _input(event: InputEvent) -> void:
	if is_note_overlay_display and event.is_action_pressed("primary"):
		_on_note_collected()
		
	if item_equipped and Input.is_action_just_pressed("primary"):
		_use_equipped_item()
		

## Determines if the object the player is interacting with should stop mouse camera movement
func isCameraLocked() -> bool:
	if interaction_component:
		if interaction_component.lock_camera and interaction_component.is_interacting:
			return true
	return false

## Called when the player is looking at an interactable objects
func _focus() -> void:
	if item_equipped:
		default_reticle.visible = false
		highlight_reticle.visible = false
		interacting_reticle.visible = false
		use_reticle.visible = true
	else:
		default_reticle.visible = false
		highlight_reticle.visible = true
		interacting_reticle.visible = false
		use_reticle.visible = false
	
## Called when the player is NOT looking at an interactable objects
func _unfocus() -> void:
	default_reticle.visible = true
	highlight_reticle.visible = false
	interacting_reticle.visible = false
	use_reticle.visible = false

## Called when the player collects an item
func _on_item_collected(item: Node):
	var ic = find_interaction_component(item)
	_add_item_to_inventory(ic.item_data)
	item.queue_free()
	
func on_note_inspected(_note: Node3D):
	note = _note
	# Reparent Note to the Hand
	if note.get_parent() != null:
		note.get_parent().remove_child(note)
	else:
		var mesh = note.find_child("MeshInstance3D", true, false)
		if mesh:
			mesh.layers = 2
		var col = note.find_child("CollisionShape3D", true, false)
		if col:
			col.get_parent().remove_child(col)
			col.queue_free()
	note_hand.add_child(note)
	note.transform.origin = note_hand.transform.origin
	note.position = Vector3(0.0,0.0,0.0)
	note.rotation_degrees = Vector3(90,10,0)
	
	note_overlay.visible = true
	is_note_overlay_display = true
	note_interaction_component = find_interaction_component(note)
	note_content.bbcode_enabled=true
	note_content.text = note_interaction_component.content
	
func on_item_equipped(item: Node3D):
		# Reparent Note to the Hand
	if item.get_parent() != null:
		item.get_parent().remove_child(item)
	else:
		var mesh = item.find_child("MeshInstance3D", true, false)
		if mesh:
			mesh.layers = 2
		var col = item.find_child("CollisionShape3D", true, false)
		if col:
			col.get_parent().remove_child(col)
			col.queue_free()
	item_hand.add_child(item)
	item.transform.origin = item_hand.transform.origin
	item.position = Vector3(0.0,0.0,0.0)
	item.rotation_degrees = Vector3(0,180,-90)
	item_equipped = true
	equipped_item = item
	equipped_item_ic = find_interaction_component(equipped_item)
	
		
func _on_note_collected():
	note_overlay.visible = false
	is_note_overlay_display = false
	if note_interaction_component.put_away_sound_effect:
		var audio_player: AudioStreamPlayer3D = AudioStreamPlayer3D.new()
		audio_player.stream = note_interaction_component.put_away_sound_effect
		add_child(audio_player)
		audio_player.play()
		note.visible = false	
		await audio_player.finished
		_add_item_to_inventory(note_interaction_component.item_data)

func _add_item_to_inventory(item_data: ItemData):
	if item_data != null:
		invent_on_item_collected.emit(item_data)
		return
				
	print("Item not found")

## Called when a collectable item is within range of the player
func _collectable_item_entered_range(body: Node3D) -> void:
	if body.name != "Player":
		var ic: AbstractInteraction = find_interaction_component(body)
		if ic and ic is ConsumableInteraction:
			var mesh: MeshInstance3D = body.find_child("MeshInstance3D", true, false)
			if mesh:
				mesh.material_overlay = outline_material	

## Called when a collectable item is NO LONGER within range of the player
func _collectable_item_exited_range(body: Node3D) -> void:
	if body.name != "Player":
		var ic: AbstractInteraction = find_interaction_component(body)
		if ic and ic is ConsumableInteraction:
			var mesh: MeshInstance3D = body.find_child("MeshInstance3D", true, false)
			if mesh:
				mesh.material_overlay = null
				
func _use_equipped_item() -> void:
	if potential_object:
		var action_data: ActionData = equipped_item_ic.item_data.action_data
		if interaction_component.use_item(action_data):
			if action_data.one_time_use:
				equipped_item.queue_free()
				equipped_item = null
				item_equipped = false
			print("item used")
			return
		else:
			# this item can not be used on this interaction
			print("nothing interesting happens")
	inventory_controller.pickup_item(equipped_item_ic.item_data)
	equipped_item.queue_free()
	equipped_item = null
	item_equipped = false
	
			
func find_interaction_component(node: Node) -> AbstractInteraction:
	while node:
		for child in node.get_children():
			if child is AbstractInteraction:
				return child
		node = node.get_parent()
	return null
