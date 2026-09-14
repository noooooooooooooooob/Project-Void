class_name HandView
extends Control

signal card_selected(index: int)
signal card_dropped(index: int, screen_position: Vector2)

const BOTTOM_OFFSET: float = 110.0
const LIFT: float = 40.0
const SELECTED_SCALE: float = 1.1
const DRAG_THRESHOLD: float = 12.0
const LAYOUT_TIME: float = 0.2
const DRAW_TIME: float = 0.25
const DRAW_START_SCALE: float = 0.6
const DISCARD_TIME: float = 0.3
const DISCARD_STAGGER: float = 0.03
const PLAY_FADE_TIME: float = 0.12
const GHOST_TIME: float = 0.3
const GHOST_STAGGER: float = 0.04

# 테스트용. 트윈 없이 최종 배치만 반영한다.
var instant: bool = false
var interactive: bool = false:
	set(value):
		interactive = value
		if not value:
			_cancel_press()
			if _selected >= 0:
				_selected = -1
				_layout(true)

var _cards: Array[CardView] = []
# 날아오는 중인 카드는 재배치 트윈과 겹치지 않게 비행이 끝날 때까지 배치에서 뺀다.
var _flying: Array[CardView] = []
var _selected: int = -1
var _pending_play: int = -1
var _sp: int = 0
var _press_view: CardView
var _press_position: Vector2 = Vector2.ZERO
var _dragging: bool = false
var _arrow: AimArrow


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_arrow = AimArrow.new()
	_arrow.z_index = 100
	add_child(_arrow)


func anchor() -> Vector2:
	return Vector2(size.x / 2.0, size.y - BOTTOM_OFFSET)


func set_cards(cards: Array[CardData], sp: int, selected: int) -> void:
	# 재생 직후 동기화가 날아오는 카드를 끊지 않게, 이미 같은 손패면 다시 만들지 않는다.
	if _shows(cards):
		_cancel_press()
		_sp = sp
		_selected = selected
		_pending_play = -1
		_layout(true)
		return
	for view in _cards:
		_free_view(view)
	_cards.clear()
	_flying.clear()
	_cancel_press()
	_sp = sp
	_selected = selected
	_pending_play = -1
	for card in cards:
		_cards.append(_make_view(card))
	_layout(false)


func draw_card(card: CardData, from_global: Vector2) -> void:
	var view: CardView = _make_view(card)
	_cards.append(view)
	if instant:
		_layout(false)
		return
	_flying.append(view)
	view.position = from_global - global_position - CardView.SIZE / 2.0
	view.rotation = 0.0
	view.scale = Vector2.ONE * DRAW_START_SCALE
	view.set_face_up(false)
	_layout(true)

	var target: Dictionary = _slot_transform(_cards.size() - 1)
	var move: Tween = view.create_tween().set_parallel(true)
	move.tween_property(view, "position", target["position"], DRAW_TIME)
	move.tween_property(view, "rotation", target["rotation"], DRAW_TIME)
	move.tween_property(view, "scale:y", (target["scale"] as Vector2).y, DRAW_TIME)
	var flip: Tween = view.create_tween()
	flip.tween_property(view, "scale:x", 0.0, DRAW_TIME / 2.0)
	flip.tween_callback(view.set_face_up.bind(true))
	flip.tween_property(view, "scale:x", (target["scale"] as Vector2).x, DRAW_TIME / 2.0)
	flip.tween_callback(_on_flight_finished.bind(view))


func remove_card(card: CardData) -> void:
	var index: int = -1
	if _pending_play >= 0 and _pending_play < _cards.size() and _cards[_pending_play].card == card:
		index = _pending_play
	else:
		for i in _cards.size():
			if _cards[i].card == card:
				index = i
				break
	_pending_play = -1
	if index < 0:
		return

	var view: CardView = _cards[index]
	_cards.remove_at(index)
	_flying.erase(view)
	if _selected == index:
		_selected = -1
	elif _selected > index:
		_selected -= 1

	if instant:
		_free_view(view)
	else:
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fade: Tween = view.create_tween()
		fade.tween_property(view, "modulate:a", 0.0, PLAY_FADE_TIME)
		fade.tween_callback(view.queue_free)
	_layout(true)


func discard_all(to_global: Vector2) -> void:
	var leaving: Array[CardView] = _cards.duplicate()
	_cards.clear()
	_flying.clear()
	_cancel_press()
	_selected = -1
	_pending_play = -1
	for i in leaving.size():
		var view: CardView = leaving[i]
		if instant:
			_free_view(view)
			continue
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var delay: float = i * DISCARD_STAGGER
		var tween: Tween = view.create_tween().set_parallel(true)
		tween.tween_property(view, "position", to_global - global_position - CardView.SIZE / 2.0, DISCARD_TIME).set_delay(delay)
		tween.tween_property(view, "scale", Vector2.ONE * 0.5, DISCARD_TIME).set_delay(delay)
		tween.tween_property(view, "modulate:a", 0.0, DISCARD_TIME).set_delay(delay)
		tween.chain().tween_callback(view.queue_free)


