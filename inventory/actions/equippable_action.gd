extends ActionData
class_name EquippableAction

@export var one_time_use: bool = true
@export var success_text: String = "Door Unlocked"

func _init():
	action_type = ActionType.EQUIPPABLE
