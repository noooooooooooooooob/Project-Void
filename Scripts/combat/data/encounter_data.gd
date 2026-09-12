@tool
class_name EncounterData
extends Resource

@export var ally_grid: Vector2i = Vector2i(3, 3)
@export var enemy_grid: Vector2i = Vector2i(3, 3)
@export var ally_units: Array[UnitPlacement] = []
@export var enemy_units: Array[UnitPlacement] = []
