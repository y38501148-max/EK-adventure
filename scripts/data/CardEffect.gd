extends Resource
class_name CardEffect

@export var id: StringName
@export_multiline var rules_text: String = ""

func can_apply(_state: Variant, _source_id: int, _targets: Array[int]) -> bool:
	return true

func apply(_state: Variant, _source_id: int, _targets: Array[int]) -> void:
	pass
