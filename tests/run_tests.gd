extends SceneTree

const TEST_SCRIPTS: Array[String] = [
	"res://tests/test_harness_smoke.gd",
	"res://tests/test_data.gd",
	"res://tests/test_unit.gd",
	"res://tests/test_target_resolver.gd",
	"res://tests/test_battle_state.gd",
	"res://tests/test_turn_order.gd",
]


func _initialize() -> void:
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
		var suite_results: Array = suite.call("run")
		for result in suite_results:
			total += 1
			if result["ok"]:
				print("  PASS  %s" % result["name"])
			else:
				failures += 1
				print("  FAIL  %s  -- %s" % [result["name"], result["message"]])

	print("\n%d/%d passed" % [total - failures, total])
	quit(1 if failures > 0 else 0)
