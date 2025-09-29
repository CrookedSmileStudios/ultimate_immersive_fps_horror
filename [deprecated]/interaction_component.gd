extends Node

#This is defined on individual objects in the game.

enum InteractionType {
	DEFAULT,
	DOOR,
	SWITCH,
	WHEEL,
	ITEM,
	NOTE,
	KEYPAD
}

@export var object_ref: Node3D
@export var interaction_type: InteractionType = InteractionType.DEFAULT
@export var maximum_rotation: float = 90
@export var pivot_point: Node3D
@export var nodes_to_affect: Array[Node]
@export var content: String

# Common Variables
var can_interact: bool = true
var is_interacting: bool = false
var lock_camera: bool = false
var starting_rotation: float
var player_hand: Marker3D
var camera: Camera3D
var previous_mouse_position: Vector2

# Door Variables
var door_angle: float = 0.0
var door_velocity: float = 0.0
var door_smoothing: float = 80.0
var door_input_active: bool = false
var is_front: bool
var door_opened: bool = false
var door_creak_velocity_threshold: float = 0.005 # how fast the player has to open the door for the sound to play
var shut_angle_threshold: float = 0.2            # how far the door is opened to count as "opened"
var shut_snap_range: float = 0.05                # how close to starting_rotation counts as "closed"
var creak_volume_scale: float = 1000.0           # how fast we get to max volume
var door_fade_speed: float = 1.0                 # how fast sound fades in/out
var prev_door_angle: float = 0.0                 # angle of the door on the previous frame
@export var is_locked: bool = false
var was_just_unlocked: bool = false

# Wheel Variables
var wheel_kickback: float = 0.0
var wheel_kick_intensity: float = 0.1
var wheel_rotation: float = 0.0
var wheel_creak_velocity_threshold: float = 0.005 # how fast the player has to turn the wheel for the sound to play
var wheel_fade_speed: float = 50.0                # how fast sound fades in/out
var last_wheel_angle: float = 0.0                 # angle of the wheel on the previous frame
var wheel_kickback_triggered: bool = false        # true if the player has stopped interacting and the wheel is kicking back

# Switch Variables
var switch_target_rotation: float = 0.0
var switch_lerp_speed: float = 8.0
var is_switch_snapping: bool = false
var switch_moved: bool = false
var last_switch_angle: float = 0.0                        # angle of the door on the previous frame
var switch_creak_velocity_threshold: float = 0.01
var switch_fade_speed: float = 50.0
var switch_kickback_triggered: bool = false

# Keypad Variables
var buttons: Array[StaticBody3D]
var entered_code: Array[int]
@export var correct_code: Array[int] = [5,6,7,8,9]
var max_code_length: int = 5
var screen_label: Label3D


# Signals
signal item_collected(item: Node)
signal note_collected(note: Node3D)

# SoundEffects
var primary_audio_player: AudioStreamPlayer3D
var secondary_audio_player: AudioStreamPlayer3D
var tertiary_audio_player: AudioStreamPlayer3D
var last_velocity: Vector3 = Vector3.ZERO
var contact_velocity_threshold: float = 1.0
@export var primary_se: AudioStreamOggVorbis
@export var secondary_se: AudioStreamOggVorbis
@export var tertiary_se: AudioStreamOggVorbis

func _ready() -> void:
	
	# Initialize Audio
	primary_audio_player = AudioStreamPlayer3D.new()
	primary_audio_player.stream = primary_se
	add_child(primary_audio_player)
	secondary_audio_player = AudioStreamPlayer3D.new()
	secondary_audio_player.stream = secondary_se
	add_child(secondary_audio_player)
	tertiary_audio_player = AudioStreamPlayer3D.new()
	tertiary_audio_player.stream = tertiary_se
	add_child(tertiary_audio_player)
	
	match interaction_type:
		InteractionType.DEFAULT:
			if object_ref.has_signal("body_entered"):
				object_ref.connect("body_entered", Callable(self, "_fire_default_collision"))
				object_ref.contact_monitor = true
				object_ref.max_contacts_reported = 1
		InteractionType.DOOR:
			starting_rotation = pivot_point.rotation.y
			maximum_rotation = deg_to_rad(rad_to_deg(starting_rotation)+maximum_rotation)
		InteractionType.SWITCH:
			starting_rotation = object_ref.rotation.z
			maximum_rotation = deg_to_rad(rad_to_deg(starting_rotation)+maximum_rotation)
		InteractionType.WHEEL:
			starting_rotation = object_ref.rotation.z
			maximum_rotation = deg_to_rad(rad_to_deg(starting_rotation)+maximum_rotation)
			camera = get_tree().get_current_scene().find_child("Camera3D", true, false)
		InteractionType.NOTE:
			content = content.replace("\\n", "\n")
		InteractionType.KEYPAD:
			screen_label = get_parent().get_node_or_null("%Screen")
			for node in get_parent().get_children():
				if node is StaticBody3D:
					buttons.append(node)
	
