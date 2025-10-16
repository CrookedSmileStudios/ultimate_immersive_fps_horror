extends CharacterBody3D

@onready var head: Node3D = %Head
@onready var eyes: Node3D = %Eyes
@onready var camera_3d: Camera3D = %Camera3D
@onready var standing_collision_shape: CollisionShape3D = $StandingCollisionShape
@onready var crouching_collision_shape: CollisionShape3D = $CrouchingCollisionShape
@onready var standup_check: RayCast3D = $StandupCheck
@onready var interaction_controller: Node = %InteractionController
@onready var footsteps_se: AudioStreamPlayer3D = %Footsteps
@onready var jump_se: AudioStreamPlayer3D = %Jump
@onready var note_camera: Camera3D = %NoteCamera

# Note sway variables
@onready var note_hand: Marker3D = %NoteHand
@export var note_sway_amount: float = .1

# Movement Variables
const walking_speed: float = 3.0
const sprinting_speed: float = 5.0
const crouching_speed: float = 1.0
const crouching_depth: float = -0.9
const jump_velocity: float = 4.0
var current_speed: float = 3.0
var moving: bool = false
var input_dir: Vector2 = Vector2.ZERO
var direction: Vector3 = Vector3.ZERO
var lerp_speed: float = 10.0
var mouse_input: Vector2
var is_in_air: bool = false

# Player Settings
var base_fov: float = 90.0
var normal_sensitivity: float = 0.2
var current_sensitivity: float = normal_sensitivity
var sensitivity_restore_speed: float = 5.0  # tweak for smoothness
var sensitivity_fading_in: bool = false

# State Machine
enum PlayerState {
	IDLE_STAND,
	IDLE_CROUCH,
	CROUCHING,
	WALKING,
	SPRINTING,
	AIR
	}
var player_state: PlayerState = PlayerState.IDLE_STAND

# Headbobbing Vars
const head_bobbing_sprinting_speed: float = 22.0
const head_bobbing_walking_speed: float = 14.0
const head_bobbing_crouching_speed: float = 10.0
const head_bobbing_sprinting_intensity: float = 0.2
const head_bobbing_walking_intensity: float = 0.1
const head_bobbing_crouching_intensity: float = 0.05
var head_bobbing_current_intensity: float = 0.0
var head_bobbing_vector: Vector2 = Vector2.ZERO
var head_bobbing_index: float = 0.0
var last_bob_position_x: float = 0.0                                            # Tracks the previous horizontal head-bob position
var last_bob_direction: int = 0                                                 # Tracks the previous movement direction of the bob (-1 = left, +1 = right)

# Leaning Vars
var lean_angle: float = 12.0                # How much to tilt (degrees)
var lean_offset: float = 0.25               # How far to move camera sideways
var lean_speed: float = 8.0                 # How quickly to lerp between states
var target_lean: float = 0.0                        # -1 = left, 1 = right, 0 = neutral
var current_lean: float = 0.0

# Sanity Vars
var light_level: float = 0.0

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
		
	if Input.is_action_pressed("lean_left"):
		target_lean = -1.0
	elif Input.is_action_pressed("lean_right"):
		target_lean = 1.0
	else:
		target_lean = 0.0	
		
	if event is InputEventMouseMotion:
		if current_sensitivity > 0.01 and not interaction_controller.isCameraLocked():
			mouse_input = event.relative
			rotate_y(deg_to_rad(-mouse_input.x * current_sensitivity))
			head.rotate_x(deg_to_rad(-mouse_input.y * current_sensitivity))
			head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	
