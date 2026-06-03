extends Resource
class_name MonsterDefinition

@export var id: StringName = &"sample_judge"
@export var title: String = "模拟题守门员"
@export var max_health: int = 120
@export var algorithm_attribute: StringName = &"模拟"
@export var action_countdown: int = 3
@export var attack: int = 12
@export var actions: Array[Dictionary] = []
@export_multiline var description: String = "一台守在模拟题入口的评测机，会用稳定但不留情面的测试点攻击选手。"
