# HandView(부채꼴 손패) 테스트: 배치, 같은 손패 유지, 선택 들기, 자식 순서, 드로우·제거·버리기, 클릭·끌기 입력, 잠금, SP 부족 입력 차단.
# instant 모드로 연출 없이 최종 상태만 확인하고, 마우스 입력은 gui_input 신호를 직접 내서 흉내 낸다.
extends TestCase

# 테스트용 카드를 만들 스크립트.
const CardDataScript := preload("res://Scripts/combat/data/card_data.gd")


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 카드 배치와 흐림.
	_test_set_cards_lays_out()
	# 같은 손패면 카드 화면 유지.
	_test_set_cards_same_hand_keeps_views()
	# 선택 카드가 들린다.
	_test_selected_card_lifts()
	# 자식 순서가 선택을 따른다.
	_test_child_order_follows_selection()
	# 드로우가 끝에 붙는다.
	_test_draw_card_appends()
	# 제거는 기억한 위치를 우선한다.
	_test_remove_card_prefers_pending_play()
	# 버리기로 손패가 빈다.
	_test_discard_all_empties()
	# 클릭으로 선택 토글.
	_test_click_toggles_selection()
	# 끌어서 놓기.
	_test_drag_emits_drop()
	# 잠긴 손패는 입력 무시.
	_test_locked_hand_ignores_input()
	# SP 부족 카드는 입력 무시.
	_test_unaffordable_card_ignores_input()
	# 결과를 돌려준다.
	return results()


# 이름·비용만 정한 테스트 카드.
func _card(display_name: String, cost: int) -> CardData:
	# 빈 카드.
	var card: CardData = CardDataScript.new()
	# 이름.
	card.display_name = display_name
	# 비용.
	card.sp_cost = cost
	# 피해.
	card.damage = 1
	# 사거리.
	card.attack_range = 1
	# 돌려준다.
	return card


# 타입 없는 배열을 Array[CardData] 로 바꾼다 (set_cards 가 타입 있는 배열을 요구한다).
func _cards(list: Array) -> Array[CardData]:
	# 타입 있는 빈 배열.
	var typed: Array[CardData] = []
	# 원소를 옮겨 담는다.
	typed.append_array(list)
	# 돌려준다.
	return typed


# 연출 없는 손패를 1152×648 크기로 루트 창에 붙여 만든다.
func _hand() -> HandView:
	# 손패.
	var hand := HandView.new()
	# 연출 없이.
	hand.instant = true
	# 트리에 붙인다 (전역 좌표와 move_child 가 의미 있게).
	(Engine.get_main_loop() as SceneTree).root.add_child(hand)
	# 게임 창과 같은 크기.
	hand.size = Vector2(1152, 648)
	# 돌려준다.
	return hand


# 카드에 왼쪽 버튼 누르기(pressed = true) 또는 떼기(false) 이벤트를 보낸다.
func _press(view: CardView, at: Vector2, pressed: bool) -> void:
	# 마우스 버튼 이벤트.
	var event := InputEventMouseButton.new()
	# 왼쪽 버튼.
	event.button_index = MOUSE_BUTTON_LEFT
	# 누르기/떼기.
	event.pressed = pressed
	# 위치.
	event.position = at
	# 전역 위치 (HandView 는 이 값을 쓴다).
	event.global_position = at
	# 카드의 gui_input 신호로 직접 보낸다.
	view.gui_input.emit(event)


# 카드에 마우스 이동 이벤트를 보낸다.
func _move(view: CardView, at: Vector2) -> void:
	# 마우스 이동 이벤트.
	var event := InputEventMouseMotion.new()
	# 위치.
	event.position = at
	# 전역 위치.
	event.global_position = at
	# 카드의 gui_input 신호로 직접 보낸다.
	view.gui_input.emit(event)


