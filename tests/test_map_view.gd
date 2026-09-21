# MapView(맵 화면 — 점마다 버튼 하나, 길은 직접 그린다) 테스트.
extends TestCase

# 맵 화면 스크립트.
const MapViewScript := preload("res://Scripts/view/map_view.gd")
# 버튼 상태를 맞출 때 넘길 진행 상황 스크립트.
const MapRunStateScript := preload("res://Scripts/map/map_run_state.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 점 수만큼 버튼이 생긴다.
	_test_creates_a_button_per_node()
	# 버튼을 누르면 점 번호를 알린다.
	_test_button_press_emits_node_selected()
	# 갈 수 있는 점만 누를 수 있다.
	_test_sync_enables_only_selectable_nodes()
	# 결과 문구 띄우기/숨기기.
	_test_result_banner()
	# 결과를 돌려준다.
	return results()


# 시드를 고정한 난수기를 만든다 (테스트가 매번 같은 런을 보도록).
func _rng(seed_value: int) -> RandomNumberGenerator:
	# 난수기를 만든다.
	var rng := RandomNumberGenerator.new()
	# 시드를 박는다.
	rng.seed = seed_value
	# 만든 난수기를 돌려준다.
	return rng


# 맵 화면을 만들어 트리에 붙인다. 붙여야 _ready 가 돌아 버튼이 생긴다.
func _map_view() -> MapView:
	# 화면을 만든다.
	var view: MapView = MapViewScript.new()
	# 테스트는 씬이 없으므로 트리의 뿌리에 바로 붙인다.
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	# 붙인 화면을 돌려준다 (쓴 쪽이 free 로 치운다).
	return view


# 맵의 점 수(10)만큼 버튼이 만들어지는지.
func _test_creates_a_button_per_node() -> void:
	# 화면을 만든다.
	var view: MapView = _map_view()
	# 점마다 버튼 하나.
	check_eq("one button per node", view.button_count(), 10)
	# 트리에서 치운다.
	view.free()


# 버튼을 누르면 그 점 번호를 실어 알리는지.
func _test_button_press_emits_node_selected() -> void:
	# 화면을 만든다.
	var view: MapView = _map_view()
	# 알림으로 들어온 번호를 모을 곳.
	var seen: Array[int] = []
	# 알림을 받아 적는다.
	view.node_selected.connect(func(node_id: int) -> void: seen.append(node_id))
	# 실제 클릭 대신 눌림 신호를 직접 낸다.
	view.button_for(5).pressed.emit()
	# 누른 버튼의 번호가 그대로 들어왔다.
	check_eq("pressing a button reports its node id", seen, [5])
	# 트리에서 치운다.
	view.free()


# 진행 상황을 맞추면 갈 수 있는 점의 버튼만 눌리는 상태가 되는지.
func _test_sync_enables_only_selectable_nodes() -> void:
	# 화면을 만든다.
	var view: MapView = _map_view()
	# 시작점에 선 런.
	var run_state: MapRunState = MapRunStateScript.new(_rng(1))
	# 버튼 상태를 맞춘다.
	view.sync_from_state(run_state)
	# 갈래 0 의 첫 칸은 갈 수 있다.
	check("branch 0 head is enabled", not view.button_for(1).disabled)
	# 갈래 1 의 첫 칸도 갈 수 있다.
	check("branch 1 head is enabled", not view.button_for(5).disabled)
	# 아직 이어지지 않은 칸은 막혀 있다.
	check("unreached step is disabled", view.button_for(2).disabled)
	# 지금 서 있는 점(시작점)도 다시 고를 수는 없다.
	check("start is disabled once left behind as current", view.button_for(0).disabled)
	# 트리에서 치운다.
	view.free()


# 런 결과 문구가 부를 때만 보이고 내용이 그대로 나오는지.
func _test_result_banner() -> void:
	# 화면을 만든다.
	var view: MapView = _map_view()
	# 처음에는 숨어 있다.
	check("banner hidden by default", not view.result_visible())
	# 문구를 띄운다.
	view.show_result("런 클리어")
	# 보인다.
	check("banner visible after show_result", view.result_visible())
	# 넘긴 문구가 그대로 나온다.
	check_eq("banner shows the given text", view.result_text(), "런 클리어")
	# 다시 숨긴다.
	view.hide_result()
	# 숨었다.
	check("banner hidden after hide_result", not view.result_visible())
	# 트리에서 치운다.
	view.free()
