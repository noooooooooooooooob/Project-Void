# 헤드리스 테스트 실행기. 에디터 없이 명령줄에서 모든 테스트를 돌린다.
# 실행: Godot --headless --path <프로젝트> --script res://tests/run_tests.gd
# 끝나면 "통과/전체" 를 출력하고, 하나라도 실패하면 종료 코드 1 로 끝난다.
extends SceneTree

# 차례로 실행할 테스트 스크립트 목록. 새 테스트 파일을 만들면 여기에 추가해야 실행된다.
const TEST_SCRIPTS: Array[String] = [
	"res://tests/test_harness_smoke.gd",
	"res://tests/test_data.gd",
	"res://tests/test_card_math.gd",
	"res://tests/test_unit.gd",
	"res://tests/test_target_resolver.gd",
	"res://tests/test_battle_state.gd",
	"res://tests/test_turn_order.gd",
	"res://tests/test_enemy_brain.gd",
	"res://tests/test_battle_signals.gd",
	"res://tests/test_event_recorder.gd",
	"res://tests/test_board_layout.gd",
	"res://tests/test_unit_motion.gd",
	"res://tests/test_unit_view.gd",
	"res://tests/test_board_3d.gd",
	"res://tests/test_battle_hud.gd",
	"res://tests/test_battle_playback.gd",
	"res://tests/test_card_zone_signals.gd",
	"res://tests/test_card_text.gd",
	"res://tests/test_card_view.gd",
	"res://tests/test_pile_view.gd",
	"res://tests/test_hand_layout.gd",
	"res://tests/test_hand_view.gd",
	"res://tests/test_turn_phases.gd",
	"res://tests/test_movement.gd",
	"res://tests/test_stagger_status.gd",
	"res://tests/test_encounter_generator.gd",
	"res://tests/test_item_data.gd",
	"res://tests/test_party_state.gd",
	"res://tests/test_party_view.gd",
	"res://tests/test_story.gd",
	"res://tests/test_expedition.gd",
	"res://tests/test_battle_sounds.gd",
	"res://tests/test_battle_camera.gd",
	"res://tests/test_projectile.gd",
	"res://tests/test_screen_pulse.gd",
	"res://tests/test_flee_menu.gd",
	"res://tests/test_battle_root.gd",
	"res://tests/test_battle_environment.gd",
	"res://tests/test_card_area_grid.gd",
]

var _started: bool = false


# _initialize() 시점에는 root 가 아직 트리 밖이라, 노드를 붙이는 테스트에서 _ready 가 돌지 않는다.
# 그래서 첫 프레임에 한 번 돌리고, 끝나면 _run_all 의 quit() 가 메인 루프를 멈춘다.
func _process(_delta: float) -> bool:
	if not _started:
		_started = true
		_run_all()
	return false


func _run_all() -> void:
	var total: int = 0
	var failures: int = 0
	for path in TEST_SCRIPTS:
		print("
== %s" % path)
		# 문법 오류가 있는 스크립트도 load 는 되지만 인스턴스를 만들 수 없다.
		var script: GDScript = load(path)
		if script == null or not script.can_instantiate():
			print("  FAIL  %s -- could not load (parse error?)" % path)
			failures += 1
			continue
		var suite_results: Variant = script.new().call("run")
		if not (suite_results is Array):
			print("  FAIL  %s -- suite did not return results" % path)
			failures += 1
			continue
		for result in suite_results:
			total += 1
			if result["ok"]:
				print("  PASS  %s" % result["name"])
			else:
				failures += 1
				print("  FAIL  %s  -- %s" % [result["name"], result["message"]])
	print("
%d/%d passed%s" % [total - failures, total, "" if failures == 0 else "  (%d failed)" % failures])
	quit(1 if failures > 0 else 0)
