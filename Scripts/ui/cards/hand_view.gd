## 화면 아래 가운데의 부채꼴 손패. 카드 화면(CardView)들을 만들고 배치하고 연출한다.
## 입력: 카드를 눌렀다 떼면 선택 토글(card_selected), 12px 이상 끌었다 놓으면 놓기(card_dropped).
## 연출: 드로우(덱에서 날아와 뒤집힘), 사용(흐려지며 사라짐), 버리기(묘지로 날아감), 리셔플(뒷면들이 묘지→덱).
## 규칙 상태를 모르고, BattleHud 가 알려 주는 카드·SP 만으로 동작한다.
class_name HandView
# Control: 2D UI 노드. HUD 전체를 덮는 크기로 씬에 놓인다.
extends Control

## 카드를 골랐다(index) 또는 선택을 풀었다(-1).
signal card_selected(index: int)
## index 번째 카드를 끌어다 화면 좌표 screen_position 에 놓았다.
signal card_dropped(index: int, screen_position: Vector2)

## 부채꼴 중심점이 화면 아래 끝에서 올라와 있는 거리.
const BOTTOM_OFFSET: float = 110.0
## 선택한 카드가 위로 들리는 높이.
const LIFT: float = 40.0
## 선택한 카드의 확대 배율.
const SELECTED_SCALE: float = 1.1
## 누른 뒤 이만큼(픽셀) 움직이면 클릭이 아니라 끌기로 본다.
const DRAG_THRESHOLD: float = 12.0
## 카드들이 새 자리로 미끄러지는 시간.
const LAYOUT_TIME: float = 0.2
## 드로우 비행 시간 (뒤집기 포함).
const DRAW_TIME: float = 0.25
## 드로우 비행 시작 시 카드 크기 배율 (덱 더미 크기와 비슷하게 작게).
const DRAW_START_SCALE: float = 0.6
## 버린 카드가 묘지로 날아가는 시간.
const DISCARD_TIME: float = 0.3
## 버리는 카드끼리 출발 시간 간격 (한 장씩 차례로 날아가게).
const DISCARD_STAGGER: float = 0.03
## 쓴 카드가 흐려지며 사라지는 시간.
const PLAY_FADE_TIME: float = 0.12
## 리셔플 뒷면 카드가 날아가는 시간.
const GHOST_TIME: float = 0.3
## 리셔플 뒷면 카드끼리 출발 시간 간격.
const GHOST_STAGGER: float = 0.04

# 테스트용. 트윈 없이 최종 배치만 반영한다.
## true 면 연출 없이 즉시 최종 상태로 바꾼다.
var instant: bool = false
## 입력을 받을지. false 로 바꾸면 누르기·끌기를 취소하고 선택도 푼다 (연출 재생 중 잠금).
var interactive: bool = false:
	set(value):
		# 값을 저장한다.
		interactive = value
		# 잠글 때만 정리한다.
		if not value:
			# 누르고 있던 카드와 조준 화살표를 취소한다.
			_cancel_press()
			# 들려 있던 카드를 내린다.
			deselect()

## 손패 카드 화면들 (왼쪽부터 순서대로). 규칙의 손패 순서와 같다.
var _cards: Array[CardView] = []
# 날아오는 중인 카드는 재배치 트윈과 겹치지 않게 비행이 끝날 때까지 배치에서 뺀다.
## 드로우 비행 중인 카드들.
var _flying: Array[CardView] = []
## 선택된 카드 번호. -1 이면 없음.
var _selected: int = -1
## 곧 사용될 카드 번호 (같은 카드가 여러 장일 때 어느 장을 뺄지). -1 이면 없음.
var _pending_play: int = -1
## 현재 SP (카드 흐림과 입력 차단 판정에 쓴다).
var _sp: int = 0
## 마우스로 누르고 있는 카드. 없으면 null.
var _press_view: CardView
## 누르기 시작한 화면 좌표 (끌기 거리 계산용).
var _press_position: Vector2 = Vector2.ZERO
## 누른 채 DRAG_THRESHOLD 이상 움직여 끌기 중이면 true.
var _dragging: bool = false
## 끌기 중에 그리는 조준 화살표.
var _arrow: AimArrow


