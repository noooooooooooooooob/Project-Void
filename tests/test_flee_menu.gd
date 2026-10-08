extends TestCase

const FleeMenuScript := preload("res://Scripts/ui/flee_menu.gd")


func run() -> Array[Dictionary]:
	_test_starts_closed_and_toggles()
	_test_buttons_emit_their_signals()
	_test_has_resume_and_flee_labels()
	return results()


func _menu() -> FleeMenu:
	var menu: FleeMenu = FleeMenuScript.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(menu)
	return menu


func _test_starts_closed_and_toggles() -> void:
	var menu: FleeMenu = _menu()
	check("the menu starts closed", not menu.is_open())
	menu.open()
	check("open shows the menu", menu.is_open())
	menu.close()
	check("close hides the menu", not menu.is_open())
	menu.free()


func _test_buttons_emit_their_signals() -> void:
	var menu: FleeMenu = _menu()
	var resumed: Array[bool] = []
	var fled: Array[bool] = []
	menu.resume_requested.connect(func() -> void: resumed.append(true))
	menu.flee_requested.connect(func() -> void: fled.append(true))
	menu.resume_button().pressed.emit()
	check_eq("resume button reports resume", [resumed.size(), fled.size()], [1, 0])
	menu.flee_button().pressed.emit()
	check_eq("flee button reports flee", [resumed.size(), fled.size()], [1, 1])
	menu.free()


func _test_has_resume_and_flee_labels() -> void:
	var menu: FleeMenu = _menu()
	check_eq("resume button label", menu.resume_button().text, "계속하기")
	check_eq("flee button label", menu.flee_button().text, "도망가기")
	menu.free()
