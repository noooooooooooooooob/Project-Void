## 지도 위 노드 하나. 위치(행·열), 종류, 다음으로 갈 수 있는 노드 목록을 가진다.
## 깼는지 같은 진행 상태는 여기 두지 않는다 — MapRunState 가 따로 관리한다.
class_name MapNode
# RefCounted: 노드가 아닌 가벼운 객체. 참조가 없어지면 자동으로 해제된다.
extends RefCounted

## 노드 종류.
## START: 출발점. 전투 없음.
## STORY: 본 이야기 노드. 한 번 깨면 다음 이야기 노드가 열린다.
## FARM: 반복 파밍 노드. 부모 이야기 노드를 깬 뒤로는 몇 번이든 다시 들어갈 수 있다.
## BOSS: 본 이야기의 마지막 노드.
enum Kind { START, STORY, FARM, BOSS }

## 그래프 안에서 노드를 구분하는 번호. MapGraph.nodes 배열의 위치와 같다.
var id: int
## 세로 위치. 시작은 -1, 이야기 노드는 몇 번째인지(0부터), 파밍 노드는 부모와 같은 행.
var row: int
## 가로 위치. 이야기 길(가운데)이 0, 왼쪽이 음수, 오른쪽이 양수.
var col: int
## 노드 종류.
var kind: Kind
## FARM 노드가 매달린 이야기 노드 id. 그 외 종류는 -1.
var parent_id: int
## 이 노드에서 이어지는 노드 id 목록 (지도에 선으로 그려진다).
var connections: Array[int] = []

## 보스 노드면 true.
var is_boss: bool:
	get:
		# 종류가 BOSS 인지 비교한다.
		return kind == Kind.BOSS


## 위치·종류로 노드를 만든다. 연결은 만든 뒤 MapGraph 가 채운다.
func _init(p_id: int, p_row: int, p_col: int, p_kind: Kind, p_parent_id: int = -1) -> void:
	# 번호를 기억한다.
	id = p_id
	# 세로 위치를 기억한다.
	row = p_row
	# 가로 위치를 기억한다.
	col = p_col
	# 종류를 기억한다.
	kind = p_kind
	# 매달린 이야기 노드를 기억한다 (파밍 노드가 아니면 -1).
	parent_id = p_parent_id
