extends Node

@onready var light_detection_viewport: SubViewport = %SubViewport
@onready var sanity_cam_view: TextureRect = %SanityCamView
@onready var average_light_color_view: ColorRect = %AverageLightColorView
@onready var light_detection: Node3D = %LightDetection
@onready var debug: Label = %Debug

# Light Detection Variables
var light_level: float = 0.0

# Sanity Variables
var sanity: float = 100.0
var time_since_sanity_change: float = 0.0
const SANITY_DRAIN_INTERVAL := .25 # seconds
const DARKNESS_THRESHOLD := 0.3
const SANITY_REGEN_TARGET := 51.0
const SANITY_REGEN_RATE := 1.0 / SANITY_DRAIN_INTERVAL

func _ready() -> void:
	light_detection_viewport.debug_draw = Viewport.DEBUG_DRAW_LIGHTING

func _process(delta: float) -> void:
	light_level = get_light_level()

	update_sanity(delta)
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
