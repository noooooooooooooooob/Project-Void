## 전투 한 판의 규칙과 상태를 모두 가진 핵심 객체.
## 노드가 아니라서 화면 없이도(테스트, 밸런스 시뮬레이션) 전투를 끝까지 돌릴 수 있다.
## 상태가 바뀔 때마다 신호를 내고, 화면(BattleEventRecorder → BattlePlayback)은 그 신호만 보고 연출한다.
##
## 흐름: start_battle() → (아군 차례에서 멈춤) → play_card() 여러 번 → end_turn() → (적 차례 자동 처리) → 다음 아군 차례에서 멈춤 ...
class_name BattleState
# RefCounted: 노드가 아닌 가벼운 객체. 참조가 없어지면 자동으로 해제된다.
extends RefCounted

## 어떤 유닛의 차례가 시작됐다 (방어도 초기화 직후, 아군이면 SP 충전·드로우 전).
signal turn_started(unit: Unit)
## 유닛이 공격을 받았다. amount 는 방어도로 막기 전의 공격 피해량이다.
signal unit_damaged(unit: Unit, amount: int)
## 유닛이 쓰러졌다 (unit_damaged 바로 뒤에 나간다).
signal unit_died(unit: Unit)
## 전투가 끝났다. ally_won 이 true 면 아군 승리.
signal battle_ended(ally_won: bool)
## 전투 로그에 한 줄을 남긴다.
signal log_message(text: String)
## 아군이 카드를 썼다. primary 는 플레이어가 고른 대상 (범위 공격이면 실제로는 더 맞을 수 있음).
signal card_played(actor: Unit, card: CardData, primary: Unit)
## 적이 행동을 정했다. 공격이 아니면 target 은 null.
signal enemy_acted(actor: Unit, action: EnemyBrain.Action, target: Unit)
## 유닛이 회복했다. amount 는 최대 체력에 막혀 실제로 오른 양이다.
signal unit_healed(unit: Unit, amount: int)
## 유닛이 방어도를 얻었다.
signal block_gained(unit: Unit, amount: int)
## 드로우 도중 덱이 비어 묘지 count 장을 덱으로 섞어 넣었다.
signal deck_reshuffled(unit: Unit, count: int)
## 카드 한 장을 뽑았다. 뽑은 직후의 덱·묘지 장수를 함께 보낸다 (화면 더미 숫자용).
signal card_drawn(unit: Unit, card: CardData, deck_count: int, discard_count: int)
## 차례가 끝나 손패를 버렸다. cards 는 버린 카드들, discard_count 는 버린 뒤 묘지 장수.
signal hand_discarded(unit: Unit, cards: Array[CardData], discard_count: int)

## 아군 차례가 시작될 때마다 뽑는 카드 수.
const DRAW_PER_TURN: int = 4

## 전장의 모든 유닛 (아군 먼저, 그다음 적군 순서로 들어 있다). 쓰러진 유닛도 남아 있다.
var units: Array[Unit] = []
## 사거리·막힘·범위 계산기.
var resolver: TargetResolver
## 덱 섞기에 쓰는 난수 생성기. 시드를 고정하면 전투를 똑같이 재현할 수 있다.
var rng: RandomNumberGenerator
## 현재 라운드 번호 (1 부터).
var round_index: int = 0
## 이번 라운드의 행동 순서 (속도가 빠른 순).
var initiative: Array[Unit] = []
## initiative 안에서 지금 차례인 위치. -1 이면 라운드 시작 전.
var turn_index: int = -1
## 전투가 끝났으면 true.
var finished: bool = false
## 끝났을 때 아군이 이겼으면 true.
var ally_won: bool = false


