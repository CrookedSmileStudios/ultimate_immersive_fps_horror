extends SpotLight3D

@export var actuation_percentage: float = 0.8

func execute(_percentage: float) -> void:
	light_energy = (_percentage*100.0)