func _physics_process(delta: float) -> void:
	
	updatePlayerState()
	updateCamera(delta)
	
	# Falling
	if not is_on_floor():
		is_in_air = true
		if velocity.y >= 0: # jumping upwards
			velocity += get_gravity() * delta
		else: # falling down
			velocity += get_gravity() * delta * 2.0
	else: # Jumping
		if is_in_air == true: # If true, this is the first frame since landing.
			footsteps_se.play()
			is_in_air = false
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
			jump_se.play()
			
	
	# Movement Logic
	input_dir = Input.get_vector("left", "right", "forward", "backward")
	direction = lerp(direction, (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized(), delta*10.0)
	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else: # player wants to stop moving
		velocity.x = move_toward(velocity.x, 0, current_speed)
		velocity.z = move_toward(velocity.z, 0, current_speed)
			
	move_and_slide()
	note_tilt_and_sway(input_dir, delta)

func _process(delta: float) -> void:
	# If we just unlocked camera, slowly bring sensitivity back to normal levels
	if sensitivity_fading_in:
		current_sensitivity = lerp(current_sensitivity, normal_sensitivity, delta * sensitivity_restore_speed)
		if abs(current_sensitivity - normal_sensitivity) < 0.01:
			current_sensitivity = normal_sensitivity
			sensitivity_fading_in = false
			
	set_camera_locked(interaction_controller.isCameraLocked())

	
func updatePlayerState() -> void:
	moving = (input_dir != Vector2.ZERO)
	if not is_on_floor():
		player_state = PlayerState.AIR
	else:
		if Input.is_action_pressed("crouch"):
			if not moving:
				player_state = PlayerState.IDLE_CROUCH
			else:
				player_state = PlayerState.CROUCHING
		elif !standup_check.is_colliding():
			if not moving:
				player_state = PlayerState.IDLE_STAND
			elif Input.is_action_pressed("sprint"):
				player_state = PlayerState.SPRINTING
			else:
				player_state = PlayerState.WALKING
			
	updatePlayerColShape(player_state)
	updatePlayerSpeed(player_state)
	
func updatePlayerColShape(_player_state: PlayerState) -> void:
	if _player_state == PlayerState.CROUCHING or _player_state == PlayerState.IDLE_CROUCH:
		standing_collision_shape.disabled = true
		crouching_collision_shape.disabled = false
	else:
		standing_collision_shape.disabled = false
		crouching_collision_shape.disabled = true
	
func updatePlayerSpeed(_player_state: PlayerState) -> void:
	if _player_state == PlayerState.CROUCHING or _player_state == PlayerState.IDLE_CROUCH:
		current_speed = crouching_speed
	elif _player_state == PlayerState.WALKING:
		current_speed = walking_speed
	elif _player_state == PlayerState.SPRINTING:
		current_speed = sprinting_speed

func updateCamera(delta: float) -> void:
	if player_state == PlayerState.AIR:
		pass
		
	if player_state == PlayerState.CROUCHING or player_state == PlayerState.IDLE_CROUCH:
		head.position.y = lerp(head.position.y, 1.8 + crouching_depth, delta*lerp_speed)
		camera_3d.fov = lerp(camera_3d.fov, base_fov*0.95, delta*lerp_speed)
		head_bobbing_current_intensity = head_bobbing_crouching_intensity
		head_bobbing_index += head_bobbing_crouching_speed * delta
	elif player_state == PlayerState.IDLE_STAND:
		head.position.y = lerp(head.position.y, 1.8, delta*lerp_speed)
		camera_3d.fov = lerp(camera_3d.fov, base_fov, delta*lerp_speed)
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta
	elif player_state == PlayerState.WALKING:
		head.position.y = lerp(head.position.y, 1.8, delta*lerp_speed)
		camera_3d.fov = lerp(camera_3d.fov, base_fov, delta*lerp_speed)
		head_bobbing_current_intensity = head_bobbing_walking_intensity
		head_bobbing_index += head_bobbing_walking_speed * delta
	elif player_state == PlayerState.SPRINTING:
		head.position.y = lerp(head.position.y, 1.8, delta*lerp_speed)
		camera_3d.fov = lerp(camera_3d.fov, base_fov*1.05, delta*lerp_speed)
		head_bobbing_current_intensity = head_bobbing_sprinting_intensity
		head_bobbing_index += head_bobbing_sprinting_speed * delta
		
	head_bobbing_vector.y = sin(head_bobbing_index)
	head_bobbing_vector.x = (sin(head_bobbing_index/2.0))
	if moving:
		eyes.position.y = lerp(eyes.position.y , head_bobbing_vector.y*(head_bobbing_current_intensity/2.0),delta*lerp_speed)
		eyes.position.x = lerp(eyes.position.x , head_bobbing_vector.x*(head_bobbing_current_intensity),delta*lerp_speed)
	else:
		eyes.position.y = lerp(eyes.position.y , 0.0 ,delta*lerp_speed)
		eyes.position.x = lerp(eyes.position.x , 0.0 ,delta*lerp_speed)
		
	# head lean
	current_lean = lerp(current_lean, target_lean, delta * lean_speed)
	
	var target_tilt: float = deg_to_rad(-lean_angle) * current_lean
	var target_offset: float = lean_offset * current_lean
	
	camera_3d.rotation.z = lerp(camera_3d.rotation.z, target_tilt, delta * lean_speed)
	camera_3d.position.x = lerp(camera_3d.position.x, target_offset, delta * lean_speed)
	
	note_camera.fov = camera_3d.fov
	play_footsteps()
	
func set_camera_locked(locked: bool) -> void:
	
	if locked:
		current_sensitivity = 0.0
		sensitivity_fading_in = false
	else:
		sensitivity_fading_in = true

func note_tilt_and_sway(input_dir: Vector2, delta: float) -> void:
	if note_hand:
		note_hand.rotation.z = lerp(note_hand.rotation.z, -input_dir.x * note_sway_amount, 10 * delta)
		note_hand.rotation.x = lerp(note_hand.rotation.x, -input_dir.y * note_sway_amount, 10 * delta)

func play_footsteps() -> void:
	if moving and is_on_floor():
		var bob_position_x = head_bobbing_vector.x
		var bob_direction = sign(bob_position_x - last_bob_position_x)  # +1 = moving right, -1 = moving left

		# A direction change means we just reached a peak in the bobbing cycle
		if bob_direction != 0 and bob_direction != last_bob_direction and last_bob_direction != 0:
			footsteps_se.play()

		last_bob_direction = bob_direction
		last_bob_position_x = bob_position_x
	else:
		last_bob_direction = 0
		last_bob_position_x = head_bobbing_vector.x
