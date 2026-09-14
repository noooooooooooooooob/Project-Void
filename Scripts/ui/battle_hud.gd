## 전투 화면 위에 겹쳐 그리는 2D HUD (battle_hud.tscn 의 루트).
## 행동 순서 바, 로그, SP 패널, 덱·묘지 더미, 부채꼴 손패(HandView), 차례 종료 버튼, 승패 배너를 관리한다.
## BattlePlayback 이 연출 함수(draw_card, reshuffle ...)를 부르고, BattleRoot 는 입력 신호를 받는다.
class_name BattleHud
# Control: 2D UI 노드의 기본 클래스.
extends Control

## 손패에서 카드를 골랐다(index) 또는 선택을 풀었다(-1). HandView 의 신호를 그대로 전달한다.
signal card_selected(index: int)
## 카드를 끌어다 화면 좌표 screen_position 에 놓았다.
signal card_dropped(index: int, screen_position: Vector2)
## 차례 종료 버튼을 눌렀다.
signal end_turn_pressed

## 순서 바에서 지금 차례인 유닛 이름 색 (노란색).
const CURRENT_TURN_COLOR := Color(1.0, 0.82, 0.3)
## 순서 바에서 이미 행동한 유닛 이름 색 (회색).
const ACTED_COLOR := Color(0.5, 0.5, 0.5)
## 리셔플 때 날리는 뒷면 카드의 최대 장수 (많이 섞어도 화면이 복잡하지 않게).
const RESHUFFLE_GHOSTS_MAX: int = 6
## 묘지 더미 위에 표시할 이름.
const DISCARD_PILE_NAME: String = "묘지"

# %이름: 씬 안에서 "고유 이름"으로 표시한 노드를 경로 없이 찾는다.
## 위쪽 행동 순서 바 (BBCode 로 색을 넣는다).
@onready var _turn_label: RichTextLabel = %TurnLabel
## SP 패널 (아군 차례에만 보인다).
@onready var _sp_panel: PanelContainer = %SpPanel
## SP 패널 안의 글자.
@onready var _sp_label: Label = %SpLabel
## 차례 종료 버튼.
@onready var _end_turn_button: Button = %EndTurnButton
## 전투 로그.
@onready var _log: RichTextLabel = %BattleLog
## 화면 가운데 승패 배너.
@onready var _banner: Label = %Banner
## 부채꼴 손패.
@onready var _hand: HandView = %HandView
## 왼쪽 아래 덱 더미.
@onready var _deck_pile: PileView = %DeckPile
## 오른쪽 아래 묘지 더미.
@onready var _discard_pile: PileView = %DiscardPile

## 입력을 받을 수 있는 상태인지 (차례 종료 버튼 활성화에 쓴다).
var _interactive: bool = false


## 씬이 준비되면 버튼·손패 신호를 연결하고 초기 표시를 정한다.
func _ready() -> void:
	# 버튼을 누르면 end_turn_pressed 를 낸다.
	_end_turn_button.pressed.connect(_on_end_turn_button_pressed)
	# 손패 카드 선택을 밖으로 전달한다.
	_hand.card_selected.connect(_on_hand_card_selected)
	# 손패 카드 놓기를 밖으로 전달한다.
	_hand.card_dropped.connect(_on_hand_card_dropped)
	# 묘지 더미 이름은 항상 "묘지".
	_discard_pile.set_owner_name(DISCARD_PILE_NAME)
	# 처음에는 차례인 아군이 없으므로 SP 패널을 숨긴다.
	_refresh_sp(null)
	# 버튼 활성화 상태를 반영한다 (처음엔 비활성).
	_apply_interactive()


## 연출과 상관없이 규칙 상태 그대로 HUD 를 맞춘다 (재생이 끝난 뒤 호출).
func sync_from_state(state: BattleState, selected_card: int) -> void:
	# 전투가 끝났으면 차례 유닛이 없는 것으로 본다.
	var actor: Unit = null if state.finished else state.current_unit()
	# SP 패널을 갱신한다.
	_refresh_sp(actor)
	# 아군 차례면 손패와 더미를 그 유닛 것으로 보여 준다.
	if actor != null and actor.is_ally():
		# 손패를 규칙의 손패와 같게 만든다 (같으면 기존 카드 화면을 유지).
		_hand.set_cards(actor.hand, actor.sp, selected_card)
		# 더미 이름과 장수를 보여 준다.
		_show_piles(actor.data.display_name, actor.deck.size(), actor.discard.size())
	# 적 차례이거나 끝난 전투면 손패를 비우고 더미를 흐리게 한다.
	else:
		# 손패를 비운다.
		_clear_hand(0)
		# 더미를 흐리게 한다.
		_dim_piles()
	# 끝난 전투면 순서 바 대신 결과를 보여 준다.
	if state.finished:
		# 승패 문구.
		_turn_label.text = "승리!" if state.ally_won else "패배..."
		return
	# 행동 순서의 유닛마다 살아 있는지 모은다.
	var alive: Array[bool] = []
	# 순서대로 확인한다.
	for member in state.initiative:
		alive.append(member.is_alive())
	# 순서 바 문장을 만들어 넣는다.
	_turn_label.text = turn_bar_text(state.round_index, state.initiative, alive, state.turn_index)