# 3 장을 넣으면 화면 3 개가 생기고, 가운데 카드가 자기 자리 중심에 있고, SP 3 으로 못 쓰는 비용 9 카드는 흐린지.
func _test_set_cards_lays_out() -> void:
	# 손패.
	var hand: HandView = _hand()
	# a(1), b(1), big(9) 를 SP 3 으로.
	hand.set_cards(_cards([_card("a", 1), _card("b", 1), _card("big", 9)]), 3, -1)
	# 카드 화면들.
	var views: Array[CardView] = hand.card_views()
	# 3 개.
	check_eq("three card views", views.size(), 3)
	# 가운데(1 번) 자리.
	var middle: Dictionary = HandLayout.slot(1, 3, hand.anchor())
	# 카드 중심 = 자리 위치.
	check("middle card centred on its slot", (views[1].position + CardView.SIZE / 2.0).is_equal_approx(middle["position"]))
	# big 은 흐림.
	check_eq("unaffordable card dimmed", views[2].modulate, CardView.UNAFFORDABLE_MODULATE)
	# 지운다.
	hand.free()


# 같은 카드 배열로 다시 set_cards 하면 기존 카드 화면을 그대로 두고 선택만 바뀌는지.
func _test_set_cards_same_hand_keeps_views() -> void:
	# 손패.
	var hand: HandView = _hand()
	# 카드 배열 (두 번 같은 배열을 쓴다).
	var cards: Array[CardData] = _cards([_card("a", 1), _card("b", 1)])
	# 처음 설정.
	hand.set_cards(cards, 3, -1)
	# 첫 카드 화면을 기억한다.
	var first: CardView = hand.card_views()[0]
	# 같은 카드로 SP·선택만 바꿔 다시 설정.
	hand.set_cards(cards, 2, 1)
	# 같은 화면 객체.
	check("same hand keeps the existing views", hand.card_views()[0] == first)
	# 선택 1.
	check_eq("selection still applied", hand.selected_index(), 1)
	# 지운다.
	hand.free()


# 선택된 카드는 자리보다 LIFT 만큼 위에, 똑바로, SELECTED_SCALE 배로 커져 있는지.
func _test_selected_card_lifts() -> void:
	# 손패.
	var hand: HandView = _hand()
	# 3 장, 0 번 선택.
	hand.set_cards(_cards([_card("a", 1), _card("b", 1), _card("c", 1)]), 3, 0)
	# 0 번 카드 화면.
	var view: CardView = hand.card_views()[0]
	# 0 번 자리.
	var slot: Dictionary = HandLayout.slot(0, 3, hand.anchor())
	# 위치 y = 자리 중심 - 카드 절반 높이 - LIFT.
	check("lifted above its slot", is_equal_approx(view.position.y, slot["position"].y - CardView.SIZE.y / 2.0 - HandView.LIFT))
	# 기울기 0.
	check_eq("upright while selected", view.rotation, 0.0)
	# 확대.
	check("enlarged while selected", view.scale.is_equal_approx(Vector2.ONE * HandView.SELECTED_SCALE))
	# 지운다.
	hand.free()


# 선택 중에는 들린 카드가 오른쪽 이웃보다 트리 뒤(클릭 우선)에 있고 화살표가 맨 뒤이며,
# 선택을 풀면 카드들이 다시 번호 순서로 돌아가는지.
func _test_child_order_follows_selection() -> void:
	# 손패.
	var hand: HandView = _hand()
	# 카드 배열.
	var cards: Array[CardData] = _cards([_card("a", 1), _card("b", 1), _card("c", 1)])
	# 1 번 선택.
	hand.set_cards(cards, 3, 1)
	# 카드 화면들.
	var views: Array[CardView] = hand.card_views()
	# 1 번이 2 번보다 뒤.
	check("lifted card is picked before its right neighbour", views[1].get_index() > views[2].get_index())
	# 마지막 자식은 조준 화살표.
	check("aim arrow stays the last child", hand.get_child(hand.get_child_count() - 1) is AimArrow)
	# 선택 해제.
	hand.set_cards(cards, 3, -1)
	# 1 번이 2 번보다 앞으로 돌아왔다.
	check("deselected card goes back under its right neighbour", views[1].get_index() < views[2].get_index())
	# 0 번은 여전히 1 번보다 앞.
	check("left card stays under the deselected card", views[0].get_index() < views[1].get_index())
	# 지운다.
	hand.free()