## 전투 구성과 난수 생성기로 전투를 준비한다 (아직 시작하지는 않음).
func _init(encounter: EncounterData, p_rng: RandomNumberGenerator) -> void:
	# 난수 생성기를 기억한다.
	rng = p_rng
	# 양쪽 격자 크기로 대상 판정기를 만든다.
	resolver = TargetResolver.new(encounter.ally_grid, encounter.enemy_grid)

	# 유닛마다 붙일 번호. 0 부터 차례로 늘린다.
	var next_id: int = 0
	# 아군 배치 목록을 돌며 아군 유닛을 만든다.
	for placement in encounter.ally_units:
		# 배치 정보로 아군 유닛을 만든다.
		var ally := Unit.new(next_id, placement.unit_data, Unit.Team.ALLY, placement.cell)
		# 전투 시작 전에 덱을 섞는다.
		ally.shuffle_deck(rng)
		# 전장 목록에 넣는다.
		units.append(ally)
		# 다음 번호로 넘어간다.
		next_id += 1

	# 적군 배치 목록을 돌며 적 유닛을 만든다 (번호는 아군 다음부터 이어진다).
	for placement in encounter.enemy_units:
		# 적 유닛을 만들어 바로 전장 목록에 넣는다.
		units.append(Unit.new(next_id, placement.unit_data, Unit.Team.ENEMY, placement.cell))
		# 다음 번호로 넘어간다.
		next_id += 1


## 주어진 편에서 살아 있는 유닛만 모아 돌려준다.
func living_units(team: Unit.Team) -> Array[Unit]:
	# 결과를 담을 배열.
	var alive: Array[Unit] = []
	# 모든 유닛을 확인한다.
	for unit in units:
		# 살아 있고 요청한 편이면 담는다.
		if unit.is_alive() and unit.team == team:
			alive.append(unit)
	# 모은 목록을 돌려준다.
	return alive


## 지금 차례인 유닛. 라운드 시작 전이거나 범위를 벗어나면 null.
func current_unit() -> Unit:
	# turn_index 가 유효한 범위가 아니면 차례인 유닛이 없다.
	if turn_index < 0 or turn_index >= initiative.size():
		return null
	# 행동 순서에서 현재 위치의 유닛을 돌려준다.
	return initiative[turn_index]


# 시그널을 밖에서 직접 emit 하지 않도록 통로를 하나로 둔다.
# `log` 은 GDScript 전역 함수(자연로그)라 이름으로 쓸 수 없다.
## 전투 로그 한 줄을 신호로 내보낸다.
func write_log(text: String) -> void:
	# 로그 신호를 낸다.
	log_message.emit(text)


## 유닛에게 피해를 주고 알린다. 쓰러지면 쓰러짐도 알린다.
## 카드 공격과 적 공격 모두 이 함수를 거친다.
func apply_damage(target: Unit, amount: int) -> void:
	# 방어도 → 체력 순서로 피해를 적용한다.
	target.take_damage(amount)
	# 피해 신호를 낸다.
	unit_damaged.emit(target, amount)
	# 이번 피해로 체력이 0 이 됐는지 확인한다.
	if not target.is_alive():
		# 쓰러짐 신호를 낸다.
		unit_died.emit(target)
		# 로그에 남긴다.
		write_log("%s 쓰러짐" % target.data.display_name)


## 유닛을 회복시키고 실제로 오른 양을 알린다.
func apply_heal(target: Unit, amount: int) -> void:
	# 회복 전 체력을 기억한다.
	var before: int = target.hp
	# 회복을 적용한다 (최대 체력에서 잘린다).
	target.heal(amount)
	# 실제 증가량(후 - 전)으로 신호를 낸다.
	unit_healed.emit(target, target.hp - before)


## 유닛에게 방어도를 주고 알린다.
func apply_block(target: Unit, amount: int) -> void:
	# 방어도를 더한다.
	target.gain_block(amount)
	# 방어도 신호를 낸다.
	block_gained.emit(target, amount)


## 적이 정한 행동을 신호로 알린다 (EnemyBrain 이 부르는 통로).
func report_enemy_action(actor: Unit, action: EnemyBrain.Action, target: Unit) -> void:
	# 적 행동 신호를 낸다.
	enemy_acted.emit(actor, action, target)


## 한쪽 편이 전멸했는지 확인하고, 그렇다면 전투를 끝낸다.
func check_end() -> void:
	# 이미 끝난 전투는 다시 끝내지 않는다 (신호 중복 방지).
	if finished:
		return
	# 살아 있는 아군이 있는지.
	var allies_alive: bool = not living_units(Unit.Team.ALLY).is_empty()
	# 살아 있는 적군이 있는지.
	var enemies_alive: bool = not living_units(Unit.Team.ENEMY).is_empty()
	# 양쪽 다 살아 있으면 전투는 계속된다.
	if allies_alive and enemies_alive:
		return
	# 전투 종료로 표시한다.
	finished = true
	# 아군이 남아 있으면 아군 승리.
	ally_won = allies_alive
	# 종료 신호를 낸다.
	battle_ended.emit(ally_won)


