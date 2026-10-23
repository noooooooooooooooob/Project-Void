## 전투 한 판의 규칙과 상태를 모두 가진 핵심 객체.
## 노드가 아니라서 화면 없이도(테스트, 밸런스 시뮬레이션) 전투를 끝까지 돌릴 수 있다.
## 상태가 바뀔 때마다 신호를 내고, 화면(BattleEventRecorder → BattlePlayback)은 그 신호만 보고 연출한다.
##
## 흐름: start_battle() → (아군 차례에서 멈춤) → play_card()·move_unit() 여러 번 → end_turn() → (적 차례 자동 처리) → 다음 아군 차례에서 멈춤 ...
## 한 차례는 Phase 순서(스탠바이 → 드로우 → 턴 행동 → 종료 전 → 종료 후)로 진행하고, 아군은 턴 행동 단계에서 멈춘다.
class_name BattleState
# RefCounted: 노드가 아닌 가벼운 객체. 참조가 없어지면 자동으로 해제된다.
extends RefCounted

## 어떤 유닛의 차례가 시작됐다 (스탠바이 처리 직후 — 방어도 초기화·아군 SP 충전은 끝났고, 드로우는 아직 전).
signal turn_started(unit: Unit)
## 유닛이 공격을 받았다. amount 는 방어도로 막기 전의 공격 피해량, critical 은 치명타였는지.
signal unit_damaged(unit: Unit, amount: int, critical: bool)
## 유닛이 쓰러졌다 (unit_damaged 바로 뒤에 나간다).
signal unit_died(unit: Unit)
## 전투가 끝났다. ally_won 이 true 면 아군 승리.
signal battle_ended(ally_won: bool)
## 전투 로그에 한 줄을 남긴다.
signal log_message(text: String)
## 카드가 쓰였다. anchor 는 카드의 기준 유닛 (근접·자신은 자동으로 정해진 유닛). 실제로 맞는 유닛은
## resolver.units_in_area(anchor, card.area_offsets(), units) 로 다시 계산한다.
signal card_played(actor: Unit, card: CardData, anchor: Unit)
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
## 한 차례의 단계. 아군·적 모두 이 순서로 진행한다.
## STANDBY 스탠바이(block 초기화·SP 회복), DRAW 드로우, ACTION 턴 행동, BEFORE_END 종료 전, AFTER_END 종료 후(손패 버리기).
enum Phase { STANDBY, DRAW, ACTION, BEFORE_END, AFTER_END }
## 차례의 한 단계가 시작됐다. 단계 값을 바꾼 직후, 그 단계의 처리보다 먼저 나간다.
signal phase_started(unit: Unit, phase: Phase)
## 유닛이 이동했다 (여러 칸을 한 번에 갈 수도 있다).
signal unit_moved(unit: Unit, from_cell: Vector2i, to_cell: Vector2i)
## 흐트러짐 게이지가 0 이 되어 유닛이 무너졌다 (적은 기절, 아군은 탈진). 다음 차례를 쉰다.
signal unit_staggered(unit: Unit)
## 흐트러짐 게이지만 깎였다 (피해 없이 흐트러짐 효과만 받았을 때). amount 는 깎인 양.
signal stagger_damaged(unit: Unit, amount: int)
## 무너진 유닛이 차례를 쉬었다. 흐트러짐 게이지는 다시 가득 찬다.
signal turn_skipped(unit: Unit)
## 상태 스택이 바뀌었다. value 는 바뀐 뒤의 스택.
signal status_changed(unit: Unit, status_id: StringName, value: int)

## 아군 차례가 시작될 때마다 뽑는 카드 수.
const DRAW_PER_TURN: int = 4
## 상태·패시브 id: 혈갑. 패시브 혈갑을 가진 유닛은 차례가 시작될 때 혈갑 스택만큼 방어도를 얻는다.
const BLOOD_ARMOR: StringName = &"blood_armor"
## 패시브 id: 피의 갈망. 체력을 잃을 때마다 혈갑 +1, 적을 쓰러뜨리면 혈갑 +BLOOD_THIRST_KILL_STACKS.
const BLOOD_THIRST: StringName = &"blood_thirst"
## 혈갑 스택 최대치.
const BLOOD_ARMOR_MAX: int = 10
## 피의 갈망: 적을 쓰러뜨렸을 때 얻는 혈갑.
const BLOOD_THIRST_KILL_STACKS: int = 2
## 그 밖의 상태 스택 최대치.
const STATUS_MAX: int = 99

