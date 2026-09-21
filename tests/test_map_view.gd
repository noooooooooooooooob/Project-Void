extends TestCase

const MapViewScript := preload("res://Scripts/view/map_view.gd")
const MapRunStateScript := preload("res://Scripts/map/map_run_state.gd")


func run() -> Array[Dictionary]:
	_test_creates_a_button_per_node()
	_test_button_press_emits_node_selected()
	_test_sync_enables_only_selectable_nodes()
	_test_result_banner()
	return results()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _map_view() -> MapView:
	var view: MapView = MapViewScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	return view


func _test_creates_a_button_per_node() -> void:
	var view: MapView = _map_view()
	check_eq("one button per node", view.button_count(), 10)
	view.free()


func _test_button_press_emits_node_selected() -> void:
	var view: MapView = _map_view()
	var seen: Array[int] = []
	view.node_selected.connect(func(node_id: int) -> void: seen.append(node_id))
	view.button_for(5).pressed.emit()
	check_eq("pressing a button reports its node id", seen, [5])
	view.free()


func _test_sync_enables_only_selectable_nodes() -> void:
	var view: MapView = _map_view()
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	view.sync_from_state(run_state)
	check("branch 0 head is enabled", not view.button_for(1).disabled)
	check("branch 1 head is enabled", not view.button_for(5).disabled)
	check("unreached step is disabled", view.button_for(2).disabled)
	check("start is disabled once left behind as current", view.button_for(0).disabled)
	view.free()


func _test_result_banner() -> void:
	var view: MapView = _map_view()
	check("banner hidden by default", not view.result_visible())
	view.show_result("런 클리어")
	check("banner visible after show_result", view.result_visible())
	check_eq("banner shows the given text", view.result_text(), "런 클리어")
	view.hide_result()
	check("banner hidden after hide_result", not view.result_visible())
	view.free()