## 지금 차례인 아군이 손패의 hand_index 번째 카드를 primary 대상에게 쓴다.
## 규칙에 맞지 않으면 아무것도 바꾸지 않고 false 를 돌려준다. 성공하면 true.
func play_card(hand_index: int, primary: Unit) -> bool:
	# 끝난 전투에서는 카드를 쓸 수 없다.
	if finished:
		return false

	# 지금 차례인 유닛을 가져온다.
	var actor: Unit = current_unit()
	# 차례인 유닛이 없거나, 적이거나, 쓰러졌으면 카드를 쓸 수 없다.
	if actor == null or not actor.is_ally() or not actor.is_alive():
		return false
	# 손패 번호가 범위를 벗어나면 실패.
	if hand_index < 0 or hand_index >= actor.hand.size():
		return false

	# 쓸 카드를 손패에서 찾는다 (아직 빼지는 않음).
	var card: CardData = actor.hand[hand_index]
	# SP 가 모자라면 실패.
	if card.sp_cost > actor.sp:
		return false
	# 대상이 유효하지 않으면(사거리 밖, 막힘, 같은 편 등) 실패.
	if not resolver.is_valid_target(actor, primary, card.attack_type, card.attack_range, units):
		return false

	# 여기부터는 검사를 모두 통과했으므로 상태를 바꾼다.
	# SP 를 비용만큼 쓴다.
	actor.sp -= card.sp_cost
	# 손패에서 카드를 뺀다.
	actor.hand.remove_at(hand_index)
	# 쓴 카드는 묘지로 간다.
	actor.discard.append(card)
	# 카드 사용 신호를 낸다 (피해 신호보다 먼저 나가야 화면이 돌진 → 피격 순으로 연출한다).
	card_played.emit(actor, card, primary)
	# 로그에 "사용자 → 대상 (카드)" 형식으로 남긴다.
	write_log("%s → %s (%s)" % [actor.data.display_name, primary.data.display_name, card.display_name])

	# 범위 모양에 따라 맞는 유닛마다 피해를 준다.
	for victim in resolver.expand_shape(primary, card.shape, units):
		apply_damage(victim, card.damage)

	# 이번 공격으로 전투가 끝났는지 확인한다.
	check_end()
	# 성공.
	return true


## 전투를 시작한다. 첫 라운드를 준비하고 첫 아군 차례까지 진행한 뒤 멈춘다.
func start_battle() -> void:
	# 유닛이 전혀 없는(또는 이미 결판난) 인카운터라면 여기서 즉시 끝내야 한다.
	# 그렇지 않으면 _run_until_player_input() 이 매 라운드 빈 initiative 만
	# 반복 계산하며 멈추지 않는다.
	check_end()
	# 1 라운드를 준비한다 (행동 순서 계산).
	_start_round()
	# 첫 아군 차례가 올 때까지 진행한다 (그 사이 적 차례는 자동 처리).
	_run_until_player_input()


## 지금 차례인 아군의 차례를 끝낸다. 손패를 버리고 다음 아군 차례까지 진행한다.
func end_turn() -> void:
	# 지금 차례인 유닛을 가져온다.
	var actor: Unit = current_unit()
	# 아군 차례였다면 남은 손패를 묘지로 버린다.
	if actor != null and actor.is_ally():
		_discard_hand(actor)
	# 다음 아군 차례가 올 때까지 진행한다.
	_run_until_player_input()


## 새 라운드를 준비한다: 번호를 올리고 행동 순서를 다시 계산한다.
func _start_round() -> void:
	# 라운드 번호를 1 올린다.
	round_index += 1
	# 살아 있는 유닛으로 행동 순서를 새로 만든다.
	initiative = _compute_initiative()
	# 아직 아무도 행동하지 않은 상태로 되돌린다 (다음 진행에서 0 이 된다).
	turn_index = -1


