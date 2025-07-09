extends Node3D

@onready var suzanne: MeshInstance3D = $Suzanne

func execute(_percentage: float) -> void:
	if _percentage > .95:
		queue_free()
