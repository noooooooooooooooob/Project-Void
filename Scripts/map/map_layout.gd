## 맵 점의 갈래·칸 번호를 화면에 그릴 2D 자리로 바꾸는 계산 도우미 (노드 없음, 순수 계산).
## 여기서 y 는 위로 갈수록 커지는 "런의 진행 방향"이다.
## 화면 좌표(y 가 아래로 늘어나는)로 뒤집는 일은 MapView 가 한다.
class_name MapLayout
# RefCounted: 노드가 아닌 가벼운 객체.
extends RefCounted

## 같은 갈래에서 이웃한 칸 사이의 거리.
const STEP_SPACING: float = 120.0
## 두 갈래 사이의 좌우 거리.
const BRANCH_SPACING: float = 220.0


## 점 하나의 자리를 구한다. 시작점은 원점, 보스는 맨 끝 가운데, 나머지는 갈래별로 좌우에 놓인다.
static func node_position(node: MapNode) -> Vector2:
	# 갈래에 속하지 않는 점(시작점과 보스)은 가운데 줄에 선다.
	if node.branch < 0:
		# 보스는 갈래의 마지막 칸보다 한 칸 더 멀리.
		if node.is_boss:
			return Vector2(0.0, (MapGraph.STEPS_PER_BRANCH + 1) * STEP_SPACING)
		# 시작점은 원점.
		return Vector2.ZERO

	# 갈래 0 은 왼쪽(-1), 갈래 1 은 오른쪽(+1).
	var side: float = -1.0 if node.branch == 0 else 1.0
	# 가운데에서 갈래 간격의 절반만큼 좌우로 벌린다.
	var x: float = side * BRANCH_SPACING / 2.0
	# 첫 칸(step 0)이 시작점보다 한 칸 앞에 오도록 +1.
	var y: float = (node.step + 1) * STEP_SPACING
	# 계산한 자리를 돌려준다.
	return Vector2(x, y)
