# MapLayout(맵 점의 갈래·칸 번호 → 그릴 자리) 테스트.
# y 는 위로 갈수록 커지는 "런의 진행 방향"이다 (화면 좌표로 뒤집는 일은 MapView 가 한다).
extends TestCase

# 점을 만들어 줄 맵 생김새 스크립트.
const MapGraphScript := preload("res://Scripts/map/map_graph.gd")
# 자리 계산 스크립트.
const MapLayoutScript := preload("res://Scripts/map/map_layout.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 시작점은 원점.
	_test_start_at_origin()
	# 두 갈래가 좌우 대칭.
	_test_branches_are_mirrored()
	# 칸이 뒤로 갈수록 멀어진다.
	_test_steps_move_away_from_start()
	# 보스가 가장 멀고 가운데.
	_test_boss_is_farthest_and_centred()
	# 결과를 돌려준다.
	return results()


# 테스트마다 쓸 맵을 새로 만든다.
func _graph() -> MapGraph:
	# 생김새는 언제나 같으므로 인자가 필요 없다.
	return MapGraphScript.new()


# 시작점이 원점에 놓이는지 (나머지 자리가 모두 여기서부터 잰다).
func _test_start_at_origin() -> void:
	# 맵을 만든다.
	var graph: MapGraph = _graph()
	# 0 번이 시작점.
	check_eq("start sits at the origin", MapLayoutScript.node_position(graph.get_node(0)), Vector2.ZERO)


# 같은 칸 번호면 두 갈래가 좌우로 거울처럼 놓이고 높이는 같은지.
func _test_branches_are_mirrored() -> void:
	# 맵을 만든다.
	var graph: MapGraph = _graph()
	# 갈래 0 의 첫 칸.
	var branch0: Vector2 = MapLayoutScript.node_position(graph.get_node(1))
	# 갈래 1 의 첫 칸.
	var branch1: Vector2 = MapLayoutScript.node_position(graph.get_node(5))
	# 갈래 0 은 왼쪽.
	check("branch 0 is on one side", branch0.x < 0.0)
	# 갈래 1 은 오른쪽.
	check("branch 1 is on the other side", branch1.x > 0.0)
	# 가운데에서 같은 거리.
	check("same step mirrors in x", is_equal_approx(-branch0.x, branch1.x))
	# 같은 칸 번호면 높이도 같다.
	check("same step matches in y", is_equal_approx(branch0.y, branch1.y))


# 갈래 안에서 칸이 뒤로 갈수록 시작점에서 멀어지는지.
func _test_steps_move_away_from_start() -> void:
	# 맵을 만든다.
	var graph: MapGraph = _graph()
	# 갈래 0 의 첫 칸.
	var step0: Vector2 = MapLayoutScript.node_position(graph.get_node(1))
	# 갈래 0 의 둘째 칸.
	var step1: Vector2 = MapLayoutScript.node_position(graph.get_node(2))
	# 갈래 0 의 마지막 칸.
	var step3: Vector2 = MapLayoutScript.node_position(graph.get_node(4))
	# 둘째 칸이 첫 칸보다 멀다.
	check("step 1 is farther than step 0", step1.y > step0.y)
	# 마지막 칸이 가장 멀다.
	check("step 3 is the farthest regular step", step3.y > step1.y)


# 보스가 어느 갈래의 마지막 칸보다도 멀고, 좌우 가운데에 놓이는지.
func _test_boss_is_farthest_and_centred() -> void:
	# 맵을 만든다.
	var graph: MapGraph = _graph()
	# 갈래 0 의 마지막 칸.
	var last_step: Vector2 = MapLayoutScript.node_position(graph.get_node(4))
	# 보스.
	var boss: Vector2 = MapLayoutScript.node_position(graph.get_node(9))
	# 보스가 더 멀다.
	check("boss is farther than the last regular step", boss.y > last_step.y)
	# 두 갈래가 모두 이어지므로 좌우 가운데여야 한다.
	check_eq("boss is centred", boss.x, 0.0)