## 전장의 모든 유닛 (아군 먼저, 그다음 적군 순서로 들어 있다). 쓰러진 유닛도 남아 있다.
var units: Array[Unit] = []
## 기준 유닛·범위·이동 칸 계산기.
var resolver: TargetResolver
## 덱 섞기에 쓰는 난수 생성기. 시드를 고정하면 전투를 똑같이 재현할 수 있다.
var rng: RandomNumberGenerator
## 적 AI 전용 난수 생성기. 덱 섞기와 따로 써서, 적이 난수를 몇 번 쓰든 카드 순서가 바뀌지 않는다.
var ai_rng: RandomNumberGenerator
## 치명타 판정 전용 난수 생성기. 덱 섞기와 섞으면 같은 시드의 드로우 순서가 바뀌므로 따로 둔다.
var crit_rng: RandomNumberGenerator
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
## 지금 진행 중인 차례 단계.
var phase: Phase = Phase.STANDBY


## 전투 구성과 난수 생성기로 전투를 준비한다 (아직 시작하지는 않음).
func _init(encounter: EncounterData, p_rng: RandomNumberGenerator) -> void:
	# 난수 생성기를 기억한다.
	rng = p_rng
	# 적 AI 전용 난수 생성기를 만든다.
	ai_rng = RandomNumberGenerator.new()
	# 전투 시드에서 따로 뽑은 시드로 시작한다: 전투 시드가 같으면 적 행동도 같지만, 덱 섞기와 같은 수열을 되풀이하지 않는다.
	ai_rng.seed = hash([p_rng.seed, "enemy_ai"])
	# 치명 판정 전용 난수 생성기를 만든다.
	crit_rng = RandomNumberGenerator.new()
	# 전투 시드에서 따로 뽑은 시드 (전투 시드가 같으면 치명 결과도 같다).
	crit_rng.seed = hash([p_rng.seed, "crit"])
	# 양쪽 격자 크기로 대상 판정기를 만든다.
	resolver = TargetResolver.new(encounter.ally_grid, encounter.enemy_grid)

	# 유닛마다 붙일 번호. 0 부터 차례로 늘린다.
	var next_id: int = 0
	# 아군 배치 목록을 돌며 아군 유닛을 만든다.
	for placement in encounter.ally_units:
		# 배치 정보로 아군 유닛을 만든다.
		var ally := Unit.new(next_id, placement.unit_data, Unit.Team.ALLY, placement.cell)
		# 원정에서 이어진 체력이 있으면 그 체력으로 시작한다.
		if placement.start_hp > 0:
			ally.hp = mini(placement.start_hp, placement.unit_data.max_hp)
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
## 카드 공격과 적 공격 모두 이 함수를 거친다. source 는 공격한 유닛 (패시브 처리용, 없으면 null).
## 흐트러짐 게이지는 방어도로 막은 양까지 포함한 피해량만큼 깎인다.
func apply_damage(target: Unit, amount: int, critical: bool = false, source: Unit = null) -> void:
	# 맞기 전 체력 (체력을 잃었는지 판정용).
	var hp_before: int = target.hp
	# 방어도 → 체력 순서로 피해를 적용한다.
	target.take_damage(amount)
	# 흐트러짐 게이지를 깎는다 (피해 신호에 깎인 값이 함께 기록되도록 먼저).
	var broke: bool = _reduce_stagger(target, amount)
	# 피해 신호를 낸다.
	unit_damaged.emit(target, amount, critical)
	# 이번 피해로 체력이 0 이 됐는지 확인한다.
	if not target.is_alive():
		# 쓰러짐 신호를 낸다.
		unit_died.emit(target)
		# 로그에 남긴다.
		write_log("%s 쓰러짐" % target.data.display_name)
		# 피의 갈망: 적을 쓰러뜨리면 혈갑을 얻는다.
		if source != null and source.is_alive() and source.team != target.team and source.has_passive(BLOOD_THIRST):
			add_status(source, BLOOD_ARMOR, BLOOD_THIRST_KILL_STACKS)
		return
	# 피의 갈망: 체력을 잃었으면 혈갑 +1.
	if target.hp < hp_before and target.has_passive(BLOOD_THIRST):
		add_status(target, BLOOD_ARMOR, 1)
	# 게이지가 이번에 0 이 됐으면 무너짐을 알린다.
	if broke:
		_announce_break(target)