# 드로우한 카드가 손패 끝에 붙고, instant 모드에서는 바로 앞면인지.
func _test_draw_card_appends() -> void:
	# 손패.
	var hand: HandView = _hand()
	# 처음 카드.
	var first: CardData = _card("a", 1)
	# 뽑을 카드.
	var drawn: CardData = _card("b", 1)
	# 한 장으로 시작.
	hand.set_cards(_cards([first]), 3, -1)
	# 드로우.
	hand.draw_card(drawn, Vector2.ZERO)
	# 카드 화면들.
	var views: Array[CardView] = hand.card_views()
	# 2 장.
	check_eq("hand grew", views.size(), 2)
	# 뽑은 카드가 끝.
	check("drawn card is last", views[1].card == drawn)
	# 앞면.
	check("drawn card face up when instant", views[1].is_face_up())
	# 지운다.
	hand.free()


# 같은 카드가 두 장일 때 set_pending_play 로 기억한 오른쪽 장이 제거되는지.
func _test_remove_card_prefers_pending_play() -> void:
	# 손패.
	var hand: HandView = _hand()
	# 같은 카드 데이터를 두 번 넣는다.
	var strike: CardData = _card("strike", 1)
	# strike, strike, shot.
	hand.set_cards(_cards([strike, strike, _card("shot", 1)]), 3, -1)
	# 왼쪽 strike 화면.
	var left: CardView = hand.card_views()[0]
	# 오른쪽 strike 화면.
	var right: CardView = hand.card_views()[1]
	# 1 번이 곧 사용된다고 기억시킨다.
	hand.set_pending_play(1)
	# strike 제거.
	hand.remove_card(strike)
	# 남은 카드 화면들.
	var views: Array[CardView] = hand.card_views()
	# 한 장 줄었다.
	check_eq("one card removed", views.size(), 2)
	# 오른쪽이 빠졌다.
	check("the remembered copy was removed", not views.has(right))
	# 왼쪽은 남았다.
	check("the other copy stays", views[0] == left)
	# 지운다.
	hand.free()


# discard_all 후 손패가 비고 선택도 풀리는지.
func _test_discard_all_empties() -> void:
	# 손패.
	var hand: HandView = _hand()
	# 2 장, 1 번 선택.
	hand.set_cards(_cards([_card("a", 1), _card("b", 1)]), 3, 1)
	# 모두 버린다.
	hand.discard_all(Vector2.ZERO)
	# 0 장.
	check_eq("no cards left", hand.card_views().size(), 0)
	# 선택 없음.
	check_eq("selection cleared", hand.selected_index(), -1)
	# 지운다.
	hand.free()


# 누르고 조금(12px 미만) 움직여 떼면 선택, 한 번 더 클릭하면 해제되는지.
func _test_click_toggles_selection() -> void:
	# 손패.
	var hand: HandView = _hand()
	# 입력 허용.
	hand.interactive = true
	# 2 장.
	hand.set_cards(_cards([_card("a", 1), _card("b", 1)]), 3, -1)
	# 선택 신호 기록.
	var picked: Array = []
	# 선택 신호를 기록한다.
	hand.card_selected.connect(func(index: int) -> void: picked.append(index))
	# 1 번 카드 화면.
	var view: CardView = hand.card_views()[1]
	# 누르기.
	_press(view, Vector2(100, 100), true)
	# 2px 옆에서 떼기 (클릭).
	_press(view, Vector2(102, 101), false)
	# 다시 누르기.
	_press(view, Vector2(100, 100), true)
	# 떼기 (클릭).
	_press(view, Vector2(100, 100), false)
	# 선택 1 → 해제 -1.
	check_eq("select then deselect", picked, [1, -1])
	# 마지막엔 선택 없음.
	check_eq("nothing selected at the end", hand.selected_index(), -1)
	# 지운다.
	hand.free()


