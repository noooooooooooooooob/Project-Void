# FleeMenu(전투 중 Esc 메뉴) 테스트: 열고 닫기, 버튼 신호, 버튼 글자.
extends TestCase

# 도망 메뉴 스크립트.
const FleeMenuScript := preload("res://Scripts/ui/flee_menu.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 처음엔 닫혀 있고 열고 닫을 수 있다.
	_test_starts_closed_and_toggles()
	# 버튼이 각자의 신호를 낸다.
	_test_buttons_emit_their_signals()
	# 버튼 글자.
	_test_has_resume_and_flee_labels()
	# 결과를 돌려준다.
	return results()


# 메뉴를 만들어 씬 트리에 붙인다.
func _menu() -> FleeMenu:
	# 메뉴를 만든다.
	var menu: FleeMenu = FleeMenuScript.new()
	# 실행기의 루트에 붙인다.
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	# 돌려준다.
	return menu


# 처음엔 닫혀 있고, open/close 가 상태를 바꾼다.
func _test_starts_closed_and_toggles() -> void:
	# 메뉴를 만든다.
	var menu: FleeMenu = _menu()
	# 처음엔 닫혀 있다.
	check("the menu starts closed", not menu.is_open())
	# 연다.
	menu.open()
	# 열렸다.
	check("open shows the menu", menu.is_open())
	# 닫는다.
	menu.close()
	# 닫혔다.
	check("close hides the menu", not menu.is_open())
	# 정리한다.
	menu.free()


# 계속하기는 resume_requested 만, 도망가기는 flee_requested 만 낸다.
func _test_buttons_emit_their_signals() -> void:
	# 메뉴를 만든다.
	var menu: FleeMenu = _menu()
	# 계속하기 신호를 받은 횟수 기록.
	var resumed: Array[bool] = []
	# 도망가기 신호를 받은 횟수 기록.
	var fled: Array[bool] = []
	# 계속하기 신호를 받으면 기록한다.
	menu.resume_requested.connect(func() -> void: resumed.append(true))
	# 도망가기 신호를 받으면 기록한다.
	menu.flee_requested.connect(func() -> void: fled.append(true))
	# 계속하기 버튼을 누른 것처럼 한다.
	menu.resume_button().pressed.emit()
	# 계속하기만 1 번.
	check_eq("resume button reports resume", [resumed.size(), fled.size()], [1, 0])
	# 도망가기 버튼을 누른 것처럼 한다.
	menu.flee_button().pressed.emit()
	# 도망가기도 1 번.
	check_eq("flee button reports flee", [resumed.size(), fled.size()], [1, 1])
	# 정리한다.
	menu.free()


# 버튼 글자가 정해진 문구다.
func _test_has_resume_and_flee_labels() -> void:
	# 메뉴를 만든다.
	var menu: FleeMenu = _menu()
	# 계속하기 버튼 글자.
	check_eq("resume button label", menu.resume_button().text, "계속하기")
	# 도망가기 버튼 글자.
	check_eq("flee button label", menu.flee_button().text, "도망가기")
	# 정리한다.
	menu.free()
