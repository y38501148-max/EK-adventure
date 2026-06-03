extends RefCounted
class_name CardInstanceState

var runtime_id: int
var definition: Resource
var owner_id: StringName = &"player"
var zone: StringName = &"draw_pile"
var temporary_cost_delta: int = 0
var selected: bool = false

func _init(p_runtime_id: int = 0, p_definition: Resource = null) -> void:
	runtime_id = p_runtime_id
	definition = p_definition

func display_cost(additional_delta: int = 0) -> int:
	if definition == null:
		return 0
	return max(0, definition.cost + temporary_cost_delta + additional_delta)
