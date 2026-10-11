## 의뢰 1층 격자의 칸 하나. 위치(줄·걸음), 종류, 다음으로 갈 수 있는 칸 목록을 가진다.
## 지나왔는지 같은 진행 상태는 여기 두지 않는다 — CommissionRun 이 관리한다.
class_name StageNode
# RefCounted: 노드가 아닌 가벼운 객체.
extends RefCounted

## 칸 종류. EVENT / SHOP / REST 는 지금은 빈 칸(들어가면 이동만 한다).
enum Kind { START, BATTLE, EVENT, SHOP, REST, BOSS }

## 격자 안에서 칸을 구분하는 번호. StageGraph.nodes 배열의 위치와 같다.
var id: int
## 세로 줄 (0 이 위). 시작·보스는 가운데 줄.
var lane: int
## 가로 걸음 (0 이 첫 칸). 시작은 -1, 보스는 StageGraph.STEPS.
var step: int
## 칸 종류.
var kind: Kind
## 이 칸에서 이어지는 칸 id 목록.
var connections: Array[int] = []


## 위치·종류로 칸을 만든다. 연결은 StageGraph 가 채운다.
func _init(p_id: int, p_lane: int, p_step: int, p_kind: Kind) -> void:
	# 번호.
	id = p_id
	# 줄.
	lane = p_lane
	# 걸음.
	step = p_step
	# 종류.
	kind = p_kind


## 아직 효과가 없는 빈 칸(이벤트·상점·휴식)이면 true.
func is_empty_room() -> bool:
	# 세 종류 중 하나인지.
	return kind == Kind.EVENT or kind == Kind.SHOP or kind == Kind.REST
