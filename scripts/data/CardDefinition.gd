extends Resource
class_name CardDefinition

enum CardType { ATTACK, BLOCK, SKILL, POWER, EVENT }

@export var id: StringName
@export var title: String = ""
@export_enum("攻击", "格挡", "技能", "能力", "事件") var card_type: int = CardType.ATTACK
@export var algorithm_attribute: StringName = &""
@export var cost: int = 1
@export var base_value: int = 0
@export var damage_percent: int = 100
@export_multiline var description: String = ""
@export var tags: Array[StringName] = []
@export var art: Texture2D
@export var effects: Array[Resource] = []
