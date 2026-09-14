## 적 유닛의 행동을 정하고 실행하는 간단한 AI.
## 상태를 직접 바꾸지 않고, BattleState 의 apply_* / report_* 통로를 불러서 신호가 빠짐없이 나가게 한다.
class_name EnemyBrain
# RefCounted: 노드가 아닌 가벼운 객체. 모든 함수가 static 이라 객체를 만들 필요는 없다.
extends RefCounted

## 적이 할 수 있는 행동. ATTACK 공격, DEFEND 방어도 얻기, REST 체력 회복, MOVE 한 칸 이동.
enum Action { ATTACK, DEFEND, REST, MOVE }

## 체력 비율이 이 값 이하로 떨어지면 휴식을 고른다 (0.3 = 30%).
const REST_THRESHOLD: float = 0.3


## 이번 차례에 어떤 행동을 할지 정한다.
## 먼저 move_chance 확률로 이동을 고른다 (갈 칸이 없으면 공격·방어·휴식 중 무작위).
## 이동을 고르지 않으면 우선순위: 체력이 낮으면 휴식 → 칠 대상이 없으면 방어 → 그 외에는 공격.
## 확률 판정에 적 전용 난수를 쓰므로, 같은 상황에서 여러 번 부르면 결과가 달라질 수 있다.
static func decide(state: BattleState, actor: Unit) -> Action:
	# 적 전용 수치를 읽기 위해 EnemyData 로 형 변환한다.
	var data: EnemyData = actor.data as EnemyData
	# 이동 확률이 있으면 먼저 판정한다 (0 이면 난수를 쓰지 않아 결과가 결정론적이다).
	if data.move_chance > 0.0 and state.ai_rng.randf() < data.move_chance:
		# 갈 칸이 있으면 이동한다.
		if not state.resolver.movable_cells(actor, state.units).is_empty():
			return Action.MOVE
		# 막혔으면 공격·방어·휴식 중 무작위로 고른다.
		return _random_fallback(state, actor)
	# 현재 체력 / 최대 체력 비율을 소수로 구한다.
	var hp_ratio: float = float(actor.hp) / float(data.max_hp)
	# 체력이 문턱 이하이고 회복량이 있는 적이면 휴식한다.
	if hp_ratio <= REST_THRESHOLD and data.rest_heal > 0:
		return Action.REST
	# 칠 수 있는 대상이 하나도 없으면 방어한다.
	if find_target(state, actor) == null:
		return Action.DEFEND
	# 그 외에는 공격한다.
	return Action.ATTACK


## 이동하려 했지만 막혔을 때: 공격(칠 대상이 있을 때만)·방어·휴식 중 하나를 적 전용 난수로 고른다.
static func _random_fallback(state: BattleState, actor: Unit) -> Action:
	# 후보 행동 목록.
	var choices: Array[Action] = []
	# 칠 대상이 있을 때만 공격을 후보에 넣는다.
	if find_target(state, actor) != null:
		choices.append(Action.ATTACK)
	# 방어는 항상 후보.
	choices.append(Action.DEFEND)
	# 휴식도 항상 후보.
	choices.append(Action.REST)
	# 하나를 무작위로 고른다.
	return choices[state.ai_rng.randi_range(0, choices.size() - 1)]


## 이 적이 칠 수 있는 대상 중 가장 좋은 대상을 고른다. 없으면 null.
## 기준: 체력이 가장 낮은 유닛, 체력이 같으면 unit_id 가 작은 유닛 (결과가 항상 같게).
static func find_target(state: BattleState, actor: Unit) -> Unit:
	# 적의 공격 방식·사거리를 읽기 위해 형 변환한다.
	var data: EnemyData = actor.data as EnemyData
	# 지금까지 찾은 가장 좋은 대상.
	var best: Unit = null
	# 전장의 모든 유닛을 후보로 본다.
	for candidate in state.units:
		# 칠 수 없는 후보(같은 편, 쓰러짐, 사거리 밖, 근접 막힘)는 건너뛴다.
		if not state.resolver.is_valid_target(actor, candidate, data.attack_type, data.attack_range, state.units):
			continue
		# 첫 번째 유효 후보는 일단 최선으로 둔다.
		if best == null:
			best = candidate
		# 체력이 더 낮으면 새 최선이다.
		elif candidate.hp < best.hp:
			best = candidate
		# 체력이 같으면 번호가 작은 쪽을 고른다.
		elif candidate.hp == best.hp and candidate.unit_id < best.unit_id:
			best = candidate
	# 찾은 대상을 돌려준다 (없으면 null).
	return best


## 적 한 명의 차례를 처리한다: 행동을 정하고, 알리고, 적용하고, 로그를 남긴다.
static func take_turn(state: BattleState, actor: Unit) -> void:
	# 적 전용 수치를 읽기 위해 형 변환한다.
	var data: EnemyData = actor.data as EnemyData

	# 정한 행동에 따라 나눠 처리한다.
	match decide(state, actor):
		# 휴식: 체력을 회복한다.
		Action.REST:
			# 화면이 행동 연출을 먼저 보여 줄 수 있게 행동을 알린다.
			state.report_enemy_action(actor, Action.REST, null)
			# 회복을 적용한다 (unit_healed 신호가 나간다).
			state.apply_heal(actor, data.rest_heal)
			# 전투 로그에 남긴다.
			state.write_log("%s 휴식" % data.display_name)
		# 방어: 방어도를 얻는다.
		Action.DEFEND:
			# 행동을 알린다.
			state.report_enemy_action(actor, Action.DEFEND, null)
			# 방어도를 적용한다 (block_gained 신호가 나간다).
			state.apply_block(actor, data.block_amount)
			# 전투 로그에 남긴다.
			state.write_log("%s 방어" % data.display_name)
		# 공격: 대상을 골라 범위 안의 유닛들에게 피해를 준다.
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
			# 범위 모양에 따라 맞는 유닛마다 피해를 준다.
			for victim in state.resolver.expand_shape(target, data.attack_shape, state.units):
				state.apply_damage(victim, data.attack_damage)
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