## 만들 때 입력 설정과 조준 화살표를 준비한다.
func _init() -> void:
	# 손패 영역 자체는 클릭을 통과시킨다 (카드만 클릭을 받는다).
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# 조준 화살표를 만든다.
	_arrow = AimArrow.new()
	# 선택된 카드(z_index = 카드 수)보다 항상 위에 그려지게 한다.
	_arrow.z_index = 100
	# 자식으로 붙인다.
	add_child(_arrow)


## 부채꼴의 중심점 (이 노드 기준 좌표): 가로 가운데, 아래 끝에서 BOTTOM_OFFSET 위.
func anchor() -> Vector2:
	# 크기에서 계산한다 (창 크기가 바뀌면 함께 바뀐다).
	return Vector2(size.x / 2.0, size.y - BOTTOM_OFFSET)


## 연출 없이 손패를 cards 로 맞춘다. sp 는 흐림 기준, selected 는 선택할 카드 번호.
func set_cards(cards: Array[CardData], sp: int, selected: int) -> void:
	# 재생 직후 동기화가 날아오는 카드를 끊지 않게, 이미 같은 손패면 다시 만들지 않는다.
	if _shows(cards):
		# 누르기·끌기를 취소한다.
		_cancel_press()
		# SP 를 바꾼다.
		_sp = sp
		# 선택을 바꾼다.
		_selected = selected
		# 사용 대기 번호를 지운다.
		_pending_play = -1
		# 기존 카드 화면들을 새 선택·SP 에 맞게 부드럽게 다시 배치한다.
		_layout(true)
		return
	# 손패가 다르면 기존 카드 화면을 모두 지운다.
	for view in _cards:
		_free_view(view)
	# 목록을 비운다.
	_cards.clear()
	# 비행 목록도 비운다.
	_flying.clear()
	# 누르기·끌기를 취소한다.
	_cancel_press()
	# SP 를 바꾼다.
	_sp = sp
	# 선택을 바꾼다.
	_selected = selected
	# 사용 대기 번호를 지운다.
	_pending_play = -1
	# 새 카드마다 화면을 만든다.
	for card in cards:
		_cards.append(_make_view(card))
	# 연출 없이 바로 제자리에 놓는다.
	_layout(false)


## 드로우 연출: 덱 위치(from_global)에서 뒷면으로 출발해 날아오며 뒤집혀 손패 끝에 들어간다.
## 기다리지 않는다 — 다음 장의 비행이 겹쳐 시작될 수 있다.
func draw_card(card: CardData, from_global: Vector2) -> void:
	# 새 카드 화면을 만든다.
	var view: CardView = _make_view(card)
	# 손패 끝에 넣는다.
	_cards.append(view)
	# 테스트 모드면 바로 배치하고 끝낸다.
	if instant:
		_layout(false)
		return
	# 비행 중으로 표시한다 (재배치가 이 카드를 건드리지 않게).
	_flying.append(view)
	# 덱 더미 중심에 카드 중심이 오도록 시작 위치를 정한다 (전역 → 이 노드 기준 좌표).
	view.position = from_global - global_position - CardView.SIZE / 2.0
	# 기울기 없이 출발한다.
	view.rotation = 0.0
	# 작게 출발한다.
	view.scale = Vector2.ONE * DRAW_START_SCALE
	# 뒷면으로 출발한다.
	view.set_face_up(false)
	# 기존 카드들이 새 장수에 맞게 자리를 비켜 준다.
	_layout(true)

	# 이 카드가 도착할 자리 (마지막 칸).
	var target: Dictionary = _slot_transform(_cards.size() - 1)
	# 위치·기울기·세로 크기를 동시에 바꾸는 트윈.
	var move: Tween = view.create_tween().set_parallel(true)
	# 자리로 이동.
	move.tween_property(view, "position", target["position"], DRAW_TIME)
	# 자리 기울기로 회전.
	move.tween_property(view, "rotation", target["rotation"], DRAW_TIME)
	# 세로 크기를 자리 크기로.
	move.tween_property(view, "scale:y", (target["scale"] as Vector2).y, DRAW_TIME)
	# 가로 크기로 뒤집기를 흉내 내는 트윈 (순서대로 실행).
	var flip: Tween = view.create_tween()
	# 절반 시간 동안 가로 폭을 0 으로 (카드가 옆으로 선 모습).
	flip.tween_property(view, "scale:x", 0.0, DRAW_TIME / 2.0)
	# 폭이 0 인 순간 앞면으로 바꾼다.
	flip.tween_callback(view.set_face_up.bind(true))
	# 나머지 절반 동안 가로 폭을 자리 크기로 되돌린다.
	flip.tween_property(view, "scale:x", (target["scale"] as Vector2).x, DRAW_TIME / 2.0)
	# 다 끝나면 비행 종료 처리.
	flip.tween_callback(_on_flight_finished.bind(view))