## Runs once, when the player FIRST clicks on an object to interact with
func preInteract(hand: Marker3D, target: Node = null) -> void:
	is_interacting = true
	match interaction_type:
		InteractionType.DEFAULT:
			player_hand = hand
		InteractionType.DOOR:
			lock_camera = true
		InteractionType.SWITCH:
			lock_camera = true
			switch_moved = false
		InteractionType.WHEEL:
			lock_camera = true
			previous_mouse_position = get_viewport().get_mouse_position()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		InteractionType.KEYPAD:
			_press_button(target)
		
	
## Run every frame while the player is interacting with this object
func interact() -> void:
	if not can_interact:
		return
		
	match interaction_type:
		InteractionType.DEFAULT:
			_default_interact()
		InteractionType.ITEM:
			_collect_item()
		InteractionType.NOTE:
			_collect_note()

## Alternate interaction using secondary button
func auxInteract() -> void:
	if not can_interact:
		return
		
	match interaction_type:
		InteractionType.DEFAULT:
			_default_throw()
	
## Runs once, when the player LAST interacts with an object
func postInteract() -> void:
	is_interacting = false
	lock_camera = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	match interaction_type:
		InteractionType.SWITCH:
			var percent := (object_ref.rotation.z - starting_rotation) / (maximum_rotation - starting_rotation)
			if percent < 0.3:
				switch_target_rotation = starting_rotation
				is_switch_snapping = true
			elif percent > 0.7:
				switch_target_rotation = maximum_rotation
				is_switch_snapping = true
		InteractionType.WHEEL:
			wheel_kickback = -sign(wheel_rotation) * wheel_kick_intensity

func _physics_process(delta: float) -> void:
	match interaction_type:
		InteractionType.DEFAULT:
			if object_ref:
				last_velocity = object_ref.linear_velocity

func _process(delta: float) -> void:
	match interaction_type:
		InteractionType.DOOR:
			if was_just_unlocked:
				door_velocity = 0.0
				door_input_active = false
				door_angle = starting_rotation
				pivot_point.rotation.y = starting_rotation
				was_just_unlocked = false
			else:
				if not door_input_active:
					door_velocity = lerp(door_velocity, 0.0, delta * 4.0)
				
				door_angle += door_velocity
				
				if is_locked:
					var lock_wiggle: float = 0.02
					door_angle = clamp(door_angle, starting_rotation, starting_rotation+lock_wiggle)
					pivot_point.rotation.y = door_angle
					
					if door_input_active and tertiary_se and not tertiary_audio_player.playing and not prev_door_angle == door_angle:
						tertiary_audio_player.play()
						door_input_active = false
				else:
					door_angle = clamp(door_angle, starting_rotation, maximum_rotation)
					pivot_point.rotation.y = door_angle
					door_input_active = false

					if prev_door_angle == door_angle:
						stop_door_sounds(delta)
					else:
						update_door_sounds(delta)
					
				prev_door_angle = door_angle
		InteractionType.WHEEL:
			if is_interacting:
				update_wheel_sounds(delta)
			else:
				stop_wheel_sounds(delta)
			if abs(wheel_kickback) > 0.001:
				wheel_rotation += wheel_kickback
				wheel_kickback = lerp(wheel_kickback, 0.0, delta * 6.0)
				
				var min_wheel_rotation = starting_rotation / 0.1
				var max_wheel_rotation = maximum_rotation / 0.1
				wheel_rotation = clamp(wheel_rotation, min_wheel_rotation, max_wheel_rotation)
				
				object_ref.rotation.z = wheel_rotation * 0.1
				var percentage = (object_ref.rotation.z - starting_rotation) / (maximum_rotation - starting_rotation)
				notify_nodes(percentage)
				
				# Detect start of kickback (player just released the wheel)
				if not is_interacting and not wheel_kickback_triggered and abs(wheel_kickback) > 0.01:
					wheel_kickback_triggered = true

					if secondary_se:
						secondary_audio_player.stop()   # reset to avoid overlap
						secondary_audio_player.volume_db = -0.0
						secondary_audio_player.play()
			else:
				wheel_kickback_triggered = false
		InteractionType.SWITCH:
			if is_interacting:
				update_switch_sounds(delta)
			else:
				stop_switch_sounds(delta) 
			if is_switch_snapping:
				# Trigger the kickback and play the sound only once at start
				if not switch_kickback_triggered:
					switch_kickback_triggered = true
					if secondary_se and not secondary_audio_player.playing:
						secondary_audio_player.stop()
						secondary_audio_player.volume_db = 0.0
						secondary_audio_player.play()
				object_ref.rotation.z = lerp(object_ref.rotation.z, switch_target_rotation, delta * switch_lerp_speed)

				# Stop snapping when close enough
				if abs(object_ref.rotation.z - switch_target_rotation) < 0.01:
					object_ref.rotation.z = switch_target_rotation
					is_switch_snapping = false

				var percentage: float = (object_ref.rotation.z - starting_rotation) / (maximum_rotation - starting_rotation)
				notify_nodes(percentage)
			else:
				switch_kickback_triggered = false

