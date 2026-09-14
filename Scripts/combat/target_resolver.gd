## 전투 격자 위에서 "누가 누구를 칠 수 있는가"와 "누가 맞는가"를 계산하는 규칙 도우미.
## 상태를 바꾸지 않는 순수 계산만 한다. BattleState, EnemyBrain, 화면의 사거리 힌트가 함께 쓴다.
##
## 좌표 규칙: 아군과 적군은 각자 자기 격자를 가진다.
## cell.x = 열 (0 이 상대 편과 가장 가까운 앞줄), cell.y = 행 (위에서부터 0, 1, 2...).
class_name TargetResolver
# RefCounted: 노드가 아닌 가벼운 객체. 참조가 없어지면 자동으로 해제된다.
extends RefCounted

## 아군 격자 크기 (x = 열 수, y = 행 수).
var ally_grid: Vector2i
## 적군 격자 크기 (x = 열 수, y = 행 수).
var enemy_grid: Vector2i

## 한 칸 이동 방향 후보. 위, 아래, 앞(적 쪽), 뒤 순서로 고정해 무작위 선택이 시드마다 재현되게 한다.
const MOVE_DIRECTIONS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]


## 양쪽 격자 크기를 받아 저장한다.
func _init(p_ally_grid: Vector2i, p_enemy_grid: Vector2i) -> void:
	# 아군 격자 크기를 기억한다.
	ally_grid = p_ally_grid
	# 적군 격자 크기를 기억한다.
	enemy_grid = p_enemy_grid


## 주어진 편의 격자가 몇 행인지 돌려준다.
func rows_for(team: Unit.Team) -> int:
	# 아군이면 아군 격자의 행 수, 아니면 적군 격자의 행 수.
	return ally_grid.y if team == Unit.Team.ALLY else enemy_grid.y


## 주어진 편 격자의 크기를 돌려준다.
func grid_for(team: Unit.Team) -> Vector2i:
	# 아군이면 아군 격자, 아니면 적군 격자.
	return ally_grid if team == Unit.Team.ALLY else enemy_grid


## 행 번호를 "격자 가운데로부터 얼마나 떨어졌는가"로 바꾼다.
## 예: 3행 격자에서 0행 → -1.0, 1행 → 0.0, 2행 → 1.0.
## 양쪽 격자의 행 수가 달라도 가운데를 맞춰 비교할 수 있게 한다.
static func center_offset(row: int, rows: int) -> float:
	# (rows - 1) / 2 가 가운데 행 위치이므로 그만큼 빼 준다.
	return float(row) - float(rows - 1) / 2.0


## 공격자에서 대상까지의 거리(사거리 판정에 쓰는 값)를 잰다.
## 거리 = (공격자 열 + 1 + 대상 열) + 내림(두 유닛의 가운데 기준 행 차이).
func reach(attacker: Unit, target: Unit) -> int:
	# 열 거리: 공격자가 자기 앞줄까지 걸어가는 칸 + 두 격자 사이 경계 1칸 + 대상 앞줄에서 대상까지 칸.
	var col_distance: int = attacker.cell.x + 1 + target.cell.x
	# 공격자의 행이 자기 격자 가운데에서 얼마나 떨어져 있는지.
	var attacker_offset: float = center_offset(attacker.cell.y, rows_for(attacker.team))
	# 대상의 행이 자기 격자 가운데에서 얼마나 떨어져 있는지.
	var target_offset: float = center_offset(target.cell.y, rows_for(target.team))
	# 행 차이는 소수가 나올 수 있으므로(행 수가 다를 때) 내림해서 열 거리에 더한다.
	return col_distance + floori(absf(attacker_offset - target_offset))


## 대상이 근접 공격으로부터 가려져 있는지 검사한다.
## 대상과 같은 편, 같은 행에서 대상보다 앞 열에 살아 있는 유닛이 있으면 가려진 것이다.
func is_blocked(target: Unit, all_units: Array[Unit]) -> bool:
	# 전장의 모든 유닛을 하나씩 본다.
	for unit in all_units:
		# 대상과 다른 편이면 가리개가 될 수 없다.
		if unit.team != target.team:
			continue
		# 쓰러진 유닛은 가리지 못한다.
		if not unit.is_alive():
			continue
		# 같은 행이면서 대상보다 앞 열(x 가 더 작음)에 있으면 대상을 가린다.
		if unit.cell.y == target.cell.y and unit.cell.x < target.cell.x:
			return true
	# 가리는 유닛을 못 찾았다.
	return false


