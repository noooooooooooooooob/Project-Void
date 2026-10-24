## BattleState 의 신호를 구독해서 BattleEvent 목록으로 쌓아 두는 기록기 (화면에 보여 주지 않는 phase_started 는 기록하지 않는다).
## 사용 흐름: 규칙 함수 호출(play_card 등) → 그동안 난 신호가 여기 쌓임 → take_events() 로 꺼내 BattlePlayback 에 넘김.
## 신호가 난 순간의 값(체력, 장수, 행동 순서)을 복사해 두므로, 재생이 늦게 일어나도 당시 상태를 정확히 보여 준다.
class_name BattleEventRecorder
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
	state.turn_started.connect(_on_turn_started)
	state.card_played.connect(_on_card_played)
	state.enemy_acted.connect(_on_enemy_acted)
	state.unit_damaged.connect(_on_unit_damaged)
	state.unit_healed.connect(_on_unit_healed)
	state.block_gained.connect(_on_block_gained)
	state.unit_died.connect(_on_unit_died)
	state.log_message.connect(_on_log_message)
	state.battle_ended.connect(_on_battle_ended)
	state.card_drawn.connect(_on_card_drawn)
	state.deck_reshuffled.connect(_on_deck_reshuffled)
	state.hand_discarded.connect(_on_hand_discarded)
	state.unit_moved.connect(_on_unit_moved)
	# 흐트러짐·차례 쉼·상태 변화.
	state.unit_staggered.connect(_on_unit_staggered)
	state.stagger_damaged.connect(_on_stagger_damaged)
	state.turn_skipped.connect(_on_turn_skipped)
	state.status_changed.connect(_on_status_changed)


## 쌓인 기록을 모두 꺼내고 목록을 비운다.
func take_events() -> Array[BattleEvent]:
	# 지금까지의 목록을 잡아 둔다.
	var taken: Array[BattleEvent] = _events
	# 새 빈 목록으로 바꾼다 (꺼낸 목록과 섞이지 않게 새 배열을 만든다).
	_events = []
	return taken


## 차례 시작: 유닛 상태와 함께 행동 순서 바를 그릴 정보를 복사한다.
func _on_turn_started(unit: Unit) -> void:
	# 라운드·순서 정보를 읽기 위해 상태를 꺼낸다.
	var state: BattleState = _state_ref.get_ref()
	var event := BattleEvent.new(BattleEvent.Kind.TURN_STARTED)
	event.unit = unit
	event.hp = unit.hp
	# 그 순간의 방어도 (방금 0 으로 초기화된 값).
	event.block = unit.block
	# 차례 시작 시점의 칸 (재생 때 규칙의 칸은 이미 이동 뒤일 수 있다).
	event.cell = unit.cell
	event.round_index = state.round_index
	event.turn_index = state.turn_index
	# 행동 순서를 복사한다 (원본 배열은 다음 라운드에 바뀐다).
	event.order = state.initiative.duplicate()
	# 순서 안의 유닛마다 지금 살아 있는지 기록한다.
	for member in state.initiative:
		event.alive.append(member.is_alive())
	# 드로우 전의 덱 장수 (더미 표시용).
	event.deck_count = unit.deck.size()
	event.discard_count = unit.discard.size()
	_events.append(event)


## 카드 사용: 누가 어떤 카드를 어느 기준 유닛에 썼는지와 사용 직후 더미 장수.
func _on_card_played(actor: Unit, card: CardData, anchor: Unit) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.CARD_PLAYED)
	event.unit = actor
	event.card = card
	# 기준 유닛 (화면의 돌진 연출·로그가 쓴다).
	event.target = anchor
	# 기준 유닛의 편과 그 순간의 칸.
	event.target_team = anchor.team
	event.target_cell = anchor.cell
	event.deck_count = actor.deck.size()
	# 사용 직후 묘지 장수 (쓴 카드가 이미 들어가 있음).
	event.discard_count = actor.discard.size()
	_events.append(event)


## 적 행동: 누가 무엇을 누구에게 했는지.
func _on_enemy_acted(actor: Unit, action: EnemyBrain.Action, target: Unit) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.ENEMY_ACTED)
	event.unit = actor
	event.action = action
	# 공격 대상 (공격이 아니면 null).
	event.target = target
	_events.append(event)