func _input(event: InputEvent) -> void:
	if is_interacting:
		match interaction_type:
			InteractionType.DOOR:
				if event is InputEventMouseMotion:
					door_input_active = true
					var delta: float = -event.relative.y * 0.001
					if not is_front:
						delta = -delta
					# Simulate resistance to small motions
					if abs(delta) < 0.01:
						delta *= 0.25
					# Smooth velocity blending
					door_velocity = lerp(door_velocity, delta, 1.0 / door_smoothing)
			InteractionType.SWITCH:
				if event is InputEventMouseMotion:
					var prev_angle = object_ref.rotation.z
					object_ref.rotate_z(event.relative.y * .001)
					object_ref.rotation.z = clamp(object_ref.rotation.z, starting_rotation, maximum_rotation)
					var percentage: float = (object_ref.rotation.z - starting_rotation) / (maximum_rotation - starting_rotation)
					
					if abs(object_ref.rotation.z - prev_angle) > 0.01:
						switch_moved = true
						
					notify_nodes(percentage)
			InteractionType.WHEEL:
				if event is InputEventMouseMotion:
					var mouse_position: Vector2 = event.position
					if calculate_cross_product(mouse_position) > 0:
						wheel_rotation += 0.1
					else:
						wheel_rotation -= 0.1
						
					object_ref.rotation.z = wheel_rotation *.1
					object_ref.rotation.z = clamp(object_ref.rotation.z, starting_rotation, maximum_rotation)
					var percentage: float = (object_ref.rotation.z - starting_rotation) / (maximum_rotation - starting_rotation)
						
					previous_mouse_position = mouse_position
					
					# Clamp internal wheel_rotation using derived limits
					var min_wheel_rotation = starting_rotation / 0.1
					var max_wheel_rotation = maximum_rotation / 0.1
					wheel_rotation = clamp(wheel_rotation, min_wheel_rotation, max_wheel_rotation)

					notify_nodes(percentage)

## Default Interaction with objects that can be picked up
func _default_interact() -> void:
	var object_current_position: Vector3 = object_ref.global_transform.origin
	var player_hand_position: Vector3 = player_hand.global_transform.origin
	var object_distance: Vector3 = player_hand_position-object_current_position
	
	var rigid_body_3d: RigidBody3D = object_ref as RigidBody3D
	if rigid_body_3d:
		rigid_body_3d.set_linear_velocity((object_distance)*(5/rigid_body_3d.mass))
	
## Alternate Interaction with objects that can be picked up
func _default_throw() -> void:
	var object_current_position: Vector3 = object_ref.global_transform.origin
	var player_hand_position: Vector3 = player_hand.global_transform.origin
	var object_distance: Vector3 = player_hand_position-object_current_position
	
	var rigid_body_3d: RigidBody3D = object_ref as RigidBody3D
	if rigid_body_3d:
		var throw_direction: Vector3 = -player_hand.global_transform.basis.z.normalized()
		var throw_strength: float = (20.0/rigid_body_3d.mass)
		rigid_body_3d.set_linear_velocity(throw_direction*throw_strength)
		
		can_interact = false
		await get_tree().create_timer(2.0).timeout
		can_interact = true
	
