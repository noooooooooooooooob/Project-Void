## 의뢰 1층 격자 (거울던전식). 시작 → LANES 줄 × STEPS 칸 → 보스, 왼쪽에서 오른쪽으로 한 칸씩 간다.
## 모양만 가진다 — 어디까지 왔는지는 CommissionRun 이 관리한다.
class_name StageGraph
# RefCounted: 노드가 아닌 가벼운 객체.
extends RefCounted

## 세로 줄 수.
const LANES: int = 3
## 시작과 보스 사이 칸 수.
const STEPS: int = 5
## 굴릴 수 있는 칸 종류 (ROLL_WEIGHTS 와 같은 순서).
const ROLL_KINDS: Array[int] = [StageNode.Kind.BATTLE, StageNode.Kind.EVENT, StageNode.Kind.SHOP, StageNode.Kind.REST]
## 칸 종류 가중치: 전투 6 : 이벤트 2 : 상점 1 : 휴식 1.
const ROLL_WEIGHTS: Array[int] = [6, 2, 1, 1]

## 시작 칸 id. 가장 먼저 만들어서 항상 0.
var start_id: int = 0
## 보스 칸 id.
var boss_id: int
## 모든 칸. 배열 위치가 곧 id.
var nodes: Array[StageNode] = []


## 칸을 만들고 잇는다. 첫 칸 줄은 전투로 고정, 나머지는 가중치로 굴린다.
func _init(rng: RandomNumberGenerator) -> void:
	# 시작 칸 (가운데 줄, 걸음 -1).
	_add(1, -1, StageNode.Kind.START)
	# 걸음별 줄별 칸 id.
	var grid: Array[Array] = []
	# 걸음마다.
	for step in STEPS:
		# 이 걸음의 칸 id.
		var column: Array[int] = []
		# 줄마다.
		for lane in LANES:
			# 첫 걸음은 전투, 나머지는 굴린다.
			var kind: StageNode.Kind = StageNode.Kind.BATTLE if step == 0 else _roll_kind(rng)
			# 칸을 만든다.
			column.append(_add(lane, step, kind))
		# 기억한다.
		grid.append(column)
	# 보스 칸 (가운데 줄, 마지막 걸음 다음).
	boss_id = _add(1, STEPS, StageNode.Kind.BOSS)

	# 시작은 첫 걸음의 모든 칸과 잇는다.
	for id in grid[0]:
		nodes[start_id].connections.append(id)
	# 칸마다 다음 걸음과 잇는다.
	for step in STEPS:
		for lane in LANES:
			# 이 칸.
			var node: StageNode = nodes[grid[step][lane]]
			# 마지막 걸음은 보스로.
			if step == STEPS - 1:
				node.connections.append(boss_id)
				continue
			# 같은 줄과 위·아래 한 줄.
			for next_lane in range(maxi(0, lane - 1), mini(LANES - 1, lane + 1) + 1):
				node.connections.append(grid[step + 1][next_lane])


## id 로 칸을 찾는다.
func get_node(id: int) -> StageNode:
	# 배열 위치가 곧 id.
	return nodes[id]


## 칸 개수.
func node_count() -> int:
	# 배열 길이.
	return nodes.size()


## 줄·걸음으로 칸을 찾는다. 없으면 null.
func node_at(lane: int, step: int) -> StageNode:
	# 칸마다 비교한다.
	for node in nodes:
		if node.lane == lane and node.step == step:
			return node
	# 없다.
	return null


## 칸을 하나 만들어 끝에 붙이고 그 id 를 돌려준다.
func _add(lane: int, step: int, kind: StageNode.Kind) -> int:
	# 새 id = 지금 길이.
	var id: int = nodes.size()
	# 만들어 붙인다.
	nodes.append(StageNode.new(id, lane, step, kind))
	# id 를 돌려준다.
	return id


## 가중치로 칸 종류 하나를 뽑는다.
func _roll_kind(rng: RandomNumberGenerator) -> StageNode.Kind:
	# 가중치 합.
	var total: int = 0
	for weight in ROLL_WEIGHTS:
		total += weight
	# 1 ~ 합 중 하나.
	var roll: int = rng.randi_range(1, total)
	# 누적하며 어느 구간인지 찾는다.
	for i in ROLL_KINDS.size():
		roll -= ROLL_WEIGHTS[i]
		if roll <= 0:
			return ROLL_KINDS[i] as StageNode.Kind
	# 도달하지 않는다 (안전망).
	return StageNode.Kind.BATTLE
