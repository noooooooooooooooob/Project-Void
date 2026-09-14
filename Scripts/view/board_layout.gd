## 격자 칸 좌표를 3D 공간 위치로 바꾸는 계산 도우미 (노드 없음, 순수 계산).
## 아군은 왼쪽(-x), 적군은 오른쪽(+x)에 놓이고, 두 격자 사이에 SIDE_GAP 만큼 틈이 있다.
## 행(cell.y)은 앞뒤 방향(z)으로 펼쳐진다.
class_name BoardLayout
# RefCounted: 노드가 아닌 가벼운 객체.
extends RefCounted

## 타일 한 장의 한 변 길이 (3D 단위).
const TILE_SIZE: float = 1.0
## 이웃한 칸 중심 사이의 거리. 타일보다 조금 커서 타일 사이에 틈이 보인다.
const CELL_PITCH: float = 1.1
## 아군 격자와 적군 격자 사이의 빈 공간 폭.
const SIDE_GAP: float = 1.5

## 아군 격자 크기 (x = 열 수, y = 행 수).
var ally_grid: Vector2i
## 적군 격자 크기 (x = 열 수, y = 행 수).
var enemy_grid: Vector2i


## 양쪽 격자 크기를 받아 저장한다.
func _init(p_ally_grid: Vector2i, p_enemy_grid: Vector2i) -> void:
	# 아군 격자 크기를 기억한다.
	ally_grid = p_ally_grid
	# 적군 격자 크기를 기억한다.
	enemy_grid = p_enemy_grid


## 편과 칸 좌표로 그 칸 중심의 3D 위치를 구한다 (높이 y 는 0).
func cell_position(team: Unit.Team, cell: Vector2i) -> Vector3:
	# 아군은 왼쪽(-1), 적군은 오른쪽(+1)으로 뻗어 나간다.
	var side: float = -1.0 if team == Unit.Team.ALLY else 1.0
	# 그 편 격자의 행 수.
	var rows: int = ally_grid.y if team == Unit.Team.ALLY else enemy_grid.y
	# x: 가운데 틈의 절반 + 칸 절반(첫 칸 중심까지) + 열 번호만큼의 칸 거리. 앞줄(x=0)이 가운데에 가장 가깝다.
	var x: float = side * (SIDE_GAP / 2.0 + CELL_PITCH / 2.0 + cell.x * CELL_PITCH)
	# 규칙과 같은 중앙 정렬 함수를 써야 화면상 행 어긋남이 사거리 판정과 일치한다.
	var z: float = TargetResolver.center_offset(cell.y, rows) * CELL_PITCH
	# 계산한 위치를 돌려준다.
	return Vector3(x, 0.0, z)


## 보드 왼쪽 끝(아군 맨 뒷줄 바깥 가장자리)의 x 좌표.
func min_x() -> float:
	# 가운데 틈 절반 + 아군 열 수만큼의 폭을 왼쪽(음수)으로.
	return -(SIDE_GAP / 2.0 + ally_grid.x * CELL_PITCH)


## 보드 오른쪽 끝(적군 맨 뒷줄 바깥 가장자리)의 x 좌표.
func max_x() -> float:
	# 가운데 틈 절반 + 적군 열 수만큼의 폭을 오른쪽(양수)으로.
	return SIDE_GAP / 2.0 + enemy_grid.x * CELL_PITCH


## 보드 전체의 가로 폭.
func width() -> float:
	# 오른쪽 끝 - 왼쪽 끝.
	return max_x() - min_x()


## 보드 전체의 앞뒤 깊이 (행 수가 많은 쪽 기준).
func depth() -> float:
	# 두 격자 중 행이 많은 쪽의 행 수 × 칸 간격.
	return maxi(ally_grid.y, enemy_grid.y) * CELL_PITCH


## 보드의 가운데 점. 카메라가 이 점을 바라본다.
func center() -> Vector3:
	# 좌우 끝의 중간. 행은 이미 가운데 정렬(z=0 중심)이므로 z 는 0.
	return Vector3((min_x() + max_x()) / 2.0, 0.0, 0.0)


## 보드 전체가 화면에 들어오도록 카메라를 얼마나 멀리 둘지 계산한다.
## 가로와 세로 각각 필요한 거리를 구해 더 먼 쪽을 쓴다. margin 은 여백 배율 (1.0 = 딱 맞게).
static func camera_distance(board_width: float, board_depth: float, vertical_fov_deg: float, aspect: float, margin: float) -> float:
	# 세로 시야각의 절반 (라디안).
	var half_vertical: float = deg_to_rad(vertical_fov_deg) / 2.0
	# 화면 가로세로 비율로 가로 시야각의 절반을 구한다.
	var half_horizontal: float = atan(tan(half_vertical) * aspect)
	# 보드 폭(여백 포함)의 절반이 가로 시야 끝에 닿는 거리.
	var for_width: float = (board_width * margin / 2.0) / tan(half_horizontal)
	# 보드 깊이(여백 포함)의 절반이 세로 시야 끝에 닿는 거리.
	var for_depth: float = (board_depth * margin / 2.0) / tan(half_vertical)
	# 둘 다 들어오려면 더 먼 거리가 필요하다.
	return maxf(for_width, for_depth)