## True if we are looking at the front of an object, false otherwise
func set_direction(_normal: Vector3) -> void:
	if _normal.z > 0:
		is_front = true
	else:
		is_front = false

## Iterates over a list of nodes that can be interacted with and executes their respective logic
func notify_nodes(percentage: float) -> void:
	for node in nodes_to_affect:
		if node and node.has_method("execute"): # 🚨 New: Ensure node is not null
			node.call("execute", percentage)
	
## Uses mouse position to determine if the player is moving their mouse in a clockwise or counter-clockwise motion
func calculate_cross_product(_mouse_position: Vector2) -> float:
	var center_position = camera.unproject_position(object_ref.global_transform.origin)
	var vector_to_previous = previous_mouse_position - center_position
	var vector_to_current = _mouse_position - center_position
	var cross_product = vector_to_current.x * vector_to_previous.y - vector_to_current.y * vector_to_previous.x
	return cross_product

## Fires a signal that a player has picked up a collectible item
func _collect_item() -> void:
	emit_signal("item_collected", get_parent())
	await _play_primary_sound_effect(false, false)
	get_parent().queue_free()
	
## Fires a signal that a player has picked up a note/log
func _collect_note() -> void:
	var col = get_parent().find_child("CollisionShape3D", true, false)
	var mesh = get_parent().find_child("MeshInstance3D", true, false)
	if mesh:
		mesh.layers = 2
	if col:
		col.get_parent().remove_child(col)
		col.queue_free()
	_play_primary_sound_effect(true, false)
	emit_signal("note_collected", get_parent())

## Default method to play the primary sound effect of a given object
func _play_primary_sound_effect(visible: bool, interact: bool) -> void:
	if primary_se:
		primary_audio_player.play()
		get_parent().visible = visible
		self.can_interact = interact
		await primary_audio_player.finished
		
## Fires when a default object collides with something in the world
func _fire_default_collision(node: Node) -> void:
	var impact_strength = (last_velocity - object_ref.linear_velocity).length()
	if impact_strength > contact_velocity_threshold:
		_play_primary_sound_effect(true, true)

## Fires when the player is interacting with a door
func update_door_sounds(delta: float) -> void:
	# --- CREAK LOGIC ---
	# Get the velocity of the door movement in this given frame.
	# The volume should be relative to how fast/slow the playeris moving the door
	var velocity_amount: float = abs(door_velocity)
	var target_volume: float = 0.0

	# Only set target volume if we pass the threshold
	if velocity_amount > door_creak_velocity_threshold and door_opened:
		target_volume = clamp((velocity_amount - door_creak_velocity_threshold) * creak_volume_scale, 0.0, 1.0)

	# Start playing if not already
	if not primary_audio_player.playing and primary_se and target_volume > 0.0:
		primary_audio_player.volume_db = -15.0  # start silent
		primary_audio_player.play()
		print("PLAY")

	# Smooth fade towards target volume (even if target is 0 → fade out)
	if primary_audio_player.playing:
		var current_vol = db_to_linear(primary_audio_player.volume_db)
		var new_vol = lerp(current_vol, target_volume, delta * door_fade_speed)
		primary_audio_player.volume_db = linear_to_db(clamp(new_vol, 0.0, 3.0))

	# --- SHUT LOGIC ---
	# Check if the player opened the door.
	if abs(door_angle - starting_rotation) > shut_angle_threshold:
		door_opened = true
	
	# If the door was previosuly opened and the player is now shutting it
	if door_opened and abs(door_angle - starting_rotation) < shut_snap_range:
		if secondary_se:
			secondary_audio_player.volume_db = -8.0
			secondary_audio_player.play()
			primary_audio_player.stop()
			print("stop!")
		door_opened = false
		
