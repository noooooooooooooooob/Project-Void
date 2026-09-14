## BattleState 의 신호를 모두 구독해서 BattleEvent 목록으로 쌓아 두는 기록기.
## 사용 흐름: 규칙 함수 호출(play_card 등) → 그동안 난 신호가 여기 쌓임 → take_events() 로 꺼내 BattlePlayback 에 넘김.
## 신호가 난 순간의 값(체력, 장수, 행동 순서)을 복사해 두므로, 재생이 늦게 일어나도 당시 상태를 정확히 보여 준다.
class_name BattleEventRecorder
# RefCounted: 노드가 아닌 가벼운 객체.
extends RefCounted

## 아직 꺼내 가지 않은 기록들 (신호가 난 순서대로).
var _events: Array[BattleEvent] = []
# 레코더는 상태를 관찰만 할 뿐 생명 주기를 책임지지 않는다 (소유자인 BattleRoot 가 살려 둔다).
## 전투 상태에 대한 약한 참조 (서로 강하게 참조해 메모리가 해제되지 않는 순환을 피한다).
var _state_ref: WeakRef


## 전투 상태를 받아 모든 신호에 기록 함수를 연결한다.
func _init(state: BattleState) -> void:
	# 상태를 약한 참조로 기억한다.
	_state_ref = weakref(state)
	# 차례 시작 신호 → 기록.
	state.turn_started.connect(_on_turn_started)
	# 카드 사용 신호 → 기록.
	state.card_played.connect(_on_card_played)
	# 적 행동 신호 → 기록.
	state.enemy_acted.connect(_on_enemy_acted)
	# 피해 신호 → 기록.
	state.unit_damaged.connect(_on_unit_damaged)
	# 회복 신호 → 기록.
	state.unit_healed.connect(_on_unit_healed)
	# 방어도 신호 → 기록.
	state.block_gained.connect(_on_block_gained)
	# 쓰러짐 신호 → 기록.
	state.unit_died.connect(_on_unit_died)
	# 로그 신호 → 기록.
	state.log_message.connect(_on_log_message)
	# 전투 종료 신호 → 기록.
	state.battle_ended.connect(_on_battle_ended)
	# 드로우 신호 → 기록.
	state.card_drawn.connect(_on_card_drawn)
	# 리셔플 신호 → 기록.
	state.deck_reshuffled.connect(_on_deck_reshuffled)
	# 손패 버리기 신호 → 기록.
	state.hand_discarded.connect(_on_hand_discarded)


## 쌓인 기록을 모두 꺼내고 목록을 비운다.
func take_events() -> Array[BattleEvent]:
	# 지금까지의 목록을 잡아 둔다.
	var taken: Array[BattleEvent] = _events
	# 새 빈 목록으로 바꾼다 (꺼낸 목록과 섞이지 않게 새 배열을 만든다).
	_events = []
	# 꺼낸 목록을 돌려준다.
	return taken


## 차례 시작: 유닛 상태와 함께 행동 순서 바를 그릴 정보를 복사한다.
func _on_turn_started(unit: Unit) -> void:
	# 라운드·순서 정보를 읽기 위해 상태를 꺼낸다.
	var state: BattleState = _state_ref.get_ref()
	# 차례 시작 기록을 만든다.
	var event := BattleEvent.new(BattleEvent.Kind.TURN_STARTED)
	# 차례를 받은 유닛.
	event.unit = unit
	# 그 순간의 체력.
	event.hp = unit.hp
	# 그 순간의 방어도 (방금 0 으로 초기화된 값).
	event.block = unit.block
	# 현재 라운드 번호.
	event.round_index = state.round_index
	# 행동 순서 안의 현재 위치.
	event.turn_index = state.turn_index
	# 행동 순서를 복사한다 (원본 배열은 다음 라운드에 바뀐다).
	event.order = state.initiative.duplicate()
	# 순서 안의 유닛마다 지금 살아 있는지 기록한다.
	for member in state.initiative:
		event.alive.append(member.is_alive())
	# 드로우 전의 덱 장수 (더미 표시용).
	event.deck_count = unit.deck.size()
	# 드로우 전의 묘지 장수.
	event.discard_count = unit.discard.size()
	# 목록에 추가한다.
	_events.append(event)


## 카드 사용: 누가 어떤 카드를 누구에게 썼는지와 사용 직후 더미 장수.
func _on_card_played(actor: Unit, card: CardData, primary: Unit) -> void:
	# 카드 사용 기록을 만든다.
	var event := BattleEvent.new(BattleEvent.Kind.CARD_PLAYED)
	# 카드를 쓴 유닛.
	event.unit = actor
	# 쓴 카드.
	event.card = card
	# 고른 대상.
	event.target = primary
	# 사용 직후 덱 장수.
	event.deck_count = actor.deck.size()
	# 사용 직후 묘지 장수 (쓴 카드가 이미 들어가 있음).
	event.discard_count = actor.discard.size()
	# 목록에 추가한다.
	_events.append(event)


