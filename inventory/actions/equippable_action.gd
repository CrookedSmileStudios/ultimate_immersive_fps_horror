extends ActionData
class_name EquippableAction

@export var one_time_use: bool = true

func _init():
	action_type = ActionType.EQUIPPABLE
