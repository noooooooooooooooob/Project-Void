## 의뢰 격자 칸의 화면 좌표를 계산하는 도구. 칸의 줄·걸음(StageNode.lane/step)을 픽셀 위치로 바꾼다.
class_name StageLayout
# RefCounted: 정적 함수만 쓴다.
extends RefCounted

## 걸음 사이 가로 간격 (픽셀).
const STEP_SPACING: float = 150.0
## 줄 사이 세로 간격 (픽셀).
const LANE_SPACING: float = 110.0


## 칸이 그려질 위치. 시작(걸음 -1)이 x = 0, 위 줄(0)이 y = 0.
static func node_position(node: StageNode) -> Vector2:
	# 걸음에 1 을 더해 시작을 0 으로 맞춘다.
	var x: float = float(node.step + 1) * STEP_SPACING
	# 줄 번호에 세로 간격을 곱한다.
	var y: float = float(node.lane) * LANE_SPACING
	# 돌려준다.
	return Vector2(x, y)
