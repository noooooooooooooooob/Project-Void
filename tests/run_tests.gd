# 헤드리스 테스트 실행기. 에디터 없이 명령줄에서 모든 테스트를 돌린다.
# 실행: Godot --headless --path <프로젝트> --script res://tests/run_tests.gd
# 끝나면 "통과/전체" 를 출력하고, 하나라도 실패하면 종료 코드 1 로 끝난다.
# SceneTree 를 상속하면 --script 로 직접 실행되는 메인 루프가 된다.
extends SceneTree

# 차례로 실행할 테스트 스크립트 목록. 새 테스트 파일을 만들면 여기에 추가해야 실행된다.
const TEST_SCRIPTS: Array[String] = [
	"res://tests/test_harness_smoke.gd",
	"res://tests/test_data.gd",
	"res://tests/test_unit.gd",
	"res://tests/test_target_resolver.gd",
	"res://tests/test_battle_state.gd",
	"res://tests/test_turn_order.gd",
	"res://tests/test_enemy_brain.gd",
	"res://tests/test_battle_signals.gd",
	"res://tests/test_event_recorder.gd",
	"res://tests/test_board_layout.gd",
	"res://tests/test_unit_view.gd",
	"res://tests/test_board_3d.gd",
	"res://tests/test_battle_hud.gd",
	"res://tests/test_battle_playback.gd",
	"res://tests/test_card_zone_signals.gd",
	"res://tests/test_card_view.gd",
	"res://tests/test_pile_view.gd",
	"res://tests/test_hand_layout.gd",
	"res://tests/test_hand_view.gd",
	"res://tests/test_turn_phases.gd",
]

# 테스트를 이미 시작했는지 (첫 프레임에 한 번만 돌리기 위해).
var _started: bool = false


# _initialize() 시점에는 root 가 아직 트리 밖이라, 노드를 붙이는 테스트에서 _ready 가 돌지 않는다.
# 매 프레임 불린다. false 를 돌려주면 메인 루프가 계속 돈다 (종료는 quit() 이 한다).
func _process(_delta: float) -> bool:
	# 두 번째 프레임부터는 아무것도 하지 않는다.
	if _started:
		return false
	# 시작했다고 표시한다.
	_started = true
	# 모든 테스트를 돌린다.
	_run_all()
	# 계속 돌게 둔다 (_run_all 안의 quit 가 끝낸다).
	return false


# 목록의 테스트 스크립트를 하나씩 불러 run() 을 실행하고 결과를 출력한다.
func _run_all() -> void:
	# 전체 검사 수.
	var total: int = 0
	# 실패 수.
	var failures: int = 0

	# 테스트 스크립트마다.
	for path in TEST_SCRIPTS:
		# 스크립트를 불러온다 (문법 오류가 있으면 null).
		var script: GDScript = load(path)
		# 불러오지 못했으면 실패로 세고 다음으로.
		if script == null:
			push_error("could not load test script: %s" % path)
			failures += 1
			continue

		# 어느 스크립트인지 제목을 출력한다.
		print("\n== %s" % path)
		# 테스트 객체를 만든다.
		var suite: Object = script.new()
		# run() 을 불러 결과 배열을 받는다.
		var suite_results: Variant = suite.call("run")
		# 배열이 아니면(스크립트 오류로 중간에 멈춘 경우 등) 실패로 센다.
		if not (suite_results is Array):
			print("  FAIL  %s -- suite did not return results" % path)
			failures += 1
			continue
		# 검사 결과마다.
		for result in suite_results:
			# 전체 수를 센다.
			total += 1
			# 통과면 PASS 출력.
			if result["ok"]:
				print("  PASS  %s" % result["name"])
			# 실패면 실패 수를 세고 FAIL 과 이유를 출력.
			else:
				failures += 1
				print("  FAIL  %s  -- %s" % [result["name"], result["message"]])

	# 최종 "통과/전체" 를 출력한다.
	print("\n%d/%d passed" % [total - failures, total])
	# 실패가 있으면 종료 코드 1, 없으면 0 으로 끝낸다.
	quit(1 if failures > 0 else 0)