## 살아 있는 유닛을 속도가 빠른 순으로 정렬한 행동 순서를 만든다.
func _compute_initiative() -> Array[Unit]:
	# 살아 있는 유닛만 담을 배열.
	var alive: Array[Unit] = []
	# 모든 유닛을 확인한다.
	for unit in units:
		# 살아 있으면 담는다.
		if unit.is_alive():
			alive.append(unit)
	# 정렬 규칙 함수로 정렬한다.
	alive.sort_custom(_initiative_sorter)
	# 정렬된 순서를 돌려준다.
	return alive


## 행동 순서 정렬 규칙: a 가 b 보다 먼저 행동해야 하면 true.
func _initiative_sorter(a: Unit, b: Unit) -> bool:
	# 속도가 다르면 빠른 쪽이 먼저.
	if a.data.speed != b.data.speed:
		return a.data.speed > b.data.speed
	# 속도가 같으면 번호가 작은 쪽이 먼저 (결과가 항상 같게).
	return a.unit_id < b.unit_id


# 다음 아군 차례에서 멈춘다. 적 차례는 그 자리에서 해결하고 지나간다.
## 전투를 다음 입력 지점(아군 차례)까지 진행한다.
func _run_until_player_input() -> void:
	# 전투가 끝나면 반복을 멈춘다.
	while not finished:
		# 다음 유닛으로 넘어간다.
		turn_index += 1
		# 행동 순서 끝을 넘었으면 새 라운드를 시작하고 다시 반복한다.
		if turn_index >= initiative.size():
			_start_round()
			continue

		# 이번에 행동할 유닛.
		var actor: Unit = initiative[turn_index]
		# 라운드 도중에 쓰러진 유닛은 건너뛴다.
		if not actor.is_alive():
			continue

		# 방어도는 자기 차례가 시작될 때 사라진다 (한 바퀴 동안만 유지).
		actor.block = 0
		# 차례 시작 신호를 낸다.
		turn_started.emit(actor)

		# 아군이면 SP 를 채우고 카드를 뽑은 뒤, 플레이어 입력을 기다리러 빠져나간다.
		if actor.is_ally():
			# SP 를 최대치로 채운다.
			actor.sp = (actor.data as AllyData).max_sp
			# 정해진 장수를 뽑는다.
			_draw_cards(actor, DRAW_PER_TURN)
			# 여기서 멈춘다 — 다음 진행은 end_turn() 이 이어 간다.
			return

		# 적이면 AI 가 바로 행동한다.
		_take_enemy_turn(actor)
		# 적 공격으로 전투가 끝났는지 확인한다.
		check_end()


# Unit.draw 와 같은 순서로 한 장씩 진행하되, 화면이 순서대로 연출할 수 있게 매 단계 신호를 낸다.
## count 장을 뽑으면서 리셔플·드로우마다 신호를 낸다.
func _draw_cards(actor: Unit, count: int) -> void:
	# 정해진 장수만큼 반복한다.
	for _i in count:
		# 덱이 비었으면 먼저 채워야 한다.
		if actor.deck.is_empty():
			# 묘지도 비었으면 더 뽑을 카드가 없으므로 멈춘다.
			if actor.discard.is_empty():
				return
			# 묘지를 섞어 덱으로 만들고, 옮긴 장수로 리셔플 신호를 낸다.
			deck_reshuffled.emit(actor, actor.reshuffle_discard(rng))
		# 한 장 뽑는다.
		var card: CardData = actor.draw_one()
		# 뽑은 카드와 뽑은 뒤 덱·묘지 장수로 드로우 신호를 낸다.
		card_drawn.emit(actor, card, actor.deck.size(), actor.discard.size())


## 손패를 전부 묘지로 버리고 알린다.
func _discard_hand(actor: Unit) -> void:
	# 버리기 전에 손패 목록을 복사해 둔다 (버린 뒤에는 손패가 비므로).
	var cards: Array[CardData] = actor.hand.duplicate()
	# 손패를 묘지로 옮긴다.
	actor.discard_hand()
	# 버린 카드들과 버린 뒤 묘지 장수로 신호를 낸다.
	hand_discarded.emit(actor, cards, actor.discard.size())


## 적 한 명의 차례를 AI 에게 맡긴다.
func _take_enemy_turn(actor: Unit) -> void:
	# EnemyBrain 이 행동을 정하고 이 BattleState 의 통로로 적용한다.
	EnemyBrain.take_turn(self, actor)
