class_name BoardLayout
extends RefCounted

const TILE_SIZE: float = 1.0
const CELL_PITCH: float = 1.1
const SIDE_GAP: float = 1.5

var ally_grid: Vector2i
var enemy_grid: Vector2i


func _init(p_ally_grid: Vector2i, p_enemy_grid: Vector2i) -> void:
	ally_grid = p_ally_grid
	enemy_grid = p_enemy_grid


func cell_position(team: Unit.Team, cell: Vector2i) -> Vector3:
	var side: float = -1.0 if team == Unit.Team.ALLY else 1.0
	var rows: int = ally_grid.y if team == Unit.Team.ALLY else enemy_grid.y
	var x: float = side * (SIDE_GAP / 2.0 + CELL_PITCH / 2.0 + cell.x * CELL_PITCH)
	# 규칙과 같은 중앙 정렬 함수를 써야 화면상 행 어긋남이 사거리 판정과 일치한다.
	var z: float = TargetResolver.center_offset(cell.y, rows) * CELL_PITCH
	return Vector3(x, 0.0, z)


func min_x() -> float:
	return -(SIDE_GAP / 2.0 + ally_grid.x * CELL_PITCH)


func max_x() -> float:
	return SIDE_GAP / 2.0 + enemy_grid.x * CELL_PITCH


func width() -> float:
	return max_x() - min_x()


func depth() -> float:
	return maxi(ally_grid.y, enemy_grid.y) * CELL_PITCH


func center() -> Vector3:
	return Vector3((min_x() + max_x()) / 2.0, 0.0, 0.0)


static func camera_distance(board_width: float, board_depth: float, vertical_fov_deg: float, aspect: float, margin: float) -> float:
	var half_vertical: float = deg_to_rad(vertical_fov_deg) / 2.0
	var half_horizontal: float = atan(tan(half_vertical) * aspect)
	var for_width: float = (board_width * margin / 2.0) / tan(half_horizontal)
	var for_depth: float = (board_depth * margin / 2.0) / tan(half_vertical)
	return maxf(for_width, for_depth)