## 차례 시작 이벤트를 받아 순서 바, 손패, SP, 더미를 그 차례에 맞게 바꾼다.
func show_turn(event: BattleEvent) -> void:
	# 기록 시점의 순서 정보로 순서 바를 그린다.
	_turn_label.text = turn_bar_text(event.round_index, event.order, event.alive, event.turn_index)
	# 아군 차례.
	if event.unit.is_ally():
		# 드로우 연출이 이어지므로 손패를 비우고, 새 카드가 SP 부족으로 흐려지지 않게 현재 SP 로 시작한다.
		_clear_hand(event.unit.sp)
		# SP 패널을 이 유닛으로.
		_refresh_sp(event.unit)
		# 더미를 이 유닛의 기록 시점 장수로.
		_show_piles(event.unit.data.display_name, event.deck_count, event.discard_count)
	# 적 차례.
	else:
		# 손패를 비운다.
		_clear_hand(0)
		# SP 패널을 숨긴다.
		_refresh_sp(null)
		# 더미를 흐리게 한다.
		_dim_piles()


## 입력 가능 여부를 손패와 버튼에 적용한다 (BattleRoot 가 재생 전후로 부른다).
func set_interactive(enabled: bool) -> void:
	# 상태를 기억한다.
	_interactive = enabled
	# 손패 입력을 켜거나 끈다.
	_hand.interactive = enabled
	# 버튼 활성화를 반영한다.
	_apply_interactive()


## 곧 사용될 카드의 손패 위치를 손패에 알려 준다.
func set_pending_play(index: int) -> void:
	# 손패에 그대로 넘긴다.
	_hand.set_pending_play(index)


## 드로우 이벤트: 덱 더미 위치에서 카드 한 장이 손패로 날아오게 하고 더미 숫자를 갱신한다.
func draw_card(event: BattleEvent) -> void:
	# 덱 더미 중심에서 출발하는 드로우 비행을 시작한다.
	_hand.draw_card(event.card, _deck_pile.center_global())
	# 뽑은 직후 장수로 더미 숫자를 바꾼다.
	_set_counts(event.deck_count, event.discard_count)


## 리셔플 이벤트: 묘지에서 덱으로 뒷면 카드들을 날리고 더미 숫자를 갱신한다.
func reshuffle(event: BattleEvent) -> void:
	# 옮긴 장수만큼(최대 6장) 뒷면 카드를 묘지 → 덱으로 날린다.
	_hand.fly_backs(_discard_pile.center_global(), _deck_pile.center_global(), mini(event.amount, RESHUFFLE_GHOSTS_MAX))
	# 섞은 직후 장수로 더미 숫자를 바꾼다.
	_set_counts(event.deck_count, event.discard_count)


## 손패 버리기 이벤트: 손패 카드들을 묘지로 날리고 더미 숫자를 갱신한다.
func discard_hand(event: BattleEvent) -> void:
	# 손패의 모든 카드를 묘지 더미 중심으로 날린다.
	_hand.discard_all(_discard_pile.center_global())
	# 버린 직후 장수로 더미 숫자를 바꾼다.
	_set_counts(event.deck_count, event.discard_count)


## 카드 사용 이벤트: 쓴 카드를 손패에서 없애고 SP·더미 숫자를 갱신한다.
func remove_played_card(event: BattleEvent) -> void:
	# 손패에서 그 카드를 없앤다.
	_hand.remove_card(event.card)
	# 남은 SP 로 카드 흐림을 다시 계산한다.
	_hand.set_sp(event.unit.sp)
	# SP 패널을 갱신한다.
	_refresh_sp(event.unit)
	# 사용 직후 장수로 더미 숫자를 바꾼다.
	_set_counts(event.deck_count, event.discard_count)


## 로그에 한 줄을 추가한다.
func append_log(text: String) -> void:
	# 줄바꿈을 붙여 덧붙인다.
	_log.append_text(text + "\n")


## 승패 배너를 띄운다.
func show_banner(ally_won: bool) -> void:
	# 문구를 정한다.
	_banner.text = "승리!" if ally_won else "패배..."
	# 보이게 한다.
	_banner.visible = true


## 손패 노드 (테스트용 접근자).
func hand_view() -> HandView:
	# 손패를 돌려준다.
	return _hand


## 덱 더미 노드 (테스트용 접근자).
func deck_pile() -> PileView:
	# 덱 더미를 돌려준다.
	return _deck_pile


## 묘지 더미 노드 (테스트용 접근자).
func discard_pile() -> PileView:
	# 묘지 더미를 돌려준다.
	return _discard_pile


## SP 패널 글자. 패널이 숨겨져 있으면 빈 문자열 (테스트용).
func sp_text() -> String:
	# 보일 때만 글자를 돌려준다.
	return _sp_label.text if _sp_panel.visible else ""


## 로그 전체 글자 (BBCode 태그를 뺀 순수 문장, 테스트용).
func log_text() -> String:
	# 해석된 글자를 돌려준다.
	return _log.get_parsed_text()


