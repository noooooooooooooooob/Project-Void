@tool
class_name CardData
extends Resource

enum AttackType { MELEE, RANGED }
enum Shape { SINGLE, PIERCE, SWEEP }

@export var id: StringName = &""
@export var display_name: String = ""
@export var sp_cost: int = 1
@export var attack_type: AttackType = AttackType.MELEE
@export var shape: Shape = Shape.SINGLE
@export var attack_range: int = 1
@export var damage: int = 0
