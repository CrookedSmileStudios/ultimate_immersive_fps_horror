extends Node

@onready var light_detection_viewport: SubViewport = %LightViewport
@onready var sanity_cam_view: TextureRect = %SanityCamView
@onready var average_light_color_view: ColorRect = %AverageLightColorView
@onready var light_detection: Node3D = %LightDetection
@onready var debug: Label = %Debug

@onready var distortion: Sprite2D = %Distortion
@onready var distortion_material: ShaderMaterial = distortion.material

@onready var player_camera: Camera3D = %Camera3D

@onready var flash_sprite: Sprite2D =  %PuzzleComplete
@onready var shader_material: ShaderMaterial = flash_sprite.material as ShaderMaterial


# Light Detection Variables
var light_level: float = 0.0

# Sanity Variables
var sanity: float = 100.0
var time_since_sanity_change: float = 0.0
const SANITY_DRAIN_INTERVAL: float = .25 # seconds
const DARKNESS_THRESHOLD: float = 0.3
const SANITY_REGEN_TARGET: float = 51.0
const SANITY_REGEN_RATE: float = 1.0 / SANITY_DRAIN_INTERVAL

const ENEMY_VIEW_RANGE: float = 10.0

func _ready() -> void:
	light_detection_viewport.debug_draw = Viewport.DEBUG_DRAW_LIGHTING

func _process(delta: float) -> void:
	light_level = get_light_level()
	update_sanity(delta)
	update_distortion(sanity)
	
	for enemy in get_tree().get_nodes_in_group("enemy"):
		if is_enemy_on_screen(enemy):
			if is_enemy_in_view(enemy, ENEMY_VIEW_RANGE):
				if has_line_of_sight_to(enemy):
					drain_sanity(delta * 8.0)
	
	debug.text = "FPS: %d\nLight Level: %.2f\nSanity: %.2f\nState: %s" % [
		Engine.get_frames_per_second(),
		light_level,
		sanity,
		get_sanity_state()
	]

func get_average_color(texture: ViewportTexture) -> Color:
	 # Get the Image of the input texture
	var image = texture.get_image()
	 # Resize the image to one pixel
	image.resize(1, 1, Image.INTERPOLATE_LANCZOS)
	# Read the color of that pixel
	return image.get_pixel(0, 0)

func get_light_level() -> float:
	# Keep the Camera and the mesh attached to our player at all times
	light_detection.global_position = get_parent().global_position
	# Get the 2D image of what the camera is seeing. Update our visual aid.
	var texture = light_detection_viewport.get_texture()
	sanity_cam_view.texture = texture
	# Get the average color of the camera texture. This will be our light level. Update visual aid.
	var color = get_average_color(texture)
	average_light_color_view.color = color
	# Return the perceived brightness of the color
	# luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
	# These weights are based on the Rec. 709 standard (used in HDTV and sRGB), 
	# and represent how much each channel contributes to the overall brightness as seen by the human eye.
	# The alpha value is ignored for this calculation
	return color.get_luminance() 
	
func update_sanity(delta: float) -> void:
	time_since_sanity_change += delta

	if light_level <= DARKNESS_THRESHOLD:
		# In darkness: lose sanity every "drain" interval
		if time_since_sanity_change >= SANITY_DRAIN_INTERVAL and sanity > 0.0:
			sanity -= 1.0
			sanity = clamp(sanity, 0.0, 100.0)
			time_since_sanity_change = 0.0
	else:
		# In light: regain sanity to at least 51%
		if sanity < SANITY_REGEN_TARGET:
			if time_since_sanity_change >= SANITY_DRAIN_INTERVAL:
				sanity += SANITY_REGEN_RATE * SANITY_DRAIN_INTERVAL
				sanity = clamp(sanity, 0.0, SANITY_REGEN_TARGET)
				time_since_sanity_change = 0.0
				
func get_sanity_state() -> String:
	if sanity >= 75.0:
		return "Crystal Clear"
	elif sanity >= 50.0:
		return "A slight headache"
	elif sanity >= 25.0:
		return "Head is pounding and hands are shaking"
	elif sanity >= 1.0:
		return "..."
	else:
		return "Unconscious"
		
func drain_sanity(amount: float) -> void:
	sanity = clamp(sanity - amount, 0.0, 100.0)

func add_sanity(amount: float) -> void:
	sanity = clamp(sanity + amount, 0.0, 100.0)
	
