## 적 유닛의 행동을 정하고 실행하는 간단한 AI.
## 상태를 직접 바꾸지 않고, BattleState 의 resolve_card / report_* 통로를 불러서 신호가 빠짐없이 나가게 한다.
## 공격·방어·휴식은 EnemyData 의 카드로 정의되고, 아군 카드와 같은 규칙(BattleState.resolve_card)으로 적용된다.
class_name EnemyBrain
# RefCounted: 노드가 아닌 가벼운 객체. 모든 함수가 static 이라 객체를 만들 필요는 없다.
extends RefCounted

## 적이 할 수 있는 행동. ATTACK 공격, DEFEND 방어 카드, REST 휴식 카드, MOVE 한 칸 이동, WAIT 할 행동이 없어 차례를 넘김.
enum Action { ATTACK, DEFEND, REST, MOVE, WAIT }

## 체력 비율이 이 값 이하로 떨어지면 휴식을 고른다 (0.3 = 30%).
const REST_THRESHOLD: float = 0.3


## 이번 차례에 어떤 행동을 할지 정한다.
## 먼저 move_chance 확률로 이동을 고른다 (갈 칸이 없으면 쓸 수 있는 행동 중 무작위).
## 이동을 고르지 않으면 우선순위: 체력이 낮고 휴식 카드가 있으면 휴식 → 칠 대상이 없으면 방어(방어 카드도 없으면 대기) → 그 외에는 공격.
## 확률 판정에 적 전용 난수를 쓰므로, 같은 상황에서 여러 번 부르면 결과가 달라질 수 있다.
static func decide(state: BattleState, actor: Unit) -> Action:
	# 적 전용 수치를 읽기 위해 EnemyData 로 형 변환한다.
	var data: EnemyData = actor.data as EnemyData
	# 이동 확률이 있으면 먼저 판정한다 (0 이면 난수를 쓰지 않아 결과가 결정론적이다).
	if data.move_chance > 0.0 and state.ai_rng.randf() < data.move_chance:
		# 갈 칸이 있으면 이동한다.
		if not state.resolver.movable_cells(actor, state.units).is_empty():
			return Action.MOVE
		# 막혔으면 쓸 수 있는 행동 중 무작위로 고른다.
		return _random_fallback(state, actor)
	# 현재 체력 / 최대 체력 비율을 소수로 구한다.
	var hp_ratio: float = float(actor.hp) / float(data.max_hp)
	# 체력이 문턱 이하이고 휴식 카드가 있으면 휴식한다.
	if hp_ratio <= REST_THRESHOLD and data.rest_card != null:
		return Action.REST
	# 칠 수 있는 대상이 없으면 방어한다 (방어 카드도 없으면 대기).
	if find_target(state, actor) == null:
		return Action.DEFEND if data.defend_card != null else Action.WAIT
	# 그 외에는 공격한다.
	return Action.ATTACK


## 이동하려 했지만 막혔을 때: 쓸 수 있는 행동(공격은 대상이 있을 때만, 방어·휴식은 카드가 있을 때만) 중 하나를 고른다. 없으면 대기.
static func _random_fallback(state: BattleState, actor: Unit) -> Action:
	# 적 데이터.
	var data: EnemyData = actor.data as EnemyData
	# 후보 행동 목록.
	var choices: Array[Action] = []
	# 칠 대상이 있을 때만 공격.
	if find_target(state, actor) != null:
		choices.append(Action.ATTACK)
	# 방어 카드가 있을 때만 방어.
	if data.defend_card != null:
		choices.append(Action.DEFEND)
	# 휴식 카드가 있을 때만 휴식.
	if data.rest_card != null:
		choices.append(Action.REST)
	# 아무것도 없으면 대기.
	if choices.is_empty():
		return Action.WAIT
	# 하나를 무작위로 고른다.
	return choices[state.ai_rng.randi_range(0, choices.size() - 1)]


