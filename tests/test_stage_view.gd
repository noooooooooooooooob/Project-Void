# StageView(의뢰 화면) 테스트: 칸마다 버튼, 누르면 신호, 상태별 눌림·색, 파티 체력 줄, 제목, 결과 문구.
extends TestCase

# 의뢰 화면 스크립트.
const StageViewScript := preload("res://Scripts/view/stage_view.gd")
# 의뢰 진행 스크립트.
const CommissionRunScript := preload("res://Scripts/map/commission_run.gd")
# 파티 상태 스크립트.
const PartyStateScript := preload("res://Scripts/party/party_state.gd")
# 아군 데이터 스크립트.
const AllyDataScript := preload("res://Scripts/combat/data/ally_data.gd")
# 배치 스크립트.
const PlacementScript := preload("res://Scripts/combat/data/unit_placement.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 칸마다 버튼.
	_test_creates_a_button_per_cell()
	# 누르면 신호.
	_test_button_press_emits_node_selected()
	# 고를 수 있는 칸만 눌린다, 지금·지나온 칸 색.
	_test_sync_enables_selectable_and_colors_path()
	# 체력 줄.
	_test_hp_lines_show_current_and_fallen()
	# 제목.
	_test_title()
	# 결과 문구.
	_test_result_banner()
	# 결과를 돌려준다.
	return results()


# 시드 고정 의뢰 (파티 최대 체력 [30, 20]).
func _run() -> CommissionRun:
	# 생성기.
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	# 최대 체력.
	var max_hp: Array[int] = [30, 20]
	# 의뢰.
	return CommissionRunScript.new(rng, 0, max_hp)


# 이름이 "가", "나" 인 두 명 파티.
func _party() -> PartyState:
	# 배치 목록.
	var roster: Array[UnitPlacement] = []
	for member_name in ["가", "나"]:
		# 데이터.
		var data: AllyData = AllyDataScript.new()
		data.display_name = member_name
		# 배치.
		var placement: UnitPlacement = PlacementScript.new()
		placement.unit_data = data
		roster.append(placement)
	# 파티.
	return PartyStateScript.new(roster)


# 화면을 만들어 트리에 붙인다 (_ready 가 돌아야 버튼이 생긴다).
func _view(run: CommissionRun) -> StageView:
	# 화면.
	var view: StageView = StageViewScript.new(run)
	# 붙인다.
	(Engine.get_main_loop() as SceneTree).root.add_child(view)
	# 돌려준다.
	return view


# 버튼 수 = 칸 수.
func _test_creates_a_button_per_cell() -> void:
	# 의뢰와 화면.
	var run: CommissionRun = _run()
	var view: StageView = _view(run)
	check_eq("one button per cell", view.button_count(), run.graph.node_count())
	# 정리.
	view.free()


# 버튼을 누르면 그 칸 id 를 알린다.
func _test_button_press_emits_node_selected() -> void:
	# 의뢰와 화면.
	var run: CommissionRun = _run()
	var view: StageView = _view(run)
	view.sync_from_run(run, _party())
	# 받은 id (람다에서 바꾸려고 배열).
	var got: Array[int] = []
	view.node_selected.connect(func(id: int) -> void: got.append(id))
	# 첫 걸음 가운데 칸.
	var target: int = run.graph.node_at(1, 0).id
	view.button_for(target).pressed.emit()
	var expected: Array[int] = [target]
	check_eq("pressing emits the cell id", got, expected)
	# 정리.
	view.free()


# (1,0) 으로 간 뒤: (0..2,1) 눌림, (1,0) 은 지금 칸 색, 시작은 지나온 색, 보스는 잠김.
func _test_sync_enables_selectable_and_colors_path() -> void:
	# 의뢰와 화면.
	var run: CommissionRun = _run()
	var view: StageView = _view(run)
	# 가운데 첫 칸으로.
	var here: int = run.graph.node_at(1, 0).id
	run.enter(here)
	view.sync_from_run(run, _party())
	# 다음 걸음 세 칸은 눌린다.
	for lane in StageGraph.LANES:
		var button: Button = view.button_for(run.graph.node_at(lane, 1).id)
		check("next lane %d enabled" % lane, not button.disabled)
		check_eq("next lane %d selectable color" % lane, button.modulate, StageView.SELECTABLE_COLOR)
	# 지금 칸.
	check_eq("current cell color", view.button_for(here).modulate, StageView.CURRENT_COLOR)
	check("current cell disabled", view.button_for(here).disabled)
	# 시작은 지나온 칸.
	check_eq("start shows as visited", view.button_for(run.graph.start_id).modulate, StageView.VISITED_COLOR)
	# 보스는 잠김.
	check("boss disabled", view.button_for(run.graph.boss_id).disabled)
	check_eq("boss locked color", view.button_for(run.graph.boss_id).modulate, StageView.LOCKED_COLOR)
	# 정리.
	view.free()


# 체력 줄: "가  30 / 30", 쓰러진 "나" 는 "나  쓰러짐".
func _test_hp_lines_show_current_and_fallen() -> void:
	# 의뢰와 화면.
	var run: CommissionRun = _run()
	var view: StageView = _view(run)
	# 둘째가 쓰러졌다.
	run.member_hp = [30, 0]
	view.sync_from_run(run, _party())
	check_eq("living member hp line", view.hp_text(0), "가  30 / 30")
	check_eq("fallen member hp line", view.hp_text(1), "나  쓰러짐")
	# 정리.
	view.free()


# 제목은 "1층 탐사 중".
func _test_title() -> void:
	# 화면.
	var view: StageView = _view(_run())
	check_eq("title text", view.title_text(), "1층 탐사 중")
	# 정리.
	view.free()


# 결과 문구 보이기·숨기기.
func _test_result_banner() -> void:
	# 화면.
	var view: StageView = _view(_run())
	check("result hidden at first", not view.result_visible())
	view.show_result("아무 일도 없었다")
	check("result shown", view.result_visible())
	check_eq("result text", view.result_text(), "아무 일도 없었다")
	view.hide_result()
	check("result hidden again", not view.result_visible())
	# 정리.
	view.free()
