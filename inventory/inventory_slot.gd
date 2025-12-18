extends Control
class_name InventorySlot

@export var icon_slot: TextureRect

var inventory_slot_id: int = -1
var slot_filled: bool = false
var slot_data: ItemData

signal on_item_swapped(from_slot_id, to_slot_id)
signal on_item_double_clicked(slot_id: int)
signal on_item_right_clicked(slot_id: int)

func fill_slot(data: ItemData):
	slot_data = data
	if (slot_data != null):
		slot_filled = true
		icon_slot.texture = data.item_icon
	else:
		slot_filled = false
		icon_slot.texture = null
		
func _get_drag_data(_at_position: Vector2) -> Variant:
	if (slot_filled):
		var preview: TextureRect = TextureRect.new()
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.size = icon_slot.size
		preview.pivot_offset = icon_slot.size / 2.0
		preview.texture = icon_slot.texture
		set_drag_preview(preview)
		return {"Type": "Item", "ID": inventory_slot_id}
	else:
		return false
		
func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data["Type"] == "Item"

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	on_item_swapped.emit(data["ID"], inventory_slot_id)

func _gui_input(event: InputEvent) -> void:
	if not slot_filled:
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			on_item_double_clicked.emit(inventory_slot_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			emit_signal("on_item_right_clicked", inventory_slot_id)