## 흐트러짐 게이지만 깎는다 (피해 없음).
func apply_stagger_damage(target: Unit, amount: int) -> void:
	# 쓰러졌거나 이미 무너진 유닛은 더 깎이지 않는다.
	if not target.is_alive() or target.broken:
		return
	# 깎기 전 값.
	var before: int = target.stagger
	# 깎는다.
	var broke: bool = _reduce_stagger(target, amount)
	# 깎인 양을 알린다.
	stagger_damaged.emit(target, before - target.stagger)
	# 0 이 됐으면 무너짐을 알린다.
	if broke:
		_announce_break(target)


## 체력을 amount 만큼 잃는다 (방어도·흐트러짐 무시, 1 아래로는 내려가지 않는다). 카드의 대가로 쓴다.
func apply_hp_cost(target: Unit, amount: int) -> void:
	# 실제로 잃는 양 (체력 1 은 남긴다).
	var lose: int = mini(amount, target.hp - 1)
	# 잃을 게 없으면 아무 일도 없다.
	if lose <= 0:
		return
	# 체력을 깎는다.
	target.hp -= lose
	# 피해처럼 알린다 (화면은 같은 연출을 쓴다).
	unit_damaged.emit(target, lose, false)
	# 피의 갈망: 체력을 잃었으니 혈갑 +1.
	if target.has_passive(BLOOD_THIRST):
		add_status(target, BLOOD_ARMOR, 1)


## 상태 스택을 delta 만큼 더한다 (최대치·0 에서 잘린다). 실제로 바뀌었으면 알린다.
func add_status(target: Unit, status_id: StringName, delta: int) -> void:
	# 지금 스택.
	var before: int = target.status(status_id)
	# 바뀐 뒤 스택.
	var after: int = clampi(before + delta, 0, status_cap(status_id))
	# 그대로면 알리지 않는다.
	if after == before:
		return
	# 바꾼다.
	target.set_status(status_id, after)
	# 알린다.
	status_changed.emit(target, status_id, after)


## 상태 스택 최대치.
static func status_cap(status_id: StringName) -> int:
	return BLOOD_ARMOR_MAX if status_id == BLOOD_ARMOR else STATUS_MAX


## 흐트러짐 게이지를 깎는다. 이번에 0 이 되어 무너졌으면 true.
func _reduce_stagger(target: Unit, amount: int) -> bool:
	# 쓰러졌거나 이미 무너졌으면 더 깎지 않는다.
	if not target.is_alive() or target.broken or amount <= 0:
		return false
	# 깎는다.
	target.stagger = maxi(0, target.stagger - amount)
	# 0 이 됐으면 무너진다.
	if target.stagger == 0:
		target.broken = true
		return true
	return false


## 무너짐을 신호와 로그로 알린다.
func _announce_break(target: Unit) -> void:
	# 신호.
	unit_staggered.emit(target)
	# 적은 기절, 아군은 탈진.
	write_log("%s %s" % [target.data.display_name, "탈진" if target.is_ally() else "기절"])


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


## 지금 차례인 아군이 손패의 hand_index 번째 카드를 anchor 를 기준으로 쓴다.
## anchor 는 resolver.valid_anchors 가 돌려준 후보 중 하나여야 한다 (근접·자신은 그 한 명).
## 규칙에 맞지 않으면 아무것도 바꾸지 않고 false 를 돌려준다. 성공하면 true.
func play_card(hand_index: int, anchor: Unit) -> bool:
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
	# 기준 유닛이 없거나 이 카드의 후보가 아니면 실패.
	if anchor == null or not resolver.valid_anchors(actor, card, units).has(anchor):
		return false

	# 여기부터는 검사를 모두 통과했으므로 상태를 바꾼다.
	# SP 를 비용만큼 쓴다.
	actor.sp -= card.sp_cost
	# 손패에서 카드를 뺀다.
	actor.hand.remove_at(hand_index)
	# 쓴 카드는 묘지로 간다.
	actor.discard.append(card)
	# 카드 사용 신호를 낸다 (효과 신호보다 먼저 나가야 화면이 돌진 → 피격 순으로 연출한다).
	card_played.emit(actor, card, anchor)
	# 로그에 "사용자 → 기준 유닛 (카드)" 형식으로 남긴다.
	write_log("%s → %s (%s)" % [actor.data.display_name, anchor.data.display_name, card.display_name])
	# 효과를 적용한다.
	resolve_card(actor, card, anchor)

	# 이번 카드로 전투가 끝났는지 확인한다.
	check_end()
	# 성공.
	return true


