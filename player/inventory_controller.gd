extends Control
class_name InventoryController

@onready var player_camera: Camera3D = $"../../Head/Eyes/Camera3D"
@onready var hand: Marker3D = $"../../Head/Eyes/Camera3D/Hand"
@onready var interaction_controller: Node = $"../../InteractionController"
@onready var sanity_controller: Node = $"../../SanityController"
@onready var context_menu: PopupMenu = PopupMenu.new()

@export var item_slots_count:int = 20
@export var inventory_grid: GridContainer
@export var inventory_slot_prefab: PackedScene = load("res://inventory/inventory_slot.tscn")
var swap_slot_player: AudioStreamPlayer
var swap_slot_sound_effect: AudioStreamOggVorbis = load("res://assets/sound_effects/menu_swap.ogg")

var inventory_slots: Array[InventorySlot] = []

func _ready():
	swap_slot_player = AudioStreamPlayer.new()
	swap_slot_player.volume_db = -12.0
	swap_slot_player.stream = swap_slot_sound_effect
	add_child(swap_slot_player)

	for i in item_slots_count:
		var slot = inventory_slot_prefab.instantiate() as InventorySlot
		inventory_grid.add_child(slot)
		slot.inventory_slot_id = i
		slot.on_item_swapped.connect(_on_item_swapped_on_slot)
		slot.on_item_double_clicked.connect(_on_item_double_clicked)
		slot.on_item_right_clicked.connect(_on_slot_right_click)
		inventory_slots.append(slot)

	add_child(context_menu)
	context_menu.connect("id_pressed", Callable(self, "_on_context_menu_selected"))


# ----------------------
# Pickup / Drag & Drop
# ----------------------
func pickup_item(item: ItemData) -> void:
	for slot in inventory_slots:
		if not slot.slot_filled:
			slot.fill_slot(item)
			return
	# TODO: handle inventory full case

func _on_item_swapped_on_slot(from_slot_id: int, to_slot_id: int) -> void:
	var to_slot_item = inventory_slots[to_slot_id].slot_data
	var from_slot_item = inventory_slots[from_slot_id].slot_data
	inventory_slots[to_slot_id].fill_slot(from_slot_item)
	inventory_slots[from_slot_id].fill_slot(to_slot_item)
	swap_slot_player.play()

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	if data["Type"] != "Item":
		return false
	var slot := inventory_slots[data["ID"]]
	if slot.slot_data == null:
		return false
	# Only CONSUMABLE or EQUIPPABLE (items that can be dropped) can leave inventory
	var action_type = slot.slot_data.action_data.action_type
	return action_type == ActionData.ActionType.CONSUMABLE or action_type == ActionData.ActionType.EQUIPPABLE

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	drop_collectable(data["ID"])


# ----------------------
# Context Menu
# ----------------------
func _on_item_double_clicked(slot_id: int) -> void:
	var slot := inventory_slots[slot_id]
	if slot.slot_data == null:
		return
	match _get_item_action_type(slot.slot_data):
		ActionData.ActionType.CONSUMABLE:
			use_collectable(slot_id)
		ActionData.ActionType.EQUIPPABLE:
			equip_collectable(slot_id)
		ActionData.ActionType.INSPECTABLE:
			view_inspectable(slot_id)

func _on_slot_right_click(slot_id: int) -> void:
	var slot := inventory_slots[slot_id]
	if slot.slot_data == null:
		return

	context_menu.clear()
	match _get_item_action_type(slot.slot_data):
		ActionData.ActionType.CONSUMABLE:
			context_menu.add_item("Use", 0)
			context_menu.add_item("Drop", 1)
		ActionData.ActionType.EQUIPPABLE:
			context_menu.add_item("Equip", 0)
			context_menu.add_item("Drop", 1)
		ActionData.ActionType.INSPECTABLE:
			context_menu.add_item("View", 0)
			context_menu.add_item("Drop", 1)

	context_menu.set_meta("slot_id", slot_id)
	var mouse_pos := get_viewport().get_mouse_position()
	var rect := Rect2i(mouse_pos.floor(), Vector2i(1, 1))
	context_menu.popup(rect)


