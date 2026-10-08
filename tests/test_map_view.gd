extends TestCase

const MapViewScript := preload("res://Scripts/view/map_view.gd")
const MapRunStateScript := preload("res://Scripts/map/map_run_state.gd")
const MapGraphScript := preload("res://Scripts/map/map_graph.gd")

func run() -> Array[Dictionary]:
	_test_creates_a_button_per_node()
	_test_button_press_emits_node_selected()
	_test_sync_enables_only_selectable_nodes()
	_test_rebuild_replaces_the_buttons_for_a_new_graph()
	_test_farm_buttons_unlock_with_their_story_node()
	_test_party_button_emits_party_requested()
	_test_party_button_is_on_screen()
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


func _first_story_id(run_state: MapRunState) -> int:
	return run_state.graph.get_node(run_state.graph.start_id).connections[0]


func _test_button_press_emits_node_selected() -> void:
	var run_state: MapRunState = _run_state(1)
	var view: MapView = _map_view(run_state.graph)
	var head: int = _first_story_id(run_state)
	var seen: Array[int] = []
	view.node_selected.connect(func(node_id: int) -> void: seen.append(node_id))
	view.button_for(head).pressed.emit()
	check_eq("pressing a button reports its node id", seen, [head])
	view.free()


func _test_sync_enables_only_selectable_nodes() -> void:
	var run_state: MapRunState = _run_state(1)
	var view: MapView = _map_view(run_state.graph)
	view.sync_from_state(run_state)
	check("first story node is enabled", not view.button_for(_first_story_id(run_state)).disabled)
	check("boss is disabled before it is reachable", view.button_for(run_state.graph.boss_id).disabled)
	check("start is disabled once left behind as current", view.button_for(run_state.graph.start_id).disabled)
	view.free()


func _test_farm_buttons_unlock_with_their_story_node() -> void:
	var run_state: MapRunState = _run_state(1)
	var view: MapView = _map_view(run_state.graph)
	var story_id: int = _first_story_id(run_state)
	var farm_ids: Array[int] = []
	for next_id in run_state.graph.get_node(story_id).connections:
		if run_state.graph.get_node(next_id).kind == MapNode.Kind.FARM:
			farm_ids.append(next_id)
	view.sync_from_state(run_state)
	for farm_id in farm_ids:
		check("farm button %d is disabled before its story node is cleared" % farm_id, view.button_for(farm_id).disabled)
	run_state.resolve_win(story_id)
	view.sync_from_state(run_state)
	for farm_id in farm_ids:
		check("farm button %d is enabled after its story node is cleared" % farm_id, not view.button_for(farm_id).disabled)
	view.free()


func _test_party_button_emits_party_requested() -> void:
	var run_state: MapRunState = _run_state(1)
	var view: MapView = _map_view(run_state.graph)
	var seen: Array[bool] = []
	view.party_requested.connect(func() -> void: seen.append(true))
	view.party_button().pressed.emit()
	check_eq("party button reports a request", seen.size(), 1)
	view.free()


func _test_rebuild_replaces_the_buttons_for_a_new_graph() -> void:
	var run_state: MapRunState = _run_state(1)
	var view: MapView = _map_view(run_state.graph)
	var new_graph: MapGraph = MapGraphScript.new(_rng(2))
	view.rebuild(new_graph)
	check_eq("rebuild matches the new graph's node count", view.button_count(), new_graph.node_count())
	view.free()


## 버튼이 신호만 내고 화면 밖에 그려지던 버그의 회귀 테스트: 뷰가 화면 크기를 갖고, 버튼이 화면 안에 있어야 한다.
func _test_party_button_is_on_screen() -> void:
	var run_state: MapRunState = _run_state(1)
	var view: MapView = _map_view(run_state.graph)
	var viewport_rect := Rect2(Vector2.ZERO, view.get_viewport_rect().size)
	check("the map view fills the screen", view.size.x > 0.0 and view.size.y > 0.0)
	check("the party button sits inside the screen", viewport_rect.encloses(view.party_button().get_global_rect()))
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
