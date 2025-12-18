extends ActionData
class_name ConsumableAction

@export var modifier_name: String
@export var modifier_value: int

func _init():
	action_type = ActionType.CONSUMABLE