func update_switch_sounds(delta: float) -> void:
	# --- Calculate angular speed ---
	var angular_speed = abs(object_ref.rotation.z - last_switch_angle) / max(delta, 0.0001)
	last_switch_angle = object_ref.rotation.z

	# --- Determine target volume based on threshold ---
	var target_volume: float = 0.0
	if angular_speed > switch_creak_velocity_threshold:
		target_volume = clamp((angular_speed - switch_creak_velocity_threshold) * creak_volume_scale, 0.0, 1.5)

	# --- Start pull sound if needed ---
	if not primary_audio_player.playing and primary_se and target_volume > 0:
		primary_audio_player.volume_db = -15.0
		primary_audio_player.play()
		
	# --- Smooth fade in/out ---
	if primary_audio_player.playing:
		var current_vol = db_to_linear(primary_audio_player.volume_db)
		var new_vol = lerp(current_vol, target_volume, delta * switch_fade_speed)
		primary_audio_player.volume_db = linear_to_db(clamp(new_vol, 0.0, 1.5))

	# Play "thunk" when snapping completes
	if switch_moved:
		if abs(object_ref.rotation.z - maximum_rotation) < 0.01 or abs(object_ref.rotation.z - starting_rotation) < 0.01:
			if secondary_se:
				secondary_audio_player.volume_db = -0.0
				secondary_audio_player.play()
			switch_moved = false  # reset after playing

func stop_switch_sounds(delta: float) -> void:
	if primary_audio_player.playing:
		var current_vol = db_to_linear(primary_audio_player.volume_db)
		var new_vol = lerp(current_vol, 0.0, delta * switch_fade_speed)
		primary_audio_player.volume_db = linear_to_db(clamp(new_vol, 0.0, 1.0))

		# Stop completely once inaudible
		if new_vol < 0.001:
			primary_audio_player.stop()	

func update_wheel_sounds(delta: float) -> void:
	# --- Calculate angular speed ---
	var angular_speed = abs(object_ref.rotation.z - last_wheel_angle) / max(delta, 0.0001)
	last_wheel_angle = object_ref.rotation.z

	# --- Determine target volume only if above threshold ---
	var target_volume: float = 0.0
	if angular_speed > wheel_creak_velocity_threshold:
		target_volume = clamp((angular_speed - wheel_creak_velocity_threshold) * creak_volume_scale, 0.0, 1.0)

	# --- Start looping creak if not playing and needed ---
	if not primary_audio_player.playing and primary_se and target_volume > 0:
		primary_audio_player.volume_db = -15.0
		primary_audio_player.play()

	# --- Smooth fade in/out ---
	if primary_audio_player.playing:
		var current_vol = db_to_linear(primary_audio_player.volume_db)
		var new_vol = lerp(current_vol, target_volume, delta * wheel_fade_speed)
		primary_audio_player.volume_db = linear_to_db(clamp(new_vol, 0.0, 1.0))

		# Stop sound if it has faded out completely
		if new_vol < 0.001 and target_volume == 0.0:
			primary_audio_player.stop()

func stop_wheel_sounds(delta: float) -> void:
	if primary_audio_player.playing:
		var current_vol = db_to_linear(primary_audio_player.volume_db)
		var new_vol = lerp(current_vol, 0.0, delta * wheel_fade_speed)
		primary_audio_player.volume_db = linear_to_db(clamp(new_vol, 0.0, 1.0))

		# Stop completely once inaudible
		if new_vol < 0.001:
			primary_audio_player.stop()

func stop_door_sounds(delta: float) -> void:
	if primary_audio_player.playing:
		var current_vol = db_to_linear(primary_audio_player.volume_db)
		var new_vol = lerp(current_vol, 0.0, delta * door_fade_speed)
		primary_audio_player.volume_db = linear_to_db(clamp(new_vol, 0.0, 1.0))

		# Stop completely once inaudible
		if new_vol < 0.001:
			primary_audio_player.stop()

func _press_button(target: Node) -> void:
	if target == null:
		return
		
	if target in buttons:
		var tween := create_tween()
		tween.tween_property(target, "position:z", 0.02, 0.1)
		tween.tween_property(target, "position:z", 0.0, 0.1)
		
	primary_audio_player.play()
	
	match target.name:
		"sbClear":
			entered_code.clear()
			screen_label.text = "-----"
			screen_label.modulate = Color.WHITE
			
		"sbOK":
			if entered_code == correct_code:
				screen_label.text = "ENTER"
				screen_label.modulate = Color.GREEN
				tertiary_audio_player.play()
				for node in nodes_to_affect:
					if node and node.has_method("unlock"):
						node.call("unlock")
			else:
				screen_label.text = "ERROR"
				screen_label.modulate = Color.RED
				secondary_audio_player.play()
				
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
			
func unlock() -> void:
	is_locked = false
	was_just_unlocked = true
	
	match InteractionType:
		InteractionType.DOOR:
			door_velocity = 0.0
			door_input_active = false
			door_angle = starting_rotation
			pivot_point.rotation.y = starting_rotation
