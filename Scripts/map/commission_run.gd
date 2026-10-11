## 의뢰 하나의 진행 상태. 1층 격자, 지금 칸, 지나온 길, 파티원 현재 체력, 성공·실패를 가진다.
## 의뢰가 끝나면 버린다 — 다음 의뢰는 체력이 가득 찬 새 CommissionRun 으로 시작한다.
class_name CommissionRun
# RefCounted: 노드가 아닌 가벼운 객체. 화면 없이 테스트할 수 있다.
extends RefCounted

## 의뢰 상태. 보스를 이기면 성공, 지거나 도망치면 실패.
enum State { IN_PROGRESS, SUCCEEDED, FAILED }

## 이 의뢰의 1층 격자.
var graph: StageGraph
## 이 의뢰를 연 월드맵 노드 id.
var map_node_id: int
## 지금 서 있는 칸.
var current_id: int
## 지나온 칸 id (순서대로, 시작 포함).
var visited: Array[int] = []
## 파티원 번호별 현재 체력.
var member_hp: Array[int] = []
## 파티원 번호별 최대 체력 (화면 표시용).
var member_max_hp: Array[int] = []
## 의뢰 상태.
var state: State = State.IN_PROGRESS
## 마지막 battle_roster 에 들어간 파티원 번호 (배치 순서).
var _roster_indices: Array[int] = []


## 격자를 새로 뽑고 시작 칸에 선다. 체력은 최대로 시작한다.
func _init(rng: RandomNumberGenerator, p_map_node_id: int, p_member_max_hp: Array[int]) -> void:
	# 격자.
	graph = StageGraph.new(rng)
	# 월드맵 노드.
	map_node_id = p_map_node_id
	# 시작 칸.
	current_id = graph.start_id
	# 지나온 길은 시작부터.
	visited = [graph.start_id]
	# 최대 체력 (복사본).
	member_max_hp = p_member_max_hp.duplicate()
	# 현재 체력 = 최대.
	member_hp = p_member_max_hp.duplicate()


## 그 칸으로 지금 갈 수 있으면 true.
func is_selectable(id: int) -> bool:
	# 끝난 의뢰는 아무 데도 못 간다.
	if is_finished():
		return false
	# 지금 칸에서 이어진 칸만.
	return graph.get_node(current_id).connections.has(id)


## 그 칸으로 이동한다. 갈 수 없으면 아무것도 바꾸지 않고 false.
func enter(id: int) -> bool:
	# 갈 수 없으면 거절.
	if not is_selectable(id):
		return false
	# 이동.
	current_id = id
	# 길에 기록.
	visited.append(id)
	# 성공.
	return true


## 지금 칸의 종류.
func current_kind() -> StageNode.Kind:
	# 지금 칸을 본다.
	return graph.get_node(current_id).kind


## 끝났으면 (성공·실패) true.
func is_finished() -> bool:
	# 진행 중이 아니면 끝.
	return state != State.IN_PROGRESS


## 파티 전체 배치에서 쓰러진 파티원을 빼고 현재 체력을 실은 전투 배치를 만든다. 원본 배치는 바꾸지 않는다.
func battle_roster(full: Array[UnitPlacement]) -> Array[UnitPlacement]:
	# 만들 배치.
	var roster: Array[UnitPlacement] = []
	# 번호 기억을 새로 한다.
	_roster_indices.clear()
	# 파티원마다.
	for i in full.size():
		# 쓰러졌으면 뺀다.
		if member_hp[i] <= 0:
			continue
		# 새 배치 (원본을 건드리지 않는다).
		var placement := UnitPlacement.new()
		# 같은 데이터.
		placement.unit_data = full[i].unit_data
		# 같은 칸.
		placement.cell = full[i].cell
		# 지금 체력으로 시작.
		placement.start_hp = member_hp[i]
		# 넣는다.
		roster.append(placement)
		# 어느 파티원이었는지 기억한다.
		_roster_indices.append(i)
	# 돌려준다.
	return roster


## 전투가 끝난 뒤 아군 최종 체력(배치 순서)을 파티원 번호로 되돌려 쓴다.
func apply_battle_hp(final_hp: Array[int]) -> void:
	# 둘 중 짧은 쪽까지.
	for k in mini(final_hp.size(), _roster_indices.size()):
		# 0 아래로 내려가지 않게.
		member_hp[_roster_indices[k]] = maxi(0, final_hp[k])


## 전투 결과를 반영한다. 지면 실패, 보스에서 이기면 성공, 그 외 승리는 계속.
func finish_battle(won: bool) -> void:
	# 이미 끝났으면 무시.
	if is_finished():
		return
	# 패배.
	if not won:
		state = State.FAILED
	# 보스 승리.
	elif current_id == graph.boss_id:
		state = State.SUCCEEDED


## 도망: 의뢰 실패.
func fail() -> void:
	# 진행 중일 때만.
	if not is_finished():
		state = State.FAILED