## 카드 효과를 순서대로 적용한다. 아군 카드(play_card)와 적 행동(EnemyBrain)이 함께 쓴다.
## AREA 효과의 대상은 효과마다 다시 계산하므로 앞 효과로 쓰러진 유닛은 뒤 효과에서 빠진다.
func resolve_card(actor: Unit, card: CardData, anchor: Unit) -> void:
	# 사용자의 스탯.
	var stats: UnitData = actor.data
	# 효과마다.
	for effect in card.effects:
		# 수치.
		var amount: int = CardMath.amount(effect, stats)
		# 0 이면 적용하지 않는다.
		if amount <= 0:
			continue
		# 폭발: 사용자의 상태 스택을 한 번만 모두 소모하고, 스택 수를 곱한 피해를 준다. 스택이 없으면 아무 일도 없다.
		if effect.kind == CardEffect.Kind.BURST:
			var stacks: int = actor.status(effect.status)
			if stacks <= 0:
				continue
			add_status(actor, effect.status, -stacks)
			amount *= stacks
		# 대상 목록: 자신이면 사용자, 아니면 기준 유닛의 범위.
		var targets: Array[Unit] = []
		if effect.target == CardEffect.Target.SELF:
			targets.append(actor)
		else:
			targets = resolver.units_in_area(anchor, card.area_offsets(), units)
		# 대상마다 종류에 맞게 적용한다.
		for target in targets:
			match effect.kind:
				# 피해·폭발: 맞는 유닛마다 치명 판정.
				CardEffect.Kind.DAMAGE, CardEffect.Kind.BURST:
					var critical: bool = CardMath.rolls_crit(stats, crit_rng)
					apply_damage(target, CardMath.critical_amount(amount, stats) if critical else amount, critical, actor)
				# 방어도.
				CardEffect.Kind.BLOCK:
					apply_block(target, amount)
				# 회복.
				CardEffect.Kind.HEAL:
					apply_heal(target, amount)
				# 상태 스택 획득.
				CardEffect.Kind.GAIN_STATUS:
					add_status(target, effect.status, amount)
				# 체력 소모.
				CardEffect.Kind.HP_COST:
					apply_hp_cost(target, amount)
				# 흐트러짐만.
				CardEffect.Kind.STAGGER:
					apply_stagger_damage(target, amount)


## 지금 차례인 아군이 이동력을 써서 to_cell 로 이동한다. 걸음 수(상하좌우 한 칸 = 1)만큼 이동력이 준다.
## 규칙에 맞지 않으면 아무것도 바꾸지 않고 false 를 돌려준다. 성공하면 true.
func move_unit(to_cell: Vector2i) -> bool:
	# 끝난 전투에서는 이동할 수 없다.
	if finished:
		return false
	# 지금 차례인 유닛.
	var actor: Unit = current_unit()
	# 차례 유닛이 없거나, 적이거나, 쓰러졌으면 이동할 수 없다.
	if actor == null or not actor.is_ally() or not actor.is_alive():
		return false
	# 이동력이 없으면 이동할 수 없다.
	if actor.move_points < 1:
		return false
	# 남은 이동력으로 갈 수 있는 칸과 걸음 수.
	var reach: Dictionary = resolver.reachable_cells(actor, units, actor.move_points)
	# 닿지 않는 칸이면 이동할 수 없다.
	if not reach.has(to_cell):
		return false
	# 걸음 수만큼 이동력을 쓴다.
	actor.move_points -= int(reach[to_cell])
	# 옮기고 알린다.
	apply_move(actor, to_cell)
	# 성공.
	return true


## 검사 없이 유닛을 to_cell 로 옮기고 알린다 (아군 move_unit 과 EnemyBrain 이 부르는 통로).
func apply_move(unit: Unit, to_cell: Vector2i) -> void:
	# 원래 칸을 기억한다.
	var from_cell: Vector2i = unit.cell
	# 칸을 바꾼다.
	unit.cell = to_cell
	# 이동 신호를 낸다.
	unit_moved.emit(unit, from_cell, to_cell)
	# 로그에 남긴다.
	write_log("%s 이동" % unit.data.display_name)


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