## 피해: 피해량·치명 여부와 맞은 직후의 체력·방어도.
func _on_unit_damaged(unit: Unit, amount: int, critical: bool) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.DAMAGED)
	event.unit = unit
	event.amount = amount
	event.critical = critical
	event.hp = unit.hp
	event.block = unit.block
	# 맞은 직후 흐트러짐 게이지와 무너짐 여부.
	event.stagger = unit.stagger
	event.broken = unit.broken
	_events.append(event)


## 회복: 실제 회복량과 회복 직후 체력.
func _on_unit_healed(unit: Unit, amount: int) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.HEALED)
	event.unit = unit
	event.amount = amount
	event.hp = unit.hp
	_events.append(event)


## 방어도 획득: 얻은 양과 그 직후 방어도.
func _on_block_gained(unit: Unit, amount: int) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.BLOCK_GAINED)
	event.unit = unit
	event.amount = amount
	event.block = unit.block
	_events.append(event)


## 쓰러짐.
func _on_unit_died(unit: Unit) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.DIED)
	event.unit = unit
	event.cell = unit.cell
	_events.append(event)


## 로그 한 줄.
func _on_log_message(text: String) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.LOG)
	event.text = text
	_events.append(event)


## 전투 종료.
func _on_battle_ended(ally_won: bool) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.BATTLE_ENDED)
	event.ally_won = ally_won
	_events.append(event)


## 드로우: 뽑은 카드와 뽑은 직후 더미 장수 (규칙이 신호로 넘겨준 값을 그대로 쓴다).
func _on_card_drawn(unit: Unit, card: CardData, deck_count: int, discard_count: int) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.CARD_DRAWN)
	event.unit = unit
	event.card = card
	event.deck_count = deck_count
	event.discard_count = discard_count
	_events.append(event)


## 리셔플: 옮긴 장수와 옮긴 직후 더미 장수.
func _on_deck_reshuffled(unit: Unit, count: int) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.DECK_RESHUFFLED)
	event.unit = unit
	# 묘지에서 덱으로 옮긴 장수.
	event.amount = count
	event.deck_count = unit.deck.size()
	# 옮긴 직후 묘지 장수 (0).
	event.discard_count = unit.discard.size()
	_events.append(event)


## 손패 버리기: 버린 카드들과 버린 직후 더미 장수.
func _on_hand_discarded(unit: Unit, cards: Array[CardData], discard_count: int) -> void:
	# 손패 버리기 기록을 만든다.
	var event := BattleEvent.new(BattleEvent.Kind.HAND_DISCARDED)
	event.unit = unit
	# 버린 카드 목록을 복사해 둔다.
	event.cards = cards.duplicate()
	event.discard_count = discard_count
	event.deck_count = unit.deck.size()
	_events.append(event)


## 이동: 누가 어느 칸에서 어느 칸으로 옮겼는지.
func _on_unit_moved(unit: Unit, from_cell: Vector2i, to_cell: Vector2i) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.UNIT_MOVED)
	event.unit = unit
	event.from_cell = from_cell
	event.to_cell = to_cell
	_events.append(event)


## 무너짐: 게이지가 0 이 되어 다음 차례를 쉰다.
func _on_unit_staggered(unit: Unit) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.STAGGERED)
	event.unit = unit
	event.stagger = unit.stagger
	event.broken = true
	_events.append(event)


## 흐트러짐만 깎임.
func _on_stagger_damaged(unit: Unit, amount: int) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.STAGGER_DAMAGED)
	event.unit = unit
	event.amount = amount
	event.stagger = unit.stagger
	event.broken = unit.broken
	_events.append(event)


## 무너진 유닛이 차례를 쉬고 게이지를 되찾음.
func _on_turn_skipped(unit: Unit) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.TURN_SKIPPED)
	event.unit = unit
	event.stagger = unit.stagger
	event.broken = false
	_events.append(event)


## 상태 스택 변화.
func _on_status_changed(unit: Unit, status_id: StringName, value: int) -> void:
	var event := BattleEvent.new(BattleEvent.Kind.STATUS_CHANGED)
	event.unit = unit
	event.status_id = status_id
	event.status_value = value
	_events.append(event)
