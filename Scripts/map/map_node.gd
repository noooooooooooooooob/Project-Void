## 맵 위의 점 하나. 전투 한 판(또는 시작점·보스)에 대응한다.
## 화면 좌표는 들고 있지 않다 — 그건 branch/step 을 보고 MapLayout 이 계산한다.
class_name MapNode
# RefCounted: 노드가 아닌 가벼운 객체. 참조가 없어지면 자동으로 해제된다.
extends RefCounted

## 맵 안에서 이 점을 가리키는 번호. MapGraph.nodes 의 첨자와 같다.
var id: int
## 몇 번째 갈래에 속하는지 (0 또는 1). 갈래에 속하지 않는 시작점과 보스는 -1.
var branch: int
## 갈래 안에서 몇 번째 칸인지 (0 부터). 시작점과 보스는 -1.
var step: int
## 보스 점이면 true.
var is_boss: bool
## 여기서 갈 수 있는 다음 점들의 번호. 만들 때는 비어 있고 MapGraph 가 이어 붙인다.
var connections: Array[int] = []


## 번호·갈래·칸·보스 여부를 정해 점을 만든다.
func _init(p_id: int, p_branch: int, p_step: int, p_is_boss: bool) -> void:
	# 점 번호를 저장한다.
	id = p_id
	# 갈래 번호를 저장한다.
	branch = p_branch
	# 갈래 안 칸 번호를 저장한다.
	step = p_step
	# 보스 여부를 저장한다.
	is_boss = p_is_boss
