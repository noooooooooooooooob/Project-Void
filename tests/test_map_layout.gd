# MapLayout(지도 노드 화면 좌표) 테스트: 시작 위치, 열 좌우 대칭, 행이 멀어지는 방향, 보스 위치.
extends TestCase

# 지도 노드 스크립트.
const MapNodeScript := preload("res://Scripts/map/map_node.gd")
# 지도 좌표 계산 스크립트.
const MapLayoutScript := preload("res://Scripts/map/map_layout.gd")
# 지도 그래프 스크립트 (이야기 노드 수 상수용).
const MapGraphScript := preload("res://Scripts/map/map_graph.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 시작 노드는 원점.
	_test_start_centres_on_x_and_sits_at_y_zero()
	# 열은 가운데를 기준으로 좌우에 놓인다.
	_test_columns_spread_around_centre()
	# 행이 커질수록 시작에서 멀어진다.
	_test_rows_move_away_from_start()
	# 보스는 가장 멀고 가운데.
	_test_boss_is_farthest_and_centred()
	# 결과를 돌려준다.
	return results()


# 시작 노드(행 -1, 열 0)는 (0, 0) 에 놓인다.
func _test_start_centres_on_x_and_sits_at_y_zero() -> void:
	# 시작 노드를 만든다.
	var start := MapNodeScript.new(0, -1, 0, MapNodeScript.Kind.START)
	# 위치를 구한다.
	var pos: Vector2 = MapLayoutScript.node_position(start)
	# 가로는 가운데.
	check_eq("start centres on x", pos.x, 0.0)
	# 세로는 0.
	check_eq("start sits at y 0", pos.y, 0.0)


# 열 0 은 가운데, 열 -1 은 왼쪽, 열 1 은 오른쪽이고 좌우가 대칭이다.
func _test_columns_spread_around_centre() -> void:
	# 가운데 이야기 노드.
	var centre := MapNodeScript.new(1, 0, 0, MapNodeScript.Kind.STORY)
	# 왼쪽 파밍 노드.
	var left := MapNodeScript.new(2, 0, -1, MapNodeScript.Kind.FARM, 1)
	# 오른쪽 파밍 노드.
	var right := MapNodeScript.new(3, 0, 1, MapNodeScript.Kind.FARM, 1)
	# 가운데는 x = 0.
	check_eq("centre column sits on the axis", MapLayoutScript.node_position(centre).x, 0.0)
	# 왼쪽은 음수.
	check("one column left of centre sits left", MapLayoutScript.node_position(left).x < 0.0)
	# 오른쪽은 양수.
	check("one column right of centre sits right", MapLayoutScript.node_position(right).x > 0.0)
	# 좌우 거리가 같다.
	check_eq("left and right farms are symmetric", MapLayoutScript.node_position(left).x, -MapLayoutScript.node_position(right).x)


# 다음 행은 이전 행보다 y 가 크다.
func _test_rows_move_away_from_start() -> void:
	# 0 행 노드.
	var row0 := MapNodeScript.new(1, 0, 0, MapNodeScript.Kind.STORY)
	# 1 행 노드.
	var row1 := MapNodeScript.new(2, 1, 0, MapNodeScript.Kind.STORY)
	# 1 행이 더 멀다.
	check("row 1 is farther than row 0", MapLayoutScript.node_position(row1).y > MapLayoutScript.node_position(row0).y)


# 보스는 마지막 이야기 노드보다 멀고 가운데에 있다.
func _test_boss_is_farthest_and_centred() -> void:
	# 마지막 이야기 노드.
	var last_story := MapNodeScript.new(1, MapGraphScript.STORY_COUNT - 1, 0, MapNodeScript.Kind.STORY)
	# 보스 노드.
	var boss := MapNodeScript.new(2, MapGraphScript.STORY_COUNT, 0, MapNodeScript.Kind.BOSS)
	# 보스가 더 멀다.
	check("boss is farther than the last story node", MapLayoutScript.node_position(boss).y > MapLayoutScript.node_position(last_story).y)
	# 보스는 가운데.
	check_eq("boss is centred", MapLayoutScript.node_position(boss).x, 0.0)