func _on_context_menu_selected(id: int) -> void:
	var slot_id = context_menu.get_meta("slot_id")
	var slot := inventory_slots[slot_id]
	if slot.slot_data == null:
		return

	var action_type = _get_item_action_type(slot.slot_data)

	match action_type:
		ActionData.ActionType.CONSUMABLE:
			match id:
				0: use_collectable(slot_id)
				1: drop_collectable(slot_id)
		ActionData.ActionType.EQUIPPABLE:
			match id:
				0: equip_collectable(slot_id)
				1: drop_collectable(slot_id)
		ActionData.ActionType.INSPECTABLE:
			match id:
				0: view_inspectable(slot_id)
				1: drop_collectable(slot_id)


# ----------------------
# Actions (Use / Drop / View)
# ----------------------
func use_collectable(slot_id: int) -> void:
	var slot := inventory_slots[slot_id]
	var item := slot.slot_data
	if item == null:
		return

	# Access the actual data
	var data = item.action_data
	match data.modifier_name:
		"sanity":
			sanity_controller.add_sanity(data.modifier_value)

	slot.fill_slot(null)

func drop_collectable(slot_id: int) -> void:
	var slot := inventory_slots[slot_id]
	var item := slot.slot_data
	if item == null:
		return

	var instance := item.item_model_prefab.instantiate() as Node3D
	get_tree().current_scene.add_child(instance)

	# --- Step 1: Forward target ---
	var drop_distance: float = 2.0
	var forward_dir: Vector3 = -player_camera.global_transform.basis.z.normalized()
	var target_pos: Vector3 = player_camera.global_transform.origin + forward_dir * drop_distance

	var space_state = hand.get_world_3d().direct_space_state

	# --- Step 2: Obstacle check ---
	var obstacle_params = PhysicsRayQueryParameters3D.new()
	obstacle_params.from = player_camera.global_transform.origin
	obstacle_params.to = target_pos
	obstacle_params.exclude = [hand.get_parent()]

	var obstacle_hit = space_state.intersect_ray(obstacle_params)
	if obstacle_hit:
		print("Cannot drop: path blocked")
		interaction_controller.interact_failure_player.play()
		instance.queue_free()
		return

	# --- Step 3: Find ground ---
	var ground_params = PhysicsRayQueryParameters3D.new()
	ground_params.from = target_pos + Vector3.UP * 2.0
	ground_params.to = target_pos - Vector3.UP * 5.0
	ground_params.exclude = [hand.get_parent()]

	var ground_hit = space_state.intersect_ray(ground_params)
	if not ground_hit:
		print("Cannot drop: no ground")
		instance.queue_free()
		return

	var ground_pos: Vector3 = ground_hit.position
	
	# Visualize forward ray (obstacle check)
	DebugDraw3D.draw_line(
		player_camera.global_transform.origin,
		target_pos,
		Color.RED,
		1.5
	)

	# Visualize downward ray (ground check)
	DebugDraw3D.draw_line(
		target_pos + Vector3.UP * 2.0,
		target_pos - Vector3.UP * 5.0,
		Color.GREEN,
		1.5
	)

	# --- Step 4: Adjust spawn position ---
	var buffer_height = 0.2

	if instance is RigidBody3D:
		# Spawn slightly above the ground for physics to settle
		instance.global_transform.origin = ground_pos + Vector3.UP * buffer_height
		instance.freeze = false
		instance.gravity_scale = 1.0
	else:
		# Static or kinematic object: place exactly on the ground
		instance.global_transform.origin = ground_pos + Vector3.UP * 0.01

	# Optional: rotate item randomly on Y for variety
	instance.rotation_degrees.y = randf() * 360
	swap_slot_player.play()

	slot.fill_slot(null)



func equip_collectable(slot_id: int) -> void:
	var slot := inventory_slots[slot_id]
	var item := slot.slot_data
	if item == null:
		return

	var instance := item.item_model_prefab.instantiate() as Node3D
	interaction_controller.on_item_equipped(instance)
	slot.fill_slot(null)

func view_inspectable(slot_id: int) -> void:
	var slot := inventory_slots[slot_id]
	var item := slot.slot_data
	if item == null:
		return

	var instance := item.item_model_prefab.instantiate() as Node3D
	interaction_controller.on_note_inspected(instance)
	slot.fill_slot(null)

func _get_item_action_type(item: ItemData) -> int:
	if not item or not item.item_model_prefab:	
		return -1
		
	return item.action_data.action_type	