func update_distortion(sanity: float):
	var distortion := 0.0
	if sanity < 50.0:
		var t := (50.0 - sanity) / 50.0 # sanity 50 → t = 0, sanity 0 → t = 1
		t = pow(t, 2.5) # curve: start slow, ends fast (t^2.5)
		distortion = t * 0.05 # scale to max distortion
	
	distortion_material.set_shader_parameter("distortion_strength", distortion)
	
func is_enemy_in_view(enemy: Node3D, tolerance_degrees: float) -> bool:
	var camera_pos: Vector3 = player_camera.global_transform.origin
	var enemy_pos: Vector3 = enemy.global_transform.origin

	# Vector pointing from the player camera to the enemy
	var to_enemy: Vector3 = (enemy_pos - camera_pos).normalized()

	# Camera's forward direction (in Godot, this is -Z)
	var forward: Vector3 = -player_camera.global_transform.basis.z

	# Compare the angle between the camera's view and the object
	var angle_deg: float = rad_to_deg(acos(forward.dot(to_enemy)))

	return angle_deg <= tolerance_degrees
	
func is_enemy_on_screen(enemy: Node3D) -> bool:
	var viewport: Viewport = player_camera.get_viewport()
	var screen_size: Vector2 = viewport.size

	var enemy_position: Vector3 = enemy.global_transform.origin  				# World position of the enemy
	var camera_position: Vector3 = player_camera.global_transform.origin		# World position of the player camera
	var to_enemy: Vector3 = enemy_position - camera_position					# Directional vector from the camera to the object

	var forward: Vector3 = -player_camera.global_transform.basis.z				# Get the camera's forward direction (negative Z axis in Godot)

	# Check if the object is behind the camera by using dot product
	# A negative dot product means the object is behind the view direction
	if forward.dot(to_enemy) < 0.0:
		return false

	# Project the 3D object’s position to 2D screen space (Vector2)
	var screen_pos: Vector2 = player_camera.unproject_position(enemy_position)

	# If the screen X position is outside the screen bounds, return false
	if screen_pos.x < 0.0 or screen_pos.x > screen_size.x:
		return false
	# If the screen Y position is outside the screen bounds, return false
	if screen_pos.y < 0.0 or screen_pos.y > screen_size.y:
		return false

	return true
	
func has_line_of_sight_to(enemy: Node3D) -> bool:
	# direct_space_state gives access to physics queries, such as raycasts and collision checks
	var space_state = player_camera.get_world_3d().direct_space_state
	
	# the world-space position of the player camera.
	var from_pos = player_camera.global_transform.origin
	
	# the world-space position of the enemy.
	var to_pos = enemy.global_transform.origin
	
	# creates a raycast, the size of the raycast starts at the from_pos (player camera) and ends at the enemy 
	var query = PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	
	# determines what the ray can hit. Our enemy is on collision_mask 1, as well as our walls.
	# if you are making use of multiple layers, you will need to modify this value.
	query.collision_mask = 1
	
	# Ignore the player camera and the enemy, we only care if we collide with walls/objects
	query.exclude = [player_camera, enemy]
	
	# Return the results of everything the raycast is colliding with.
	var result = space_state.intersect_ray(query)
	
	# If the raycast is colliding with nothing, then we have a clear line of sight to the enemy (true)
	# If the raycast is being blocked by a wall, then result is not empty (False)
	return result.is_empty()



func on_puzzle_complete(flash_duration: float = 0.1, fade_duration: float = 0.5) -> void:
	flash_sprite.visible = true
	# Immediately set alpha to full (visible)
	shader_material.set_shader_parameter("alpha", 0.5)
	
	# Create a tween sequence
	var tween = get_tree().create_tween()
	
	# Wait for the flash_duration at full alpha (hold)
	tween.tween_interval(flash_duration)
	
	# Then tween alpha back to 0 over fade_duration
	tween.tween_property(shader_material, "shader_parameter/alpha", 0.0, fade_duration)
	
	# Optional callback at the end of fade to reset/hide
	tween.tween_callback(Callable(self, "_on_flash_complete"))

func _on_flash_complete() -> void:
	# Reset or hide flash sprite if needed
	# For example, make sure alpha is zero and node hidden
	shader_material.set_shader_parameter("alpha", 0.0)
	flash_sprite.visible = false
