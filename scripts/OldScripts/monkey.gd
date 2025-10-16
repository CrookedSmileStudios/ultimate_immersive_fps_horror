extends Node3D

@onready var suzanne: MeshInstance3D = $Suzanne

var hue_offset := randf_range(-0.05, 0.05)  # Small random offset (-0.05 to +0.05)

func execute(_percentage: float) -> void:
	var base_hue = _percentage                # Normalize hue to [0.0, 1.0]
	var hue = fmod(base_hue + hue_offset, 1.0)  # Add slight variation, wrap around at 1.0
	var saturation = 1.0               # Full saturation for vivid colors
	var value = 1.0                    # Full brightness
	var color = Color.from_hsv(hue, saturation, value)
	var material := suzanne.get_active_material(0)
	if material:
			material = material.duplicate()
			material.albedo_color = color
			suzanne.set_surface_override_material(0, material)
	

	if "2" in name:
		self.rotate_x(_percentage/10)
	elif "3" in name:
		self.rotate_y(_percentage/10)
	else:
		self.rotate_z(_percentage/10)
