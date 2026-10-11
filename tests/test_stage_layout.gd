# StageLayout(의뢰 격자 좌표) 테스트: 시작이 x 0, 걸음마다 오른쪽, 줄마다 아래.
extends TestCase

# 칸 스크립트.
const StageNodeScript := preload("res://Scripts/map/stage_node.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 시작.
	var start: StageNode = StageNodeScript.new(0, 1, -1, StageNode.Kind.START)
	check_eq("start sits at x 0", StageLayout.node_position(start), Vector2(0.0, StageLayout.LANE_SPACING))
	# (2, 3) 칸.
	var cell: StageNode = StageNodeScript.new(5, 2, 3, StageNode.Kind.BATTLE)
	check_eq("cell (2,3) position", StageLayout.node_position(cell), Vector2(4.0 * StageLayout.STEP_SPACING, 2.0 * StageLayout.LANE_SPACING))
	# 결과를 돌려준다.
	return results()
