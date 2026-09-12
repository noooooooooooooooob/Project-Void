@tool
class_name EnemyData
extends UnitData

@export var attack_damage: int = 5
@export var attack_type: CardData.AttackType = CardData.AttackType.MELEE
@export var attack_shape: CardData.Shape = CardData.Shape.SINGLE
@export var attack_range: int = 1
@export var block_amount: int = 5
@export var rest_heal: int = 4