## 사용한 카드를 손패에서 뺀다. 기억해 둔 사용 대기 위치의 카드가 같은 카드면 그 장을, 아니면 같은 카드 첫 장을 뺀다.
func remove_card(card: CardData) -> void:
	# 뺄 카드 번호 (못 찾으면 -1).
	var index: int = -1
	# 사용 대기 위치가 유효하고 그 자리 카드가 같은 카드면 그 장을 뺀다.
	if _pending_play >= 0 and _pending_play < _cards.size() and _cards[_pending_play].card == card:
		index = _pending_play
	# 아니면 왼쪽부터 같은 카드를 찾는다.
	else:
		# 카드 화면을 하나씩 본다.
		for i in _cards.size():
			# 같은 카드 데이터면.
			if _cards[i].card == card:
				# 그 번호를 쓰고 찾기를 멈춘다.
				index = i
				break
	# 사용 대기 위치는 한 번 쓰면 지운다.
	_pending_play = -1
	# 못 찾았으면 아무것도 하지 않는다.
	if index < 0:
		return

	# 뺄 카드 화면.
	var view: CardView = _cards[index]
	# 손패 목록에서 뺀다.
	_cards.remove_at(index)
	# 비행 중이었다면 비행 목록에서도 뺀다.
	_flying.erase(view)
	# 뺀 카드가 선택된 카드였으면 선택을 푼다.
	if _selected == index:
		_selected = -1
	# 선택된 카드가 뺀 카드 오른쪽이었으면 번호가 하나 당겨진다.
	elif _selected > index:
		_selected -= 1

	# 테스트 모드면 바로 지운다.
	if instant:
		_free_view(view)
	# 아니면 흐려지며 사라지게 한다.
	else:
		# 사라지는 동안 클릭되지 않게 한다.
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 투명도 트윈.
		var fade: Tween = view.create_tween()
		# 완전히 투명하게.
		fade.tween_property(view, "modulate:a", 0.0, PLAY_FADE_TIME)
		# 다 사라지면 노드를 지운다.
		fade.tween_callback(view.queue_free)
	# 남은 카드들을 새 자리로 옮긴다.
	_layout(true)


## 버리기 연출: 손패의 모든 카드를 묘지 위치(to_global)로 한 장씩 날려 보내며 줄이고 흐리게 한다.
func discard_all(to_global: Vector2) -> void:
	# 떠날 카드들을 복사해 둔다.
	var leaving: Array[CardView] = _cards.duplicate()
	# 손패 목록을 비운다 (이제 손패가 아니다).
	_cards.clear()
	# 비행 목록을 비운다.
	_flying.clear()
	# 누르기·끌기를 취소한다.
	_cancel_press()
	# 선택을 푼다.
	_selected = -1
	# 사용 대기 위치를 지운다.
	_pending_play = -1
	# 떠날 카드마다.
	for i in leaving.size():
		# 이번 카드 화면.
		var view: CardView = leaving[i]
		# 테스트 모드면 바로 지우고 다음 카드로.
		if instant:
			_free_view(view)
			continue
		# 날아가는 동안 클릭되지 않게 한다.
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# 왼쪽 카드부터 조금씩 늦게 출발한다.
		var delay: float = i * DISCARD_STAGGER
		# 위치·크기·투명도를 동시에 바꾸는 트윈.
		var tween: Tween = view.create_tween().set_parallel(true)
		# 묘지 더미 중심으로 이동.
		tween.tween_property(view, "position", to_global - global_position - CardView.SIZE / 2.0, DISCARD_TIME).set_delay(delay)
		# 절반 크기로 줄어든다.
		tween.tween_property(view, "scale", Vector2.ONE * 0.5, DISCARD_TIME).set_delay(delay)
		# 투명해진다.
		tween.tween_property(view, "modulate:a", 0.0, DISCARD_TIME).set_delay(delay)
		# 위 동시 동작이 모두 끝난 뒤(chain) 노드를 지운다.
		tween.chain().tween_callback(view.queue_free)