## 공격자가 이 대상을 주어진 방식·사거리로 칠 수 있는지 판정한다.
## 카드 사용, 적 AI 의 대상 고르기, 화면 힌트가 모두 이 함수 하나로 판정해 결과가 어긋나지 않는다.
func is_valid_target(attacker: Unit, target: Unit, attack_type: CardData.AttackType, attack_range: int, all_units: Array[Unit]) -> bool:
	# 이미 쓰러진 유닛은 대상이 될 수 없다.
	if not target.is_alive():
		return false
	# 같은 편은 칠 수 없다.
	if target.team == attacker.team:
		return false
	# 거리가 사거리보다 멀면 닿지 않는다.
	if reach(attacker, target) > attack_range:
		return false
	# 근접 공격은 앞에 가리는 유닛이 있으면 막힌다 (원거리는 이 검사를 건너뛴다).
	if attack_type == CardData.AttackType.MELEE and is_blocked(target, all_units):
		return false
	# 모든 조건을 통과했다.
	return true


## 고른 대상(primary)과 범위 모양을 바탕으로 실제로 피해를 받을 유닛 목록을 만든다.
func expand_shape(primary: Unit, shape: CardData.Shape, all_units: Array[Unit]) -> Array[Unit]:
	# 맞을 유닛들을 담을 배열.
	var hit: Array[Unit] = []

	# 단일 공격이면 고른 대상 한 명만 맞는다.
	if shape == CardData.Shape.SINGLE:
		hit.append(primary)
		return hit

	# 관통·횡렬은 대상과 같은 편 유닛 중 조건에 맞는 유닛을 모두 모은다.
	for unit in all_units:
		# 대상과 다른 편은 제외한다 (자기 편을 맞히지 않음).
		if unit.team != primary.team:
			continue
		# 쓰러진 유닛은 제외한다.
		if not unit.is_alive():
			continue
		# 관통: 대상과 같은 행에 있으면 맞는다.
		if shape == CardData.Shape.PIERCE and unit.cell.y == primary.cell.y:
			hit.append(unit)
		# 횡렬: 대상과 같은 열에 있으면 맞는다.
		elif shape == CardData.Shape.SWEEP and unit.cell.x == primary.cell.x:
			hit.append(unit)

	# 모은 목록을 돌려준다 (대상 자신도 조건에 맞으므로 포함된다).
	return hit


## 유닛이 지금 한 칸 이동할 수 있는 칸 목록 (MOVE_DIRECTIONS 순서).
## 자기 편 격자 안이고 살아 있는 유닛이 없는 상하좌우 칸만 들어간다.
func movable_cells(unit: Unit, all_units: Array[Unit]) -> Array[Vector2i]:
	# 결과를 담을 배열.
	var cells: Array[Vector2i] = []
	# 그 편 격자 크기.
	var grid: Vector2i = grid_for(unit.team)
	# 네 방향마다.
	for direction in MOVE_DIRECTIONS:
		# 한 칸 옮긴 좌표.
		var cell: Vector2i = unit.cell + direction
		# 격자 밖이면 건너뛴다.
		if cell.x < 0 or cell.y < 0 or cell.x >= grid.x or cell.y >= grid.y:
			continue
		# 살아 있는 유닛이 있으면 건너뛴다.
		if _occupied(unit.team, cell, all_units):
			continue
		# 갈 수 있는 칸이다.
		cells.append(cell)
	# 모은 칸을 돌려준다.
	return cells


## 그 편의 그 칸에 살아 있는 유닛이 있으면 true. 쓰러진 유닛은 칸을 막지 않는다.
func _occupied(team: Unit.Team, cell: Vector2i, all_units: Array[Unit]) -> bool:
	# 모든 유닛을 확인한다.
	for other in all_units:
		# 같은 편, 같은 칸, 살아 있음이면 막혀 있다.
		if other.team == team and other.cell == cell and other.is_alive():
			return true
	# 비어 있다.
	return false