func fly_backs(from_global: Vector2, to_global: Vector2, count: int) -> void:
	if instant:
		return
	for i in count:
		var ghost: Panel = CardView.make_back()
		ghost.pivot_offset = CardView.SIZE / 2.0
		ghost.position = from_global - global_position - CardView.SIZE / 2.0
		ghost.scale = Vector2.ONE * 0.8
		add_child(ghost)
		var tween: Tween = ghost.create_tween()
		tween.tween_property(ghost, "position", to_global - global_position - CardView.SIZE / 2.0, GHOST_TIME).set_delay(i * GHOST_STAGGER)
		tween.tween_callback(ghost.queue_free)


func set_sp(sp: int) -> void:
	_sp = sp
	for view in _cards:
		view.set_affordable(view.card.sp_cost <= _sp)


func set_pending_play(index: int) -> void:
	_pending_play = index


func card_views() -> Array[CardView]:
	return _cards.duplicate()


func selected_index() -> int:
	return _selected


func is_aiming() -> bool:
	return _arrow.is_aiming()


func _shows(cards: Array[CardData]) -> bool:
	if cards.size() != _cards.size():
		return false
	for i in cards.size():
		if _cards[i].card != cards[i]:
			return false
	return true


func _make_view(card: CardData) -> CardView:
	var view := CardView.new()
	view.setup(card)
	view.set_affordable(card.sp_cost <= _sp)
	view.gui_input.connect(_on_card_gui_input.bind(view))
	add_child(view)
	move_child(_arrow, -1)
	return view


# queue_free 만 하면 이번 프레임 동안 자식으로 남으므로 먼저 떼어 낸다.
func _free_view(view: CardView) -> void:
	if view.get_parent() == self:
		remove_child(view)
	view.queue_free()


func _slot_transform(index: int) -> Dictionary:
	var slot: Dictionary = HandLayout.slot(index, _cards.size(), anchor())
	var at: Vector2 = (slot["position"] as Vector2) - CardView.SIZE / 2.0
	var turn: float = slot["rotation"]
	var grow := Vector2.ONE
	if index == _selected:
		at.y -= LIFT
		turn = 0.0
		grow = Vector2.ONE * SELECTED_SCALE
	return {"position": at, "rotation": turn, "scale": grow}


func _layout(animate: bool) -> void:
	for i in _cards.size():
		var view: CardView = _cards[i]
		view.set_affordable(view.card.sp_cost <= _sp)
		view.z_index = _cards.size() if i == _selected else i
		if _flying.has(view):
			continue
		var target: Dictionary = _slot_transform(i)
		# get_meta(key, null) 은 이 버전에서 기본값이 null 이면 키가 없을 때도 ERROR 를 찍는다.
		if view.has_meta(&"layout_tween"):
			var previous: Tween = view.get_meta(&"layout_tween")
			if previous.is_valid():
				previous.kill()
		if animate and not instant and view.is_inside_tree():
			var tween: Tween = view.create_tween().set_parallel(true)
			tween.tween_property(view, "position", target["position"], LAYOUT_TIME)
			tween.tween_property(view, "rotation", target["rotation"], LAYOUT_TIME)
			tween.tween_property(view, "scale", target["scale"], LAYOUT_TIME)
			view.set_meta(&"layout_tween", tween)
		else:
			view.position = target["position"]
			view.rotation = target["rotation"]
			view.scale = target["scale"]
	# 클릭 판정은 z_index 가 아니라 트리 순서를 따르므로, 트리 순서를 z_index 와 같게 맞춘다.
	# 선택이 풀린 카드가 오른쪽 이웃보다 뒤에 남으면 겹친 곳의 클릭을 가로챈다.
	for i in _cards.size():
		if i != _selected:
			move_child(_cards[i], -1)
	if _selected >= 0 and _selected < _cards.size():
		move_child(_cards[_selected], -1)
	move_child(_arrow, -1)


func _on_flight_finished(view: CardView) -> void:
	_flying.erase(view)
	if _cards.has(view):
		_layout(true)


func _on_card_gui_input(event: InputEvent, view: CardView) -> void:
	if not interactive or not _cards.has(view):
		return
	var button := event as InputEventMouseButton
	if button != null and button.button_index == MOUSE_BUTTON_LEFT:
		if button.pressed:
			if view.card.sp_cost > _sp:
				view.accept_event()
				return
			_press_view = view
			_press_position = button.global_position
			_dragging = false
		elif _press_view == view:
			if _dragging:
				_finish_drag(button.global_position)
			else:
				_toggle(_cards.find(view))
			_press_view = null
		view.accept_event()
		return

	var motion := event as InputEventMouseMotion
	if motion == null or _press_view != view:
		return
	if not _dragging and motion.global_position.distance_to(_press_position) >= DRAG_THRESHOLD:
		_dragging = true
		_selected = _cards.find(view)
		_layout(true)
		card_selected.emit(_selected)
	if _dragging:
		_arrow.show_aim(view.global_position + Vector2(CardView.SIZE.x / 2.0, 0.0), motion.global_position)
	view.accept_event()


func _toggle(index: int) -> void:
	_selected = -1 if _selected == index else index
	_layout(true)
	card_selected.emit(_selected)


func _finish_drag(screen_position: Vector2) -> void:
	var index: int = _cards.find(_press_view)
	_dragging = false
	_arrow.hide_aim()
	_selected = -1
	_layout(true)
	card_dropped.emit(index, screen_position)


func _cancel_press() -> void:
	_press_view = null
	_dragging = false
	if _arrow != null:
		_arrow.hide_aim()