## 적 행동: 누가 무엇을 누구에게 했는지.
func _on_enemy_acted(actor: Unit, action: EnemyBrain.Action, target: Unit) -> void:
	# 적 행동 기록을 만든다.
	var event := BattleEvent.new(BattleEvent.Kind.ENEMY_ACTED)
	# 행동한 적.
	event.unit = actor
	# 고른 행동.
	event.action = action
	# 공격 대상 (공격이 아니면 null).
	event.target = target
	# 목록에 추가한다.
	_events.append(event)


## 피해: 피해량과 맞은 직후의 체력·방어도.
func _on_unit_damaged(unit: Unit, amount: int) -> void:
	# 피해 기록을 만든다.
	var event := BattleEvent.new(BattleEvent.Kind.DAMAGED)
	# 맞은 유닛.
	event.unit = unit
	# 피해량.
	event.amount = amount
	# 맞은 직후 체력.
	event.hp = unit.hp
	# 맞은 직후 방어도.
	event.block = unit.block
	# 목록에 추가한다.
	_events.append(event)


## 회복: 실제 회복량과 회복 직후 체력.
func _on_unit_healed(unit: Unit, amount: int) -> void:
	# 회복 기록을 만든다.
	var event := BattleEvent.new(BattleEvent.Kind.HEALED)
	# 회복한 유닛.
	event.unit = unit
	# 회복량.
	event.amount = amount
	# 회복 직후 체력.
	event.hp = unit.hp
	# 목록에 추가한다.
	_events.append(event)


## 방어도 획득: 얻은 양과 그 직후 방어도.
func _on_block_gained(unit: Unit, amount: int) -> void:
	# 방어도 기록을 만든다.
	var event := BattleEvent.new(BattleEvent.Kind.BLOCK_GAINED)
	# 방어도를 얻은 유닛.
	event.unit = unit
	# 얻은 양.
	event.amount = amount
	# 얻은 직후 방어도 합계.
	event.block = unit.block
	# 목록에 추가한다.
	_events.append(event)


## 쓰러짐.
func _on_unit_died(unit: Unit) -> void:
	# 쓰러짐 기록을 만든다.
	var event := BattleEvent.new(BattleEvent.Kind.DIED)
	# 쓰러진 유닛.
	event.unit = unit
	# 목록에 추가한다.
	_events.append(event)


## 로그 한 줄.
func _on_log_message(text: String) -> void:
	# 로그 기록을 만든다.
	var event := BattleEvent.new(BattleEvent.Kind.LOG)
	# 문장을 저장한다.
	event.text = text
	# 목록에 추가한다.
	_events.append(event)


## 전투 종료.
func _on_battle_ended(ally_won: bool) -> void:
	# 종료 기록을 만든다.
	var event := BattleEvent.new(BattleEvent.Kind.BATTLE_ENDED)
	# 승패를 저장한다.
	event.ally_won = ally_won
	# 목록에 추가한다.
	_events.append(event)


## 드로우: 뽑은 카드와 뽑은 직후 더미 장수 (규칙이 신호로 넘겨준 값을 그대로 쓴다).
func _on_card_drawn(unit: Unit, card: CardData, deck_count: int, discard_count: int) -> void:
	# 드로우 기록을 만든다.
	var event := BattleEvent.new(BattleEvent.Kind.CARD_DRAWN)
	# 카드를 뽑은 유닛.
	event.unit = unit
	# 뽑은 카드.
	event.card = card
	# 뽑은 직후 덱 장수.
	event.deck_count = deck_count
	# 뽑은 직후 묘지 장수.
	event.discard_count = discard_count
	# 목록에 추가한다.
	_events.append(event)


## 리셔플: 옮긴 장수와 옮긴 직후 더미 장수.
func _on_deck_reshuffled(unit: Unit, count: int) -> void:
	# 리셔플 기록을 만든다.
	var event := BattleEvent.new(BattleEvent.Kind.DECK_RESHUFFLED)
	# 리셔플한 유닛.
	event.unit = unit
	# 묘지에서 덱으로 옮긴 장수.
	event.amount = count
	# 옮긴 직후 덱 장수.
	event.deck_count = unit.deck.size()
	# 옮긴 직후 묘지 장수 (0).
	event.discard_count = unit.discard.size()
	# 목록에 추가한다.
	_events.append(event)


## 손패 버리기: 버린 카드들과 버린 직후 더미 장수.
func _on_hand_discarded(unit: Unit, cards: Array[CardData], discard_count: int) -> void:
	# 손패 버리기 기록을 만든다.
	var event := BattleEvent.new(BattleEvent.Kind.HAND_DISCARDED)
	# 손패를 버린 유닛.
	event.unit = unit
	# 버린 카드 목록을 복사해 둔다.
	event.cards = cards.duplicate()
	# 버린 직후 묘지 장수.
	event.discard_count = discard_count
	# 버린 직후 덱 장수.
	event.deck_count = unit.deck.size()
	# 목록에 추가한다.
	_events.append(event)
