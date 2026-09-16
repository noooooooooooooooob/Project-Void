extends SceneTree

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
	"res://tests/test_map_graph.gd",
	"res://tests/test_map_layout.gd",
	"res://tests/test_encounter_generator.gd",
	"res://tests/test_map_run_state.gd",
	"res://tests/test_map_view.gd",
]

var _started: bool = false


# _initialize() 시점에는 root 가 아직 트리 밖이라, 노드를 붙이는 테스트에서 _ready 가 돌지 않는다.
func _process(_delta: float) -> bool:
	if _started:
		return false
	_started = true
	_run_all()
	return false


func _run_all() -> void:
	var total: int = 0
	var failures: int = 0

	for path in TEST_SCRIPTS:
		var script: GDScript = load(path)
		if script == null:
			push_error("could not load test script: %s" % path)
			failures += 1
			continue

		print("\n== %s" % path)
		var suite: Object = script.new()
		var suite_results: Variant = suite.call("run")
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

	print("\n%d/%d passed" % [total - failures, total])
	quit(1 if failures > 0 else 0)
