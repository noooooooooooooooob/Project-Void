## 한 런의 맵 생김새. 시작점 하나에서 갈래가 갈라졌다가 보스에서 다시 만난다.
## 어디까지 깼는지 같은 진행 상황은 들고 있지 않다 — 그건 MapRunState 의 몫이다.
class_name MapGraph
# RefCounted: 노드가 아닌 가벼운 객체.
extends RefCounted

## 갈라지는 길의 수.
const BRANCH_COUNT: int = 2
## 갈래 하나에 들어가는 전투 칸 수.
const STEPS_PER_BRANCH: int = 4

## 시작점의 번호. 가장 먼저 만들므로 항상 0 이다.
var start_id: int = 0
## 보스 점의 번호.
var boss_id: int
## 모든 점. 첨자가 곧 점 번호가 되도록 번호 순서대로 넣는다.
var nodes: Array[MapNode] = []


## 맵을 통째로 만든다. 시작점 → 갈래들 → 보스 순서로 점을 만들며 연결을 이어 붙인다.
func _init() -> void:
	# 시작점 1 개와 갈래 칸 전부가 쓰고 남은 다음 번호가 보스 몫이다.
	boss_id = BRANCH_COUNT * STEPS_PER_BRANCH + 1

	# 0 번 시작점. 갈래에 속하지 않으므로 갈래·칸은 -1.
	var start := MapNode.new(start_id, -1, -1, false)
	# 첫 번째 점으로 넣는다.
	nodes.append(start)

	# 갈래를 하나씩 만든다.
	for branch in BRANCH_COUNT:
		# 갈래의 첫 칸은 시작점에서 이어진다.
		var previous: MapNode = start
		# 갈래 안의 칸을 앞에서부터 만든다.
		for step in STEPS_PER_BRANCH:
			# 시작점 1 개를 건너뛰고, 앞선 갈래들이 쓴 번호 다음부터 매긴다.
			var id: int = 1 + branch * STEPS_PER_BRANCH + step
			# 이 칸의 점.
			var node := MapNode.new(id, branch, step, false)
			# 앞 칸에서 이 칸으로 가는 길을 잇는다.
			previous.connections.append(id)
			# 점 목록에 넣는다 (첨자 = 번호).
			nodes.append(node)
			# 다음 바퀴에서는 이 칸이 앞 칸이 된다.
			previous = node
		# 갈래의 마지막 칸은 보스로 이어진다.
		previous.connections.append(boss_id)

	# 보스가 가장 큰 번호이므로 맨 뒤에 넣어야 첨자와 번호가 맞는다.
	nodes.append(MapNode.new(boss_id, -1, -1, true))


## 번호로 점을 찾는다.
func get_node(id: int) -> MapNode:
	# 번호가 곧 첨자라 그대로 꺼내면 된다.
	return nodes[id]


## 점의 총 개수.
func node_count() -> int:
	# 목록 길이가 곧 개수.
	return nodes.size()
