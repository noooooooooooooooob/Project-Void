class_name MapNode
extends RefCounted

## 노드 종류.
## START: 출발점. 전투 없음.
## STORY: 본 이야기 노드. 한 번 깨면 다음 이야기 노드가 열린다.
## FARM: 반복 파밍 노드. 부모 이야기 노드를 깬 뒤로는 몇 번이든 다시 들어갈 수 있다.
## BOSS: 본 이야기의 마지막 노드.
enum Kind { START, STORY, FARM, BOSS }

var id: int
## 세로 위치. 시작은 -1, 이야기 노드는 몇 번째인지(0부터), 파밍 노드는 부모와 같은 행.
var row: int
## 가로 위치. 이야기 길(가운데)이 0, 왼쪽이 음수, 오른쪽이 양수.
var col: int
var kind: Kind
## FARM 노드가 매달린 이야기 노드 id. 그 외 종류는 -1.
var parent_id: int
var connections: Array[int] = []

var is_boss: bool:
	get:
		return kind == Kind.BOSS


func _init(p_id: int, p_row: int, p_col: int, p_kind: Kind, p_parent_id: int = -1) -> void:
	id = p_id
	row = p_row
	col = p_col
	kind = p_kind
	parent_id = p_parent_id