## 지금 차례인 아군의 차례를 끝낸다. 종료 전 → 종료 후(손패 버리기) 단계를 지나 다음 아군 차례까지 진행한다.
func end_turn() -> void:
	# 지금 차례인 유닛을 가져온다.
	var actor: Unit = current_unit()
	# 아군 차례였다면 종료 단계들을 진행한다.
	if actor != null and actor.is_ally():
		# 종료 전 → 종료 후. 손패는 종료 후 단계에서 버린다.
		_end_phases(actor)
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
## 전투를 다음 입력 지점(아군의 턴 행동 단계)까지 진행한다.
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
		# 무너진(기절·탈진) 유닛은 이번 차례를 쉬고 게이지를 되찾는다.
		if actor.broken:
			_skip_turn(actor)
			continue

		# 스탠바이 → 차례 시작 알림 → 드로우.
		_start_phases(actor)
		# 턴 행동 단계로 들어간다.
		_enter_phase(actor, Phase.ACTION)

		# 아군이면 여기서 멈추고 플레이어 입력을 기다린다 — 다음 진행은 end_turn() 이 이어 간다.
		if actor.is_ally():
			return

		# 적이면 AI 가 바로 행동한다.
		_take_enemy_turn(actor)
		# 적 행동으로 전투가 끝났는지 확인한다.
		check_end()
		# 전투가 끝났으면 남은 단계는 진행하지 않는다.
		if finished:
			return
		# 종료 전 → 종료 후.
		_end_phases(actor)


## 현재 단계를 바꾸고 단계 시작 신호를 낸다.
func _enter_phase(actor: Unit, next_phase: Phase) -> void:
	# 현재 단계를 바꾼다.
	phase = next_phase
	# 단계 시작 신호를 낸다 (그 단계의 처리보다 먼저).
	phase_started.emit(actor, next_phase)


## 스탠바이(block 초기화·SP 회복) → 차례 시작 알림 → 드로우 단계를 진행한다.
func _start_phases(actor: Unit) -> void:
	# 스탠바이 단계.
	_enter_phase(actor, Phase.STANDBY)
	# 방어도는 자기 차례가 시작될 때 사라진다 (한 바퀴 동안만 유지).
	actor.block = 0
	# 이동력을 채운다.
	actor.move_points = actor.data.move
	# 아군이면 SP 를 최대치로 채운다.
	if actor.is_ally():
		actor.sp = (actor.data as AllyData).max_sp
	# 초기화된 값이 기록되도록 스탠바이 처리 뒤에 차례 시작을 알린다.
	turn_started.emit(actor)
	# 혈갑 패시브: 혈갑 스택만큼 방어도를 얻는다.
	if actor.has_passive(BLOOD_ARMOR) and actor.status(BLOOD_ARMOR) > 0:
		apply_block(actor, actor.status(BLOOD_ARMOR))
	# 드로우 단계.
	_enter_phase(actor, Phase.DRAW)
	# 아군만 카드를 뽑는다 (적은 덱이 없어 단계만 지나간다).
	if actor.is_ally():
		_draw_cards(actor, DRAW_PER_TURN)


## 무너진 유닛의 차례: 스탠바이만 지나고 행동 없이 쉰 뒤, 흐트러짐 게이지를 가득 채운다.
func _skip_turn(actor: Unit) -> void:
	# 스탠바이 단계.
	_enter_phase(actor, Phase.STANDBY)
	# 방어도는 평소처럼 사라진다.
	actor.block = 0
	# 쉬는 차례에는 움직일 수 없다.
	actor.move_points = 0
	# 차례 시작을 알린다 (행동 순서 표시용).
	turn_started.emit(actor)
	# 무너짐에서 회복한다.
	actor.broken = false
	actor.stagger = actor.data.stagger
	# 쉬었다고 알린다.
	turn_skipped.emit(actor)
	write_log("%s 차례를 쉰다" % actor.data.display_name)
	# 종료 단계.
	_end_phases(actor)


## 종료 전 → 종료 후 단계를 진행한다. 아군은 종료 후 단계에서 손패를 버린다.
func _end_phases(actor: Unit) -> void:
	# 종료 전 단계 (지금은 처리할 일이 없다).
	_enter_phase(actor, Phase.BEFORE_END)
	# 종료 후 단계.
	_enter_phase(actor, Phase.AFTER_END)
	# 아군이면 남은 손패를 묘지로 버린다.
	if actor.is_ally():
		_discard_hand(actor)


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