## 리셔플 연출: 뒷면 카드 count 장을 from_global(묘지)에서 to_global(덱)로 차례로 날린다.
func fly_backs(from_global: Vector2, to_global: Vector2, count: int) -> void:
	# 테스트 모드에서는 보여 줄 필요가 없다.
	if instant:
		return
	# 장수만큼.
	for i in count:
		# 뒷면 패널을 만든다 (손패 카드가 아닌 장식용).
		var ghost: Panel = CardView.make_back()
		# 확대 중심을 가운데로.
		ghost.pivot_offset = CardView.SIZE / 2.0
		# 묘지 더미 중심에서 출발한다.
		ghost.position = from_global - global_position - CardView.SIZE / 2.0
		# 조금 작게.
		ghost.scale = Vector2.ONE * 0.8
		# 자식으로 붙인다.
		add_child(ghost)
		# 순서대로 실행되는 트윈.
		var tween: Tween = ghost.create_tween()
		# i 번째 장은 i × 간격만큼 늦게 출발해 덱 더미 중심으로 이동한다.
		tween.tween_property(ghost, "position", to_global - global_position - CardView.SIZE / 2.0, GHOST_TIME).set_delay(i * GHOST_STAGGER)
		# 도착하면 지운다.
		tween.tween_callback(ghost.queue_free)


## SP 를 바꾸고 카드마다 흐림을 다시 정한다.
func set_sp(sp: int) -> void:
	# SP 를 기억한다.
	_sp = sp
	# 카드마다.
	for view in _cards:
		# 비용이 SP 이하면 또렷하게, 아니면 흐리게.
		view.set_affordable(view.card.sp_cost <= _sp)


## 곧 사용될 카드 번호를 기억한다 (재생 전 잠금으로 선택이 풀려도 유지된다).
func set_pending_play(index: int) -> void:
	# 번호를 기억한다.
	_pending_play = index


## 손패 카드 화면 목록의 복사본 (테스트용).
func card_views() -> Array[CardView]:
	# 원본을 바꾸지 못하게 복사해서 돌려준다.
	return _cards.duplicate()


## 선택된 카드 번호 (-1 이면 없음).
func selected_index() -> int:
	# 번호를 돌려준다.
	return _selected


## 선택된 카드가 있으면 선택을 풀고 제자리로 내린다. card_selected 는 내지 않는다 (푼 쪽이 이미 안다).
func deselect() -> void:
	# 선택이 없으면 할 일이 없다.
	if _selected < 0:
		return
	# 선택을 푼다.
	_selected = -1
	# 들렸던 카드를 제자리로 내린다.
	_layout(true)


## 조준 화살표가 보이는 중이면 true.
func is_aiming() -> bool:
	# 화살표에게 묻는다.
	return _arrow.is_aiming()


## 지금 손패가 cards 와 장수·순서·카드가 모두 같으면 true.
func _shows(cards: Array[CardData]) -> bool:
	# 장수가 다르면 다르다.
	if cards.size() != _cards.size():
		return false
	# 같은 자리마다.
	for i in cards.size():
		# 카드 데이터가 다르면 다르다.
		if _cards[i].card != cards[i]:
			return false
	# 모두 같다.
	return true


## 카드 화면 하나를 만들어 자식으로 붙이고 입력을 연결한다.
func _make_view(card: CardData) -> CardView:
	# 카드 화면을 만든다.
	var view := CardView.new()
	# 앞면·뒷면을 채운다.
	view.setup(card)
	# 현재 SP 로 흐림을 정한다.
	view.set_affordable(card.sp_cost <= _sp)
	# 이 카드의 마우스 입력을 받으면 어느 카드인지 함께 넘기도록 연결한다.
	view.gui_input.connect(_on_card_gui_input.bind(view))
	# 자식으로 붙인다.
	add_child(view)
	# 조준 화살표를 다시 맨 뒤(가장 위)로 옮긴다.
	move_child(_arrow, -1)
	# 만든 카드 화면을 돌려준다.
	return view


# queue_free 만 하면 이번 프레임 동안 자식으로 남으므로 먼저 떼어 낸다.
## 카드 화면을 즉시 트리에서 떼고 지운다.
func _free_view(view: CardView) -> void:
	# 아직 이 노드의 자식이면.
	if view.get_parent() == self:
		# 트리에서 뗀다.
		remove_child(view)
	# 프레임 끝에 메모리에서 지운다.
	view.queue_free()


