# MapView(지도 화면) 테스트: 노드 버튼 생성, 버튼 신호, 진행 상태에 따른 눌림 가능 여부, 새 지도로 다시 만들기, 파티 버튼, 결과 문구.
extends TestCase

# 지도 화면 스크립트.
const MapViewScript := preload("res://Scripts/view/map_view.gd")
# 지도 진행 상태 스크립트.
const MapRunStateScript := preload("res://Scripts/map/map_run_state.gd")
# 지도 그래프 스크립트.
const MapGraphScript := preload("res://Scripts/map/map_graph.gd")

# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 노드마다 버튼 하나.
	_test_creates_a_button_per_node()
	# 버튼을 누르면 노드 id 를 알린다.
	_test_button_press_emits_node_selected()
	# 들어갈 수 있는 노드만 눌린다.
	_test_sync_enables_only_selectable_nodes()
	# 새 지도로 버튼을 다시 만든다.
	_test_rebuild_replaces_the_buttons_for_a_new_graph()
	# 파밍 버튼은 부모 이야기 노드를 깨면 열린다.
	_test_farm_buttons_unlock_with_their_story_node()
	# 파티 버튼이 요청 신호를 낸다.
	_test_party_button_emits_party_requested()
	# 파티 버튼이 화면 안에 있다.
	_test_party_button_is_on_screen()
	# 결과 문구 보이기·숨기기.
	_test_result_banner()
	# 결과를 돌려준다.
	return results()


# 시드를 고정한 난수 생성기.
func _rng(seed_value: int) -> RandomNumberGenerator:
	# 생성기를 만든다.
	var rng := RandomNumberGenerator.new()
	# 시드를 고정한다.
	rng.seed = seed_value
	# 돌려준다.
	return rng


# 시드를 고정한 진행 상태.
func _run_state(seed_value: int) -> MapRunState:
	# 진행 상태를 만들어 돌려준다.
	return MapRunStateScript.new(_rng(seed_value))


# 지도 화면을 만들어 씬 트리에 붙인다 (_ready 가 돌아야 버튼이 생긴다).
func _map_view(graph: MapGraph) -> MapView:
	# 화면을 만든다.
	var view: MapView = MapViewScript.new(graph)
	# 실행기의 루트에 붙인다.
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	# 돌려준다.
	return view


# 버튼 수가 노드 수와 같다.
func _test_creates_a_button_per_node() -> void:
	# 진행 상태.
	var run_state: MapRunState = _run_state(1)
	# 화면.
	var view: MapView = _map_view(run_state.graph)
	# 수가 같다.
	check_eq("one button per node", view.button_count(), run_state.graph.node_count())
	# 정리한다.
	view.free()


# 시작 노드 다음의 첫 이야기 노드 id.
func _first_story_id(run_state: MapRunState) -> int:
	# 시작 노드의 첫 연결.
	return run_state.graph.get_node(run_state.graph.start_id).connections[0]


# 버튼을 누르면 그 노드 id 로 node_selected 가 나온다.
func _test_button_press_emits_node_selected() -> void:
	# 진행 상태.
	var run_state: MapRunState = _run_state(1)
	# 화면.
	var view: MapView = _map_view(run_state.graph)
	# 첫 이야기 노드.
	var head: int = _first_story_id(run_state)
	# 받은 id 기록.
	var seen: Array[int] = []
	# 신호를 받으면 기록한다.
	view.node_selected.connect(func(node_id: int) -> void: seen.append(node_id))
	# 버튼을 누른 것처럼 한다.
	view.button_for(head).pressed.emit()
	# 그 id 하나만.
	check_eq("pressing a button reports its node id", seen, [head])
	# 정리한다.
	view.free()


# 동기화하면 들어갈 수 있는 노드만 눌리고 나머지는 막힌다.
func _test_sync_enables_only_selectable_nodes() -> void:
	# 진행 상태.
	var run_state: MapRunState = _run_state(1)
	# 화면.
	var view: MapView = _map_view(run_state.graph)
	# 진행 상태에 맞춘다.
	view.sync_from_state(run_state)
	# 첫 이야기 노드는 눌린다.
	check("first story node is enabled", not view.button_for(_first_story_id(run_state)).disabled)
	# 보스는 막혀 있다.
	check("boss is disabled before it is reachable", view.button_for(run_state.graph.boss_id).disabled)
	# 시작 노드도 막혀 있다.
	check("start is disabled once left behind as current", view.button_for(run_state.graph.start_id).disabled)
	# 정리한다.
	view.free()