## 이 적의 공격 카드로 칠 수 있는 대상 중 가장 좋은 대상. 공격 카드가 없거나 후보가 없으면 null.
## 기준: 체력이 가장 낮은 유닛, 같으면 unit_id 가 작은 유닛 (결과가 항상 같게).
static func find_target(state: BattleState, actor: Unit) -> Unit:
	# 적 데이터.
	var data: EnemyData = actor.data as EnemyData
	# 공격 카드가 없으면 대상도 없다.
	if data.attack_card == null:
		return null
	# 지금까지 찾은 가장 좋은 대상.
	var best: Unit = null
	# 카드의 기준 후보마다.
	for candidate in state.resolver.valid_anchors(actor, data.attack_card, state.units):
		# 첫 후보이거나, 체력이 더 낮거나, 같으면 번호가 작으면 바꾼다.
		if best == null or candidate.hp < best.hp or (candidate.hp == best.hp and candidate.unit_id < best.unit_id):
			best = candidate
	# 찾은 대상 (없으면 null).
	return best


## 적 한 명의 차례를 처리한다: 행동을 정하고, 알리고, 적용하고, 로그를 남긴다.
static func take_turn(state: BattleState, actor: Unit) -> void:
	# 적 전용 수치를 읽기 위해 형 변환한다.
	var data: EnemyData = actor.data as EnemyData

	# 정한 행동에 따라 나눠 처리한다.
	match decide(state, actor):
		# 휴식: 휴식 카드를 자신에게 쓴다.
		Action.REST:
			# 화면이 행동 연출을 먼저 보여 줄 수 있게 행동을 알린다.
			state.report_enemy_action(actor, Action.REST, null)
			# 카드 효과를 적용한다 (unit_healed 신호가 나간다).
			state.resolve_card(actor, data.rest_card, actor)
			# 전투 로그에 남긴다.
			state.write_log("%s 휴식" % data.display_name)
		# 방어: 방어 카드를 자신에게 쓴다.
		Action.DEFEND:
			# 행동을 알린다.
			state.report_enemy_action(actor, Action.DEFEND, null)
			# 카드 효과를 적용한다 (block_gained 신호가 나간다).
			state.resolve_card(actor, data.defend_card, actor)
			# 전투 로그에 남긴다.
			state.write_log("%s 방어" % data.display_name)
		# 공격: 대상을 기준으로 공격 카드를 쓴다.
		Action.ATTACK:
			# decide 에서 확인했지만 다시 대상을 구한다.
			var target: Unit = find_target(state, actor)
			# 혹시 대상이 없으면 아무것도 하지 않는다 (안전장치).
			if target == null:
				return
			# 누구를 공격하는지 알린다 (화면의 돌진 연출용).
			state.report_enemy_action(actor, Action.ATTACK, target)
			# 전투 로그에 남긴다.
			state.write_log("%s → %s 공격" % [data.display_name, target.data.display_name])
			# 카드 효과를 적용한다 (범위 안의 유닛마다 피해 신호가 나간다).
			state.resolve_card(actor, data.attack_card, target)
		# 이동: 갈 수 있는 칸 중 하나로 옮긴다.
		Action.MOVE:
			# 갈 수 있는 칸들.
			var cells: Array[Vector2i] = state.resolver.movable_cells(actor, state.units)
			# 칸이 없으면 아무것도 하지 않는다 (안전장치).
			if cells.is_empty():
				return
			# 적 전용 난수로 한 칸을 고른다.
			var cell: Vector2i = cells[state.ai_rng.randi_range(0, cells.size() - 1)]
			# 이동 행동을 알린다 (화면은 뒤따르는 이동 이벤트로 연출한다).
			state.report_enemy_action(actor, Action.MOVE, null)
			# 옮기고 알린다 (unit_moved 신호와 로그가 나간다).
			state.apply_move(actor, cell)
		# 대기: 할 행동이 없다.
		Action.WAIT:
			# 행동을 알린다.
			state.report_enemy_action(actor, Action.WAIT, null)
			# 전투 로그에 남긴다.
			state.write_log("%s 대기" % data.display_name)