## index 번째 자리의 목표 위치·기울기·크기를 구한다. 선택된 카드는 들리고 똑바로 서고 커진다.
func _slot_transform(index: int) -> Dictionary:
	# 부채꼴 계산으로 카드 중심 위치와 기울기를 얻는다.
	var slot: Dictionary = HandLayout.slot(index, _cards.size(), anchor())
	# 카드의 position 은 왼쪽 위 기준이므로 크기 절반만큼 뺀다.
	var at: Vector2 = (slot["position"] as Vector2) - CardView.SIZE / 2.0
	# 기울기.
	var turn: float = slot["rotation"]
	# 기본 크기.
	var grow := Vector2.ONE
	# 선택된 카드라면.
	if index == _selected:
		# 위로 들어 올린다.
		at.y -= LIFT
		# 똑바로 세운다.
		turn = 0.0
		# 조금 키운다.
		grow = Vector2.ONE * SELECTED_SCALE
	# 목표 값을 돌려준다.
	return {"position": at, "rotation": turn, "scale": grow}


## 모든 카드를 목표 자리로 옮기고, 흐림·그리기 순서·클릭 순서를 맞춘다. animate 가 true 면 트윈으로 미끄러진다.
func _layout(animate: bool) -> void:
	# 카드마다.
	for i in _cards.size():
		# 이번 카드 화면.
		var view: CardView = _cards[i]
		# SP 기준으로 흐림을 정한다.
		view.set_affordable(view.card.sp_cost <= _sp)
		# 그리기 순서: 선택된 카드는 가장 위(카드 수), 나머지는 오른쪽일수록 위(번호).
		view.z_index = _cards.size() if i == _selected else i
		# 비행 중인 카드는 비행 트윈이 옮기므로 건드리지 않는다.
		if _flying.has(view):
			continue
		# 이 카드의 목표 자리.
		var target: Dictionary = _slot_transform(i)
		# get_meta(key, null) 은 이 버전에서 기본값이 null 이면 키가 없을 때도 ERROR 를 찍는다.
		# 이전 배치 트윈이 남아 있으면.
		if view.has_meta(&"layout_tween"):
			# 이전 트윈을 꺼낸다.
			var previous: Tween = view.get_meta(&"layout_tween")
			# 아직 돌고 있으면 멈춘다 (두 트윈이 서로 싸우지 않게).
			if previous.is_valid():
				previous.kill()
		# 연출을 원하고, 테스트 모드가 아니고, 트리에 붙어 있으면 트윈으로 옮긴다 (트리 밖에서는 트윈이 돌지 않는다).
		if animate and not instant and view.is_inside_tree():
			# 동시에 진행되는 트윈.
			var tween: Tween = view.create_tween().set_parallel(true)
			# 위치.
			tween.tween_property(view, "position", target["position"], LAYOUT_TIME)
			# 기울기.
			tween.tween_property(view, "rotation", target["rotation"], LAYOUT_TIME)
			# 크기.
			tween.tween_property(view, "scale", target["scale"], LAYOUT_TIME)
			# 다음 배치에서 멈출 수 있게 트윈을 카드에 기억시킨다.
			view.set_meta(&"layout_tween", tween)
		# 아니면 즉시 목표 값으로.
		else:
			# 위치.
			view.position = target["position"]
			# 기울기.
			view.rotation = target["rotation"]
			# 크기.
			view.scale = target["scale"]
	# 클릭 판정은 z_index 가 아니라 트리 순서를 따르므로, 트리 순서를 z_index 와 같게 맞춘다.
	# 선택이 풀린 카드가 오른쪽 이웃보다 뒤에 남으면 겹친 곳의 클릭을 가로챈다.
	# 선택되지 않은 카드들을 번호 순서대로 자식 맨 뒤로 보낸다 (결과적으로 번호 순 정렬).
	for i in _cards.size():
		if i != _selected:
			move_child(_cards[i], -1)
	# 선택된 카드는 그 뒤로 (클릭 우선).
	if _selected >= 0 and _selected < _cards.size():
		move_child(_cards[_selected], -1)
	# 조준 화살표는 항상 맨 뒤로.
	move_child(_arrow, -1)


