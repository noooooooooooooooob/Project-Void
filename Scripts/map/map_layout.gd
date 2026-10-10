## 지도 노드의 화면 좌표를 계산하는 도구. 노드의 행·열(MapNode.row/col)을 픽셀 위치로 바꾼다.
class_name MapLayout
# RefCounted: 노드가 아닌 가벼운 객체. 정적 함수만 쓰므로 만들 일은 없다.
extends RefCounted

## 행 사이 세로 간격 (픽셀).
const ROW_SPACING: float = 130.0
## 열 사이 가로 간격 (픽셀).
const COL_SPACING: float = 190.0


## 노드가 그려질 위치. 이야기 길(col 0)이 x = 0 이고, 시작 노드(row -1)가 y = 0 이 된다.
static func node_position(node: MapNode) -> Vector2:
	# 열 번호에 가로 간격을 곱한다 (왼쪽은 음수).
	var x: float = float(node.col) * COL_SPACING
	# 시작 노드의 행이 -1 이므로 1 을 더해 맨 위를 0 으로 맞춘다.
	var y: float = float(node.row + 1) * ROW_SPACING
	# 두 값을 묶어 돌려준다.
	return Vector2(x, y)