# 파밍 버튼은 부모 이야기 노드를 깨기 전엔 막혀 있고, 깨고 동기화하면 눌린다.
func _test_farm_buttons_unlock_with_their_story_node() -> void:
	# 진행 상태.
	var run_state: MapRunState = _run_state(1)
	# 화면.
	var view: MapView = _map_view(run_state.graph)
	# 첫 이야기 노드.
	var story_id: int = _first_story_id(run_state)
	# 그 노드의 파밍 노드 id 들.
	var farm_ids: Array[int] = []
	# 연결마다.
	for next_id in run_state.graph.get_node(story_id).connections:
		# 파밍이면 모은다.
		if run_state.graph.get_node(next_id).kind == MapNode.Kind.FARM:
			farm_ids.append(next_id)
	# 처음 상태로 맞춘다.
	view.sync_from_state(run_state)
	# 파밍마다 막혀 있다.
	for farm_id in farm_ids:
		check("farm button %d is disabled before its story node is cleared" % farm_id, view.button_for(farm_id).disabled)
	# 이야기 노드를 깬다.
	run_state.resolve_win(story_id)
	# 다시 맞춘다.
	view.sync_from_state(run_state)
	# 파밍마다 눌린다.
	for farm_id in farm_ids:
		check("farm button %d is enabled after its story node is cleared" % farm_id, not view.button_for(farm_id).disabled)
	# 정리한다.
	view.free()


# 파티 버튼을 누르면 party_requested 가 한 번 나온다.
func _test_party_button_emits_party_requested() -> void:
	# 진행 상태.
	var run_state: MapRunState = _run_state(1)
	# 화면.
	var view: MapView = _map_view(run_state.graph)
	# 받은 횟수 기록.
	var seen: Array[bool] = []
	# 신호를 받으면 기록한다.
	view.party_requested.connect(func() -> void: seen.append(true))
	# 버튼을 누른 것처럼 한다.
	view.party_button().pressed.emit()
	# 한 번.
	check_eq("party button reports a request", seen.size(), 1)
	# 정리한다.
	view.free()


# 새 지도로 다시 만들면 버튼 수가 새 지도의 노드 수와 같다.
func _test_rebuild_replaces_the_buttons_for_a_new_graph() -> void:
	# 진행 상태.
	var run_state: MapRunState = _run_state(1)
	# 화면.
	var view: MapView = _map_view(run_state.graph)
	# 다른 시드의 새 지도.
	var new_graph: MapGraph = MapGraphScript.new(_rng(2))
	# 다시 만든다.
	view.rebuild(new_graph)
	# 수가 같다.
	check_eq("rebuild matches the new graph's node count", view.button_count(), new_graph.node_count())
	# 정리한다.
	view.free()


## 버튼이 신호만 내고 화면 밖에 그려지던 버그의 회귀 테스트: 뷰가 화면 크기를 갖고, 버튼이 화면 안에 있어야 한다.
func _test_party_button_is_on_screen() -> void:
	# 진행 상태.
	var run_state: MapRunState = _run_state(1)
	# 화면.
	var view: MapView = _map_view(run_state.graph)
	# 화면 영역.
	var viewport_rect := Rect2(Vector2.ZERO, view.get_viewport_rect().size)
	# 뷰 크기가 0 이 아니다.
	check("the map view fills the screen", view.size.x > 0.0 and view.size.y > 0.0)
	# 버튼이 화면 영역 안에 들어간다.
	check("the party button sits inside the screen", viewport_rect.encloses(view.party_button().get_global_rect()))
	# 정리한다.
	view.free()


# 결과 문구는 처음엔 숨겨져 있고, show_result/hide_result 로 보이고 숨는다.
func _test_result_banner() -> void:
	# 진행 상태.
	var run_state: MapRunState = _run_state(1)
	# 화면.
	var view: MapView = _map_view(run_state.graph)
	# 처음엔 숨김.
	check("banner hidden by default", not view.result_visible())
	# 문구를 띄운다.
	view.show_result("런 클리어")
	# 보인다.
	check("banner visible after show_result", view.result_visible())
	# 문구가 같다.
	check_eq("banner shows the given text", view.result_text(), "런 클리어")
	# 숨긴다.
	view.hide_result()
	# 숨었다.
	check("banner hidden after hide_result", not view.result_visible())
	# 정리한다.
	view.free()
