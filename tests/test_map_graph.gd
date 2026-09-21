# MapGraph(런 맵의 생김새 — 시작점에서 두 갈래로 갈라졌다가 보스에서 만난다) 테스트.
extends TestCase

# 맵 생김새 스크립트.
const MapGraphScript := preload("res://Scripts/map/map_graph.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 점 개수와 번호.
	_test_node_count()
	# 시작점에서 두 갈래로 갈라진다.
	_test_start_connects_to_both_branch_heads()
	# 갈래 안은 한 줄로만 이어진다.
	_test_branch_is_a_linear_chain()
	# 두 갈래가 보스에서 만난다.
	_test_branch_tails_converge_on_boss()
	# 보스 표시.
	_test_boss_flag()
	# 결과를 돌려준다.
	return results()


# 시작점 1 + 갈래 2 × 칸 4 + 보스 1 = 10 개이고, 번호가 첨자와 맞는지.
func _test_node_count() -> void:
	# 맵을 만든다.
	var graph: MapGraph = MapGraphScript.new()
	# 점 개수.
	check_eq("10 nodes total", graph.node_count(), 10)
	# 목록 길이도 같아야 한다 (번호 = 첨자가 성립하는지).
	check_eq("nodes array matches count", graph.nodes.size(), 10)
	# 보스가 마지막 번호.
	check_eq("boss id is last", graph.boss_id, 9)
	# 시작점이 첫 번호.
	check_eq("start id is 0", graph.start_id, 0)


# 시작점에서 두 갈래의 첫 칸(1, 5)으로만 갈 수 있는지.
func _test_start_connects_to_both_branch_heads() -> void:
	# 맵을 만든다.
	var graph: MapGraph = MapGraphScript.new()
	# 갈래 0 은 1 번, 갈래 1 은 5 번에서 시작한다.
	check_eq("start connects to branch heads", graph.get_node(0).connections, [1, 5])


# 갈래 안에서는 다음 칸 하나로만 이어져 도중에 갈라지지 않는지.
func _test_branch_is_a_linear_chain() -> void:
	# 맵을 만든다.
	var graph: MapGraph = MapGraphScript.new()
	# 갈래 0 의 첫 칸에서 둘째 칸으로.
	check_eq("branch 0 step 0 -> step 1", graph.get_node(1).connections, [2])
	# 갈래 0 의 둘째 칸에서 셋째 칸으로.
	check_eq("branch 0 step 1 -> step 2", graph.get_node(2).connections, [3])
	# 갈래 1 도 같은 모양 (번호만 4 만큼 뒤).
	check_eq("branch 1 step 0 -> step 1", graph.get_node(5).connections, [6])
	# 갈래 1 의 둘째 칸에서 셋째 칸으로.
	check_eq("branch 1 step 1 -> step 2", graph.get_node(6).connections, [7])


# 두 갈래의 마지막 칸이 모두 보스로 이어지고, 보스에서는 더 갈 곳이 없는지.
func _test_branch_tails_converge_on_boss() -> void:
	# 맵을 만든다.
	var graph: MapGraph = MapGraphScript.new()
	# 갈래 0 의 마지막 칸(4)에서 보스로.
	check_eq("branch 0 tail connects to boss", graph.get_node(4).connections, [9])
	# 갈래 1 의 마지막 칸(8)에서도 같은 보스로.
	check_eq("branch 1 tail connects to boss", graph.get_node(8).connections, [9])
	# 보스가 런의 끝이므로 나가는 길이 없다.
	check("boss has no outgoing connections", graph.get_node(9).connections.is_empty())


# 보스 표시가 보스 점에만 붙어 있는지.
func _test_boss_flag() -> void:
	# 맵을 만든다.
	var graph: MapGraph = MapGraphScript.new()
	# 마지막 점이 보스.
	check("node 9 is the boss", graph.get_node(9).is_boss)
	# 시작점은 보스가 아니다.
	check("start is not the boss", not graph.get_node(0).is_boss)
	# 보통 칸도 보스가 아니다.
	check("a regular step is not the boss", not graph.get_node(3).is_boss)
