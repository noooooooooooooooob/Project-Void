class_name TargetResolver
extends RefCounted

var ally_grid: Vector2i
var enemy_grid: Vector2i


func _init(p_ally_grid: Vector2i, p_enemy_grid: Vector2i) -> void:
	ally_grid = p_ally_grid
	enemy_grid = p_enemy_grid


func rows_for(team: Unit.Team) -> int:
	return ally_grid.y if team == Unit.Team.ALLY else enemy_grid.y


static func center_offset(row: int, rows: int) -> float:
	return float(row) - float(rows - 1) / 2.0


func reach(attacker: Unit, target: Unit) -> int:
	var col_distance: int = attacker.cell.x + 1 + target.cell.x
	var attacker_offset: float = center_offset(attacker.cell.y, rows_for(attacker.team))
	var target_offset: float = center_offset(target.cell.y, rows_for(target.team))
	return col_distance + floori(absf(attacker_offset - target_offset))


func is_blocked(target: Unit, all_units: Array[Unit]) -> bool:
	for unit in all_units:
		if unit.team != target.team:
			continue
		if not unit.is_alive():
			continue
		if unit.cell.y == target.cell.y and unit.cell.x < target.cell.x:
			return true
	return false


func is_valid_target(attacker: Unit, target: Unit, attack_type: CardData.AttackType, attack_range: int, all_units: Array[Unit]) -> bool:
	if not target.is_alive():
		return false
	if target.team == attacker.team:
		return false
	if reach(attacker, target) > attack_range:
		return false
	if attack_type == CardData.AttackType.MELEE and is_blocked(target, all_units):
		return false
	return true


func expand_shape(primary: Unit, shape: CardData.Shape, all_units: Array[Unit]) -> Array[Unit]:
	var hit: Array[Unit] = []

	if shape == CardData.Shape.SINGLE:
		hit.append(primary)
		return hit

	for unit in all_units:
		if unit.team != primary.team:
			continue
		if not unit.is_alive():
			continue
		if shape == CardData.Shape.PIERCE and unit.cell.y == primary.cell.y:
			hit.append(unit)
		elif shape == CardData.Shape.SWEEP and unit.cell.x == primary.cell.x:
			hit.append(unit)

	return hit
