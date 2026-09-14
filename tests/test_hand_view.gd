extends TestCase

const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")


func run() -> Array[Dictionary]:
	_test_set_cards_lays_out()
	_test_set_cards_same_hand_keeps_views()
	_test_selected_card_lifts()
	_test_draw_card_appends()
	_test_remove_card_prefers_pending_play()
	_test_discard_all_empties()
	_test_click_toggles_selection()
	_test_drag_emits_drop()
	_test_locked_hand_ignores_input()
	_test_unaffordable_card_ignores_input()
	return results()


func _card(display_name: String, cost: int) -> CardData:
	var card: CardData = CardDataScript.new()
	card.display_name = display_name
	card.sp_cost = cost
	card.damage = 1
	card.attack_range = 1
	return card


func _cards(list: Array) -> Array[CardData]:
	var typed: Array[CardData] = []
	typed.append_array(list)
	return typed


func _hand() -> HandView:
	var hand := HandView.new()
	hand.instant = true
	(Engine.get_main_loop() as SceneTree).root.add_child(hand)
	hand.size = Vector2(1152, 648)
	return hand


func _press(view: CardView, at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = at
	event.global_position = at
	view.gui_input.emit(event)


func _move(view: CardView, at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	view.gui_input.emit(event)


func _test_set_cards_lays_out() -> void:
	var hand: HandView = _hand()
	hand.set_cards(_cards([_card("a", 1), _card("b", 1), _card("big", 9)]), 3, -1)
	var views: Array[CardView] = hand.card_views()
	check_eq("three card views", views.size(), 3)
	var middle: Dictionary = HandLayout.slot(1, 3, hand.anchor())
	check("middle card centred on its slot", (views[1].position + CardView.SIZE / 2.0).is_equal_approx(middle["position"]))
	check_eq("unaffordable card dimmed", views[2].modulate, CardView.UNAFFORDABLE_MODULATE)
	hand.free()


func _test_set_cards_same_hand_keeps_views() -> void:
	var hand: HandView = _hand()
	var cards: Array[CardData] = _cards([_card("a", 1), _card("b", 1)])
	hand.set_cards(cards, 3, -1)
	var first: CardView = hand.card_views()[0]
	hand.set_cards(cards, 2, 1)
	check("same hand keeps the existing views", hand.card_views()[0] == first)
	check_eq("selection still applied", hand.selected_index(), 1)
	hand.free()


func _test_selected_card_lifts() -> void:
	var hand: HandView = _hand()
	hand.set_cards(_cards([_card("a", 1), _card("b", 1), _card("c", 1)]), 3, 0)
	var view: CardView = hand.card_views()[0]
	var slot: Dictionary = HandLayout.slot(0, 3, hand.anchor())
	check("lifted above its slot", is_equal_approx(view.position.y, slot["position"].y - CardView.SIZE.y / 2.0 - HandView.LIFT))
	check_eq("upright while selected", view.rotation, 0.0)
	check("enlarged while selected", view.scale.is_equal_approx(Vector2.ONE * HandView.SELECTED_SCALE))
	hand.free()


func _test_draw_card_appends() -> void:
	var hand: HandView = _hand()
	var first: CardData = _card("a", 1)
	var drawn: CardData = _card("b", 1)
	hand.set_cards(_cards([first]), 3, -1)
	hand.draw_card(drawn, Vector2.ZERO)
	var views: Array[CardView] = hand.card_views()
	check_eq("hand grew", views.size(), 2)
	check("drawn card is last", views[1].card == drawn)
	check("drawn card face up when instant", views[1].is_face_up())
	hand.free()


func _test_remove_card_prefers_pending_play() -> void:
	var hand: HandView = _hand()
	var strike: CardData = _card("strike", 1)
	hand.set_cards(_cards([strike, strike, _card("shot", 1)]), 3, -1)
	var left: CardView = hand.card_views()[0]
	var right: CardView = hand.card_views()[1]
	hand.set_pending_play(1)
	hand.remove_card(strike)
	var views: Array[CardView] = hand.card_views()
	check_eq("one card removed", views.size(), 2)
	check("the remembered copy was removed", not views.has(right))
	check("the other copy stays", views[0] == left)
	hand.free()


func _test_discard_all_empties() -> void:
	var hand: HandView = _hand()
	hand.set_cards(_cards([_card("a", 1), _card("b", 1)]), 3, 1)
	hand.discard_all(Vector2.ZERO)
	check_eq("no cards left", hand.card_views().size(), 0)
	check_eq("selection cleared", hand.selected_index(), -1)
	hand.free()


func _test_click_toggles_selection() -> void:
	var hand: HandView = _hand()
	hand.interactive = true
	hand.set_cards(_cards([_card("a", 1), _card("b", 1)]), 3, -1)
	var picked: Array = []
	hand.card_selected.connect(func(index: int) -> void: picked.append(index))
	var view: CardView = hand.card_views()[1]
	_press(view, Vector2(100, 100), true)
	_press(view, Vector2(102, 101), false)
	_press(view, Vector2(100, 100), true)
	_press(view, Vector2(100, 100), false)
	check_eq("select then deselect", picked, [1, -1])
	check_eq("nothing selected at the end", hand.selected_index(), -1)
	hand.free()


func _test_drag_emits_drop() -> void:
	var hand: HandView = _hand()
	hand.interactive = true
	hand.set_cards(_cards([_card("a", 1), _card("b", 1)]), 3, -1)
	var picked: Array = []
	var dropped: Array = []
	hand.card_selected.connect(func(index: int) -> void: picked.append(index))
	hand.card_dropped.connect(func(index: int, at: Vector2) -> void: dropped.append([index, at]))
	var view: CardView = hand.card_views()[0]
	_press(view, Vector2(500, 560), true)
	_move(view, Vector2(500, 500))
	check_eq("dragging selects the card", picked, [0])
	check("aim arrow shown while dragging", hand.is_aiming())
	_press(view, Vector2(700, 200), false)
	check_eq("drop reports card and position", dropped, [[0, Vector2(700, 200)]])
	check("aim arrow hidden after drop", not hand.is_aiming())
	check_eq("card returns unselected", hand.selected_index(), -1)
	hand.free()


func _test_locked_hand_ignores_input() -> void:
	var hand: HandView = _hand()
	hand.set_cards(_cards([_card("a", 1)]), 3, -1)
	var picked: Array = []
	hand.card_selected.connect(func(index: int) -> void: picked.append(index))
	var view: CardView = hand.card_views()[0]
	_press(view, Vector2(100, 100), true)
	_press(view, Vector2(100, 100), false)
	check_eq("no selection while not interactive", picked, [])

	hand.interactive = true
	_press(view, Vector2(100, 100), true)
	_press(view, Vector2(100, 100), false)
	hand.interactive = false
	check_eq("locking clears the selection", hand.selected_index(), -1)
	hand.free()


func _test_unaffordable_card_ignores_input() -> void:
	var hand: HandView = _hand()
	hand.interactive = true
	hand.set_cards(_cards([_card("big", 9)]), 3, -1)
	var picked: Array = []
	var dropped: Array = []
	hand.card_selected.connect(func(index: int) -> void: picked.append(index))
	hand.card_dropped.connect(func(index: int, at: Vector2) -> void: dropped.append(index))
	var view: CardView = hand.card_views()[0]
	_press(view, Vector2(100, 100), true)
	_press(view, Vector2(100, 100), false)
	_press(view, Vector2(100, 100), true)
	_move(view, Vector2(100, 40))
	_press(view, Vector2(100, 40), false)
	check_eq("unaffordable card cannot be selected", picked, [])
	check_eq("unaffordable card cannot be dropped", dropped, [])
	check("no aim arrow for an unaffordable card", not hand.is_aiming())
	hand.free()
