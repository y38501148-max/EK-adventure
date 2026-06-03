extends Resource
class_name CardDefinition

enum CardType { ATTACK, SKILL, POWER, EVENT }

@export var id: StringName
@export var title: String = ""
@export_enum("攻击", "技能", "能力", "事件") var card_type: int = CardType.ATTACK
@export var cost: int = 1
@export_multiline var description: String = ""
@export var tags: Array[StringName] = []
@export var art: Texture2D
@export var effects: Array[Resource] = []
