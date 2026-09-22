extends TestCase

const MapViewScript := preload("res://Scripts/view/map_view.gd")
const MapRunStateScript := preload("res://Scripts/map/map_run_state.gd")
const MapGraphScript := preload("res://Scripts/map/map_graph.gd")

func run() -> Array[Dictionary]:
	_test_creates_a_button_per_node()
	_test_button_press_emits_node_selected()
	_test_sync_enables_only_selectable_nodes()
	_test_rebuild_replaces_the_buttons_for_a_new_graph()
	_test_result_banner()
	return results()


func _rng(seed_value: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	return rng


func _run_state(seed_value: int) -> MapRunState:
	return MapRunStateScript.new(_rng(seed_value))


func _map_view(graph: MapGraph) -> MapView:
	var view: MapView = MapViewScript.new(graph)
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	return view


func _test_creates_a_button_per_node() -> void:
	var run_state: MapRunState = _run_state(1)
	var view: MapView = _map_view(run_state.graph)
	check_eq("one button per node", view.button_count(), run_state.graph.node_count())
	view.free()


func _test_button_press_emits_node_selected() -> void:
	var run_state: MapRunState = _run_state(1)
	var view: MapView = _map_view(run_state.graph)
	var head: int = run_state.graph.get_node(run_state.graph.start_id).connections[0]
	var seen: Array[int] = []
	view.node_selected.connect(func(node_id: int) -> void: seen.append(node_id))
	view.button_for(head).pressed.emit()
	check_eq("pressing a button reports its node id", seen, [head])
	view.free()


func _test_sync_enables_only_selectable_nodes() -> void:
	var run_state: MapRunState = _run_state(1)
	var view: MapView = _map_view(run_state.graph)
	view.sync_from_state(run_state)
	for head_id in run_state.graph.get_node(run_state.graph.start_id).connections:
		check("branch head %d is enabled" % head_id, not view.button_for(head_id).disabled)
	check("boss is disabled before it is reachable", view.button_for(run_state.graph.boss_id).disabled)
	check("start is disabled once left behind as current", view.button_for(run_state.graph.start_id).disabled)
	view.free()


func _test_rebuild_replaces_the_buttons_for_a_new_graph() -> void:
	var run_state: MapRunState = _run_state(1)
	var view: MapView = _map_view(run_state.graph)
	var new_graph: MapGraph = MapGraphScript.new(_rng(2))
	view.rebuild(new_graph)
	check_eq("rebuild matches the new graph's node count", view.button_count(), new_graph.node_count())
	view.free()


func _test_result_banner() -> void:
	var run_state: MapRunState = _run_state(1)
	var view: MapView = _map_view(run_state.graph)
	check("banner hidden by default", not view.result_visible())
	view.show_result("런 클리어")
	check("banner visible after show_result", view.result_visible())
	check_eq("banner shows the given text", view.result_text(), "런 클리어")
	view.hide_result()
	check("banner hidden after hide_result", not view.result_visible())
	view.free()