## 차례 종료 버튼이 활성화되어 있는지 (테스트용).
func end_turn_enabled() -> bool:
	# 비활성이 아니면 활성.
	return not _end_turn_button.disabled


## 승패 배너가 보이는지 (테스트용).
func banner_visible() -> bool:
	# 보이기 상태를 돌려준다.
	return _banner.visible


## 승패 배너 문구 (테스트용).
func banner_text() -> String:
	# 문구를 돌려준다.
	return _banner.text


## 순서 바 문장을 만든다. 예: "R1  [회색]정찰병[/] → [노랑]▶추적자[/] → 선봉"
## 쓰러진 유닛은 빼고, 이미 행동한 유닛은 회색, 지금 차례는 굵은 노란색에 ▶ 표시.
static func turn_bar_text(round_index: int, order: Array[Unit], alive: Array[bool], turn_index: int) -> String:
	# 유닛별 조각을 모을 배열.
	var parts: PackedStringArray = []
	# 행동 순서대로.
	for i in order.size():
		# 기록 시점에 쓰러져 있던 유닛은 뺀다.
		if not alive[i]:
			continue
		# 유닛 이름.
		var unit_name: String = order[i].data.display_name
		# 이미 행동한 유닛: 회색.
		if i < turn_index:
			parts.append("[color=#%s]%s[/color]" % [ACTED_COLOR.to_html(false), unit_name])
		# 지금 차례: 굵게, 노란색, ▶ 표시.
		elif i == turn_index:
			parts.append("[b][color=#%s]▶%s[/color][/b]" % [CURRENT_TURN_COLOR.to_html(false), unit_name])
		# 아직 행동하지 않은 유닛: 기본 색.
		else:
			parts.append(unit_name)
	# "R라운드  이름 → 이름 → ..." 로 이어 붙인다.
	return "R%d  %s" % [round_index, " → ".join(parts)]


## SP 패널을 유닛에 맞게 갱신한다. 아군이 아니면(또는 null) 숨긴다.
func _refresh_sp(actor: Unit) -> void:
	# 아군 차례일 때만 보인다.
	_sp_panel.visible = actor != null and actor.is_ally()
	# 숨겼으면 더 할 일이 없다.
	if not _sp_panel.visible:
		return
	# 최대 SP.
	var max_sp: int = (actor.data as AllyData).max_sp
	# 남은 SP 는 ●, 쓴 SP 는 ○ 로 표시한다.
	var pips: String = "●".repeat(actor.sp) + "○".repeat(maxi(max_sp - actor.sp, 0))
	# "SP / ●●○ / 2 / 3" 세 줄로 쓴다.
	_sp_label.text = "SP\n%s\n%d / %d" % [pips, actor.sp, max_sp]


## 손패를 비운다. sp 는 이후 들어올 카드의 흐림 판정 기준.
func _clear_hand(sp: int) -> void:
	# 타입이 정해진 빈 배열 (set_cards 가 Array[CardData] 를 요구한다).
	var none: Array[CardData] = []
	# 빈 손패로 설정한다.
	_hand.set_cards(none, sp, -1)


## 더미에 유닛 이름과 장수를 보여 주고 흐림을 푼다.
func _show_piles(owner_name: String, deck_count: int, discard_count: int) -> void:
	# 덱 더미 위에 유닛 이름.
	_deck_pile.set_owner_name(owner_name)
	# 두 더미의 장수.
	_set_counts(deck_count, discard_count)
	# 덱 더미를 또렷하게.
	_deck_pile.set_dimmed(false)
	# 묘지 더미를 또렷하게.
	_discard_pile.set_dimmed(false)


## 두 더미를 흐리게 한다 (적 차례).
func _dim_piles() -> void:
	# 덱 더미를 흐리게.
	_deck_pile.set_dimmed(true)
	# 묘지 더미를 흐리게.
	_discard_pile.set_dimmed(true)


## 두 더미의 장수 숫자를 바꾼다.
func _set_counts(deck_count: int, discard_count: int) -> void:
	# 덱 장수.
	_deck_pile.set_count(deck_count)
	# 묘지 장수.
	_discard_pile.set_count(discard_count)


## 입력 가능 상태를 차례 종료 버튼에 반영한다.
func _apply_interactive() -> void:
	# 입력 불가면 버튼을 비활성화한다.
	_end_turn_button.disabled = not _interactive


## 손패의 카드 선택 신호를 HUD 신호로 전달한다.
func _on_hand_card_selected(index: int) -> void:
	# 그대로 다시 낸다.
	card_selected.emit(index)


## 손패의 카드 놓기 신호를 HUD 신호로 전달한다.
func _on_hand_card_dropped(index: int, screen_position: Vector2) -> void:
	# 그대로 다시 낸다.
	card_dropped.emit(index, screen_position)


## 차례 종료 버튼 신호를 HUD 신호로 전달한다.
func _on_end_turn_button_pressed() -> void:
	# end_turn_pressed 를 낸다.
	end_turn_pressed.emit()