# 누르고 60px 움직이면 끌기(선택 + 화살표), 떼면 놓은 위치와 번호를 알리고 화살표·선택이 풀리는지.
func _test_drag_emits_drop() -> void:
	# 손패.
	var hand: HandView = _hand()
	# 입력 허용.
	hand.interactive = true
	# 2 장.
	hand.set_cards(_cards([_card("a", 1), _card("b", 1)]), 3, -1)
	# 선택 신호 기록.
	var picked: Array = []
	# 놓기 신호 기록.
	var dropped: Array = []
	# 선택 신호를 기록한다.
	hand.card_selected.connect(func(index: int) -> void: picked.append(index))
	# 놓기 신호를 [번호, 위치] 로 기록한다.
	hand.card_dropped.connect(func(index: int, at: Vector2) -> void: dropped.append([index, at]))
	# 0 번 카드 화면.
	var view: CardView = hand.card_views()[0]
	# 누르기.
	_press(view, Vector2(500, 560), true)
	# 위로 60px 이동 (끌기 시작).
	_move(view, Vector2(500, 500))
	# 끌기가 0 번을 선택했다.
	check_eq("dragging selects the card", picked, [0])
	# 화살표가 보인다.
	check("aim arrow shown while dragging", hand.is_aiming())
	# 멀리서 떼기.
	_press(view, Vector2(700, 200), false)
	# 놓기 신호: 0 번, (700, 200).
	check_eq("drop reports card and position", dropped, [[0, Vector2(700, 200)]])
	# 화살표 숨김.
	check("aim arrow hidden after drop", not hand.is_aiming())
	# 선택 풀림.
	check_eq("card returns unselected", hand.selected_index(), -1)
	# 지운다.
	hand.free()


# interactive 가 false 면 클릭해도 선택되지 않고, 선택된 상태에서 잠그면 선택이 풀리는지.
func _test_locked_hand_ignores_input() -> void:
	# 손패 (기본 interactive = false).
	var hand: HandView = _hand()
	# 1 장.
	hand.set_cards(_cards([_card("a", 1)]), 3, -1)
	# 선택 신호 기록.
	var picked: Array = []
	# 선택 신호를 기록한다.
	hand.card_selected.connect(func(index: int) -> void: picked.append(index))
	# 0 번 카드 화면.
	var view: CardView = hand.card_views()[0]
	# 누르기.
	_press(view, Vector2(100, 100), true)
	# 떼기.
	_press(view, Vector2(100, 100), false)
	# 신호 없음.
	check_eq("no selection while not interactive", picked, [])

	# 입력 허용.
	hand.interactive = true
	# 누르기.
	_press(view, Vector2(100, 100), true)
	# 떼기 (선택됨).
	_press(view, Vector2(100, 100), false)
	# 다시 잠근다.
	hand.interactive = false
	# 선택이 풀렸다.
	check_eq("locking clears the selection", hand.selected_index(), -1)
	# 지운다.
	hand.free()


# SP 3 으로 비용 9 카드를 클릭하거나 끌어도 선택·놓기·화살표가 생기지 않는지.
func _test_unaffordable_card_ignores_input() -> void:
	# 손패.
	var hand: HandView = _hand()
	# 입력 허용.
	hand.interactive = true
	# 비용 9 카드 한 장, SP 3.
	hand.set_cards(_cards([_card("big", 9)]), 3, -1)
	# 선택 신호 기록.
	var picked: Array = []
	# 놓기 신호 기록.
	var dropped: Array = []
	# 선택 신호를 기록한다.
	hand.card_selected.connect(func(index: int) -> void: picked.append(index))
	# 놓기 신호를 기록한다.
	hand.card_dropped.connect(func(index: int, at: Vector2) -> void: dropped.append(index))
	# 0 번 카드 화면.
	var view: CardView = hand.card_views()[0]
	# 클릭 시도: 누르기.
	_press(view, Vector2(100, 100), true)
	# 클릭 시도: 떼기.
	_press(view, Vector2(100, 100), false)
	# 끌기 시도: 누르기.
	_press(view, Vector2(100, 100), true)
	# 끌기 시도: 60px 이동.
	_move(view, Vector2(100, 40))
	# 끌기 시도: 떼기.
	_press(view, Vector2(100, 40), false)
	# 선택 신호 없음.
	check_eq("unaffordable card cannot be selected", picked, [])
	# 놓기 신호 없음.
	check_eq("unaffordable card cannot be dropped", dropped, [])
	# 화살표 없음.
	check("no aim arrow for an unaffordable card", not hand.is_aiming())
	# 지운다.
	hand.free()
