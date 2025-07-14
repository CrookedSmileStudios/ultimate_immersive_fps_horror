extends Node3D

var sanity_controller: Node
var completed: bool = false

func execute(_percentage: float) -> void:
	if not completed and _percentage > .9:
		sanity_controller = get_tree().get_current_scene().find_child("SanityController", true, false)
		if sanity_controller.has_method("add_sanity"):
			sanity_controller.add_sanity(10)
			sanity_controller.on_puzzle_complete(0.1, 0.5)
			completed = true