## 드로우 비행이 끝났을 때: 비행 목록에서 빼고, 손패에 남아 있으면 제자리로 정리한다.
func _on_flight_finished(view: CardView) -> void:
	# 비행 목록에서 뺀다.
	_flying.erase(view)
	# 비행 중에 제거되지 않았다면.
	if _cards.has(view):
		# 마지막으로 선택·배치 상태를 반영한다.
		_layout(true)


## 카드 하나에 들어온 마우스 입력을 처리한다 (누르기·떼기·끌기).
func _on_card_gui_input(event: InputEvent, view: CardView) -> void:
	# 잠겨 있거나 이미 손패에서 빠진 카드면 무시한다.
	if not interactive or not _cards.has(view):
		return
	# 마우스 버튼 이벤트로 형 변환 (아니면 null).
	var button := event as InputEventMouseButton
	# 왼쪽 버튼 이벤트면.
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		# 누르는 순간.
		if button.pressed:
			# SP 가 모자란 카드는 누르기 자체를 받지 않는다 (선택·끌기 불가).
			if view.card.sp_cost > _sp:
				# 이벤트를 소비해 뒤의 보드로 새지 않게 한다.
				view.accept_event()
				return
			# 누른 카드를 기억한다.
			_press_view = view
			# 누른 위치를 기억한다.
			_press_position = button.global_position
			# 아직 끌기는 아니다.
			_dragging = false
		# 떼는 순간인데, 누르기를 시작한 카드와 같다면.
		elif _press_view == view:
			# 끌던 중이면 놓기 처리.
			if _dragging:
				_finish_drag(button.global_position)
			# 끌지 않았으면 클릭으로 보고 선택을 토글한다.
			else:
				_toggle(_cards.find(view))
			# 누르기 상태를 끝낸다.
			_press_view = null
		# 버튼 이벤트는 여기서 소비한다.
		view.accept_event()
		return

	# 마우스 이동 이벤트로 형 변환 (아니면 null).
	var motion := event as InputEventMouseMotion
	# 이동이 아니거나 이 카드를 누르고 있지 않으면 무시한다.
	if motion == null or _press_view != view:
		return
	# 아직 끌기가 아니고, 누른 위치에서 문턱 거리 이상 움직였으면 끌기를 시작한다.
	if not _dragging and motion.global_position.distance_to(_press_position) >= DRAG_THRESHOLD:
		# 끌기 중으로 표시한다.
		_dragging = true
		# 끄는 카드를 선택한다.
		_selected = _cards.find(view)
		# 들어 올린다.
		_layout(true)
		# 선택을 알린다 (루트가 사거리 힌트를 보여 준다).
		card_selected.emit(_selected)
	# 끌기 중이면 카드 위쪽 가운데에서 커서까지 화살표를 그린다.
	if _dragging:
		_arrow.show_aim(view.global_position + Vector2(CardView.SIZE.x / 2.0, 0.0), motion.global_position)
	# 이동 이벤트를 소비한다.
	view.accept_event()


## 클릭한 카드의 선택을 토글한다: 이미 선택돼 있으면 풀고, 아니면 선택한다.
func _toggle(index: int) -> void:
	# 같은 카드면 해제, 아니면 그 카드로.
	_selected = -1 if _selected == index else index
	# 들기·내리기를 반영한다.
	_layout(true)
	# 선택 변경을 알린다.
	card_selected.emit(_selected)


## 끌던 카드를 놓았을 때: 화살표를 숨기고 카드를 제자리로 돌린 뒤 놓은 위치를 알린다.
func _finish_drag(screen_position: Vector2) -> void:
	# 끌던 카드의 번호.
	var index: int = _cards.find(_press_view)
	# 끌기 상태를 끝낸다.
	_dragging = false
	# 화살표를 숨긴다.
	_arrow.hide_aim()
	# 선택을 푼다 (결과 처리는 루트가 한다).
	_selected = -1
	# 카드를 손패 자리로 돌려놓는다.
	_layout(true)
	# 놓은 위치를 알린다.
	card_dropped.emit(index, screen_position)


## 누르기·끌기 상태와 조준 화살표를 취소한다.
func _cancel_press() -> void:
	# 누르던 카드를 잊는다.
	_press_view = null
	# 끌기 상태를 끈다.
	_dragging = false
	# _init 전에 불릴 수 있으므로(세터 등) 화살표가 있을 때만 숨긴다.
	if _arrow != null:
		_arrow.hide_aim()
