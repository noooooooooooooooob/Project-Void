## 전투 격자 위에서 "카드의 기준이 될 수 있는 유닛"과 "범위 안에서 누가 맞는가", "어디로 이동할 수 있는가"를 계산하는 규칙 도우미.
## 상태를 바꾸지 않는 순수 계산만 한다. BattleState, EnemyBrain, 화면의 대상 힌트가 함께 쓴다.
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


## 근접 기준 유닛: 상대 편에서 actor 와 같은 행 번호에 살아 있는 유닛 중 가장 앞 열(x 가 가장 작은) 한 명. 없으면 null.
func melee_anchor(actor: Unit, all_units: Array[Unit]) -> Unit:
	# 지금까지 찾은 가장 앞 유닛.
	var best: Unit = null
	# 모든 유닛을 본다.
	for unit in all_units:
		# 같은 편, 쓰러짐, 다른 행은 제외한다.
		if unit.team == actor.team or not unit.is_alive() or unit.cell.y != actor.cell.y:
			continue
		# 처음이거나 더 앞 열이면 바꾼다.
		if best == null or unit.cell.x < best.cell.x:
			best = unit
	# 찾은 유닛 (없으면 null).
	return best


## 이 카드의 기준 유닛이 될 수 있는 유닛 목록. 근접은 같은 행 맨 앞 한 명(없으면 빈 목록), 원거리는 살아 있는 상대 전부,
## 아군은 살아 있는 같은 편 전부(자신 포함), 자신은 [actor]. 카드 사용·적 AI·화면 힌트가 모두 이 함수로 판정한다.
func valid_anchors(actor: Unit, card: CardData, all_units: Array[Unit]) -> Array[Unit]:
	# 후보 목록.
	var anchors: Array[Unit] = []
	# 공격 종류마다.
	match card.attack_type:
		# 자신: 살아 있으면 자기 자신.
		CardData.AttackType.SELF:
			if actor.is_alive():
				anchors.append(actor)
		# 근접: 같은 행 맨 앞 한 명.
		CardData.AttackType.MELEE:
			var front: Unit = melee_anchor(actor, all_units)
			if front != null:
				anchors.append(front)
		# 원거리·아군: 해당 편의 살아 있는 유닛 전부.
		_:
			# 아군 카드면 같은 편, 원거리면 상대 편.
			var same_team: bool = card.attack_type == CardData.AttackType.ALLY
			for unit in all_units:
				if unit.is_alive() and (unit.team == actor.team) == same_team:
					anchors.append(unit)
	# 모은 후보.
	return anchors


## 기준 칸에 범위 오프셋을 더한 칸들. 격자 밖은 버리고 같은 칸은 한 번만 넣는다.
func area_cells(anchor_cell: Vector2i, area: Array[Vector2i], grid: Vector2i) -> Array[Vector2i]:
	# 결과 칸.
	var cells: Array[Vector2i] = []
	# 오프셋마다.
	for offset in area:
		# 실제 칸.
		var cell: Vector2i = anchor_cell + offset
		# 격자 밖이면 버린다.
		if cell.x < 0 or cell.y < 0 or cell.x >= grid.x or cell.y >= grid.y:
			continue
		# 중복이면 버린다.
		if cells.has(cell):
			continue
		# 넣는다.
		cells.append(cell)
	# 모은 칸.
	return cells


## 기준 유닛 기준 범위 안에 서 있는, 기준 유닛과 같은 편의 살아 있는 유닛들 (전장 순서).
func units_in_area(anchor: Unit, area: Array[Vector2i], all_units: Array[Unit]) -> Array[Unit]:
	# 범위 칸.
	var cells: Array[Vector2i] = area_cells(anchor.cell, area, grid_for(anchor.team))
	# 맞는 유닛.
	var hit: Array[Unit] = []
	# 모든 유닛 중.
	for unit in all_units:
		# 같은 편, 살아 있음, 범위 안.
		if unit.team == anchor.team and unit.is_alive() and cells.has(unit.cell):
			hit.append(unit)
	# 모은 유닛.
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
