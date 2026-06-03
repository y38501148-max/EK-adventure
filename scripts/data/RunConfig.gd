extends Resource
class_name RunConfig

@export var hero_name: String = "ExplodingKonjac"
@export var seed: int = 20260603
@export var starting_health: int = 50
@export var starting_energy: int = 4
@export var base_attack: int = 15
@export var base_block: int = 10
@export var starting_deck: Array[Resource] = []
@export var enemy_name: String = "样例评测机"
@export var enemy_health: int = 120
@export var enemy_algorithm_attribute: StringName = &"模拟"
@export var enemy_action_countdown: int = 3
@export var enemy_attack: int = 12
