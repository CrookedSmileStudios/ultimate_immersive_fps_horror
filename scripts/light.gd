extends SpotLight3D

@export var actuation_percentage: float = 0.8

func execute(_percentage: float) -> void:
	if _percentage > .97:
		light_energy = (100.0)
	elif  _percentage < .03:
		light_energy = (0.0)
