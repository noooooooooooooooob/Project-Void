## 기록된 BattleEvent 들을 하나씩 순서대로 화면에 연출하는 노드.
## 이벤트 하나의 연출(돌진, 피격 번쩍임, 카드 드로우 등)이 끝날 때까지 await 로 기다린 뒤 다음으로 넘어간다.
## 3D 보드(Board3D)와 HUD(BattleHud)를 BattleRoot 가 넣어 준다.
class_name BattlePlayback
# Node: 씬 트리에 붙어야 타이머(get_tree().create_timer)를 쓸 수 있다.
extends Node

## play() 가 모든 이벤트를 재생하고 끝났을 때.
signal finished
# 코루틴 호출 결과를 배열에 담아 나중에 await 하는 방식은 GDScript 정적 분석에 걸린다.
# 그 대신 신호 + 남은 수 세기로 "여럿을 동시에 시작하고 모두 끝나길 기다리기"를 구현한다.
## (내부용) 광역 공격으로 여러 유닛이 동시에 맞을 때, 그중 한 유닛의 재생이 끝날 때마다 낸다.
signal _damage_batch_unit_finished
## (내부용) 공격자의 돌진이 끝났을 때.
signal _lunge_finished

## 적 차례가 시작될 때 잠깐 쉬는 시간 (누구 차례인지 눈에 들어오게).
const ENEMY_TURN_PAUSE: float = 0.2
## 피해 연출 한 번에 쓰는 전체 시간 (번쩍임 포함).
const DAMAGE_TIME: float = 0.5
## 회복·방어도 숫자가 떠오르는 동안 기다리는 시간.
const STAT_POP_TIME: float = 0.4
## 피해 숫자 색 (붉은색).
const DAMAGE_COLOR := Color(1.0, 0.35, 0.3)
## 회복 숫자 색 (초록색).
const HEAL_COLOR := Color(0.45, 0.9, 0.45)
## 방어도 숫자 색 (푸른색).
const BLOCK_COLOR := Color(0.5, 0.7, 1.0)
## 카드 한 장을 뽑은 뒤 다음 장까지 기다리는 시간 (비행이 겹쳐 보이게 짧게).
const DRAW_WAIT: float = 0.12
## 리셔플 연출(묘지에서 덱으로 날아가는 뒷면들)을 기다리는 시간.
const RESHUFFLE_WAIT: float = 0.45
## 손패가 묘지로 날아가는 연출을 기다리는 시간.
const DISCARD_WAIT: float = 0.35
## 쓴 카드가 손패에서 사라진 뒤 돌진 연출 전까지 기다리는 시간.
const PLAY_REMOVE_WAIT: float = 0.2
## 피해 순간 히트스톱 길이 (실제 초).
const HIT_STOP_TIME: float = 0.06
## 처치 순간 히트스톱 길이 (실제 초).
const KILL_HIT_STOP_TIME: float = 0.1
## 넉백 최대 거리.
const MAX_KNOCKBACK: float = 0.35
## 원거리는 앞으로 나가지 않고 쏘는 순간 살짝 뒤로 물러난다.
const RANGED_RECOIL: float = -0.1
## 이 이상 피해면 화면 펄스를 약하게 준다.
const BIG_HIT_DAMAGE: int = 8
# 큰 타격 펄스 세기.
const _BIG_HIT_PULSE: float = 0.5

## 유닛·타일을 보여 주는 3D 보드.
var board: Board3D
## 손패·더미·로그·SP 를 보여 주는 HUD.
var hud: BattleHud
# 테스트용. 트윈과 대기를 건너뛰고 표시값만 반영해서 play() 가 동기로 끝난다.
## true 면 연출 없이 최종 표시값만 즉시 반영한다.
var instant: bool = false
## 카메라 연출 (없으면 카메라 연출 없이 재생).
var camera_fx: BattleCamera
## 효과음 재생기 (없으면 소리 없이 재생).
var audio: BattleAudio
## 화면 펄스 (없으면 펄스 없이 재생).
var screen_fx: ScreenPulse
## 원거리 화살 그림 (없으면 흰 줄).
var projectile_texture: Texture2D

# 지금 재생 중인 타격 묶음을 만든 공격의 종류. 공격 없이 나온 피해는 근접으로 친다.
var _impact_type: CardData.AttackType = CardData.AttackType.MELEE
# 타격 묶음을 만든 공격자의 자리 (넉백 방향). _has_impact_origin 이 false 면 넉백하지 않는다.
var _impact_origin: Vector3 = Vector3.ZERO
var _has_impact_origin: bool = false


## 이벤트 목록을 앞에서부터 하나씩 재생한다. 호출하는 쪽은 await 로 끝날 때까지 기다린다.
func play(events: Array[BattleEvent]) -> void:
	# 다음에 볼 이벤트 번호 (묶음으로 처리한 만큼 한 번에 건너뛸 수 있어 for 대신 while 을 쓴다).
	var i: int = 0
	while i < events.size():
		# 이번 이벤트.
		var event: BattleEvent = events[i]
		# 피해·쓰러짐은 이어지는 만큼 모아 동시에 재생한다 (광역 공격이 한꺼번에 보이게).
		if _is_damage(event.kind):
			var batch: Array[BattleEvent] = []
			while i < events.size() and _is_damage(events[i].kind):
				batch.append(events[i])
				i += 1
			await _play_damage_batch(batch)
			_release_camera()
			continue
		# 돌진한 공격의 결과가 아니면 구도를 되돌린다.
		if not keeps_camera_push(event.kind):
			_release_camera()
		match event.kind:
			# 차례 시작: 현재 유닛 표시·순서 바 갱신.
			BattleEvent.Kind.TURN_STARTED:
				await _turn_started(event)
			# 카드 사용·적 행동: 뒤따르는 피해가 있으면 무기가 닿는 순간에 그 피해를 재생한다.
			BattleEvent.Kind.CARD_PLAYED, BattleEvent.Kind.ENEMY_ACTED:
				var impact: int = impact_start(events, i) if not instant and _is_attack(event) else -1
				# 피해가 없으면(빗나감·방어·휴식) 돌진·깡충만.
				if impact < 0:
					var no_hits: Array[BattleEvent] = []
					if event.kind == BattleEvent.Kind.CARD_PLAYED:
						await _card_played(event, no_hits, no_hits)
					else:
						await _enemy_acted(event, no_hits, no_hits)
				else:
					# 타격 묶음의 끝.
					var end: int = impact
					while end < events.size() and _is_damage(events[end].kind):
						end += 1
					# 사이의 로그와 타격 묶음.
					var logs: Array[BattleEvent] = events.slice(i + 1, impact)
					var hits: Array[BattleEvent] = events.slice(impact, end)
					if event.kind == BattleEvent.Kind.CARD_PLAYED:
						await _card_played(event, logs, hits)
					else:
						await _enemy_acted(event, logs, hits)
					_release_camera()
					# 묶음 끝 다음 이벤트로.
					i = end
					continue
			# 회복: 체력 바 갱신·숫자.
			BattleEvent.Kind.HEALED:
				await _healed(event)
			# 방어도: 방어도 표시·숫자.
			BattleEvent.Kind.BLOCK_GAINED:
				await _block_gained(event)
			# 로그: 기다림 없이 한 줄 추가.
			BattleEvent.Kind.LOG:
				hud.append_log(event.text)
			# 전투 종료: 승패 배너와 로그.
			BattleEvent.Kind.BATTLE_ENDED:
				hud.show_banner(event.ally_won)
				hud.append_log("전투 종료 — %s" % ("승리" if event.ally_won else "패배"))
			# 드로우.
			BattleEvent.Kind.CARD_DRAWN:
				hud.draw_card(event)
				await _wait(DRAW_WAIT)
			# 리셔플.
			BattleEvent.Kind.DECK_RESHUFFLED:
				hud.reshuffle(event)
				await _wait(RESHUFFLE_WAIT)
			# 손패 버리기.
			BattleEvent.Kind.HAND_DISCARDED:
				hud.discard_hand(event)
				await _wait(DISCARD_WAIT)
			# 이동.
			BattleEvent.Kind.UNIT_MOVED:
				await _unit_moved(event)
		# 다음 이벤트로.
		i += 1
	# 남은 푸시를 푼다.
	_release_camera()
	# 모든 이벤트를 재생했음을 알린다.
	finished.emit()


## 공격 이벤트 뒤(로그는 건너뜀)에 이어지는 피해·사망 묶음의 첫 인덱스. 다른 이벤트가 끼거나 없으면 −1.
static func impact_start(events: Array[BattleEvent], attack_index: int) -> int:
	for i in range(attack_index + 1, events.size()):
		var kind: BattleEvent.Kind = events[i].kind
		# 피해·사망이면 여기.
		if kind == BattleEvent.Kind.DAMAGED or kind == BattleEvent.Kind.DIED:
			return i
		# 로그 말고 다른 것이 끼면 이 공격의 결과가 아니다.
		if kind != BattleEvent.Kind.LOG:
			return -1
	# 없음.
	return -1


## 피해량에 비례해 밀리는 거리. 막힌(0) 공격은 밀지 않는다.
static func knockback_distance(amount: int) -> float:
	return 0.0 if amount <= 0 else minf(0.1 + 0.03 * amount, MAX_KNOCKBACK)


## 돌진한 공격의 결과(피해·사망과 그 사이 로그)만 푸시인을 유지한다.
static func keeps_camera_push(kind: BattleEvent.Kind) -> bool:
	return kind == BattleEvent.Kind.DAMAGED or kind == BattleEvent.Kind.DIED or kind == BattleEvent.Kind.LOG


## 원거리 발사음은 화살이 나가는 순간에 낸다. 근접 휘두르기는 예비동작부터 들려야 타격을 이끈다.
static func attack_sound_at_strike(type: CardData.AttackType) -> bool:
	return type == CardData.AttackType.RANGED


# 피해·사망 이벤트인지.
static func _is_damage(kind: BattleEvent.Kind) -> bool:
	return kind == BattleEvent.Kind.DAMAGED or kind == BattleEvent.Kind.DIED


# 대상이 있는 공격인지 (카드 사용, 또는 대상 있는 적 공격).
static func _is_attack(event: BattleEvent) -> bool:
	return event.kind == BattleEvent.Kind.CARD_PLAYED or (event.action == EnemyBrain.Action.ATTACK and event.target != null)


# 연출 부품이 쓸 수 있는지 (instant 면 모두 끈다).
func _has_camera() -> bool:
	return camera_fx != null and not instant


func _has_audio() -> bool:
	return audio != null and audio.sounds != null and not instant


func _has_pulse() -> bool:
	return screen_fx != null and not instant


# 카메라 푸시를 푼다.
func _release_camera() -> void:
	if _has_camera():
		camera_fx.release()


# 맞은 유닛을 공격자 반대 방향(바닥 평면)으로 밀 변위. 공격자를 모르면 0.
func _knockback(view: UnitView, amount: int) -> Vector3:
	if not _has_impact_origin:
		return Vector3.ZERO
	var away: Vector3 = view.home_position - _impact_origin
	away.y = 0.0
	return away.normalized() * knockback_distance(amount) if away.length_squared() > 0.0 else Vector3.ZERO


# 같은 유닛이 한 묶음 안에서 두 번 나올 일은 지금 규칙상 없지만(한 칸은 한 공격에 한 번만 맞는다),
# 있더라도 그 유닛 안에서는 순서가 흐트러지지 않도록 유닛별로 따로 코루틴을 돌린다.
## 같은 순간(한 번의 공격)에 겹치는 피해·쓰러짐 기록들을 유닛별로 나눠 모두 동시에 재생한다.
func _play_damage_batch(batch: Array[BattleEvent]) -> void:
	# 유닛 → 그 유닛의 기록들(원래 순서 유지).
	var by_unit: Dictionary = {}
	# 묶음을 유닛별로 나눈다.
	for event in batch:
		# 이 유닛의 기록 목록이 아직 없으면 새로 만들어 등록한다.
		if not by_unit.has(event.unit):
			var new_list: Array[BattleEvent] = []
			by_unit[event.unit] = new_list
		# 이 유닛의 기록 목록을 꺼내 이번 기록을 더한다 (사전이 들고 있는 배열 자체를 바꾸므로 다시 넣을 필요는 없다).
		var unit_events: Array[BattleEvent] = by_unit[event.unit]
		unit_events.append(event)

	# 배열 한 칸짜리 상자에 남은 유닛 수를 담는다 (GDScript 지역 변수는 코루틴끼리 참조로 공유되지 않으므로 상자로 감싼다).
	var remaining: Array[int] = [by_unit.size()]
	# 유닛마다 재생을 시작한다. await 로 결과를 받지 않고 그냥 불러 둔다 — 끝나면 스스로 remaining 을 줄이고 신호를 낸다.
	for unit in by_unit:
		# 이 유닛의 기록 목록.
		var unit_events: Array[BattleEvent] = by_unit[unit]
		_play_unit_damage(unit_events, remaining)
	# 남은 수가 0 이 될 때까지 기다린다. 연출 없이(instant) 이미 다 끝났으면 조건이 곧장 거짓이라 기다리지 않는다.
	while remaining[0] > 0:
		await _damage_batch_unit_finished


## 한 유닛의 피해·쓰러짐 기록들을 그 유닛 안에서만 순서대로 재생한다. 다 끝나면 remaining 을 줄이고 신호를 낸다.
func _play_unit_damage(unit_events: Array[BattleEvent], remaining: Array[int]) -> void:
	# 기록마다.
	for event in unit_events:
		# 피해면 피해 연출, 아니면(쓰러짐) 쓰러짐 연출.
		if event.kind == BattleEvent.Kind.DAMAGED:
			await _damaged(event)
		else:
			await _died(event)
	# 이 유닛은 끝났다.
	remaining[0] -= 1
	# 기다리는 쪽을 깨운다.
	_damage_batch_unit_finished.emit()


## 차례 시작 연출.
func _turn_started(event: BattleEvent) -> void:
	# 보드에서 지금 차례인 유닛이 차례 시작 때 서 있던 칸을 강조한다.
	board.show_current(event.unit.team, event.cell)
	# 그 유닛의 체력·방어도 표시를 기록 시점 값으로 맞춘다 (방어도 초기화 반영).
	board.view_for(event.unit).set_stats(event.hp, event.unit.data.max_hp, event.block)
	# HUD 의 순서 바·SP·더미를 이번 차례로 바꾼다.
	hud.show_turn(event)
	# 로그에 차례 구분선을 넣는다.
	hud.append_log("― %s 차례" % event.unit.data.display_name)
	# 적 차례라면 잠깐 멈춰 누구 차례인지 보이게 한다.
	if not event.unit.is_ally():
		await _wait(ENEMY_TURN_PAUSE)


## 카드 사용 연출: 손패에서 카드를 빼고, 사용자가 대상 쪽으로 공격한다. hits 가 있으면 무기가 닿는 순간 재생한다.
func _card_played(event: BattleEvent, logs: Array[BattleEvent], hits: Array[BattleEvent]) -> void:
	# 손패에서 쓴 카드를 없애고 SP·묘지 숫자를 갱신한다 (instant 에서도 해야 하므로 먼저).
	hud.remove_played_card(event)
	# 테스트 모드면 움직임 연출은 건너뛴다.
	if instant:
		return
	# 카드가 사라지는 것이 보이도록 잠깐 기다린다.
	await _wait(PLAY_REMOVE_WAIT)
	# 카드를 쓴 유닛.
	var view: UnitView = board.view_for(event.unit)
	# 머리 위에 카드 이름.
	view.pop_text(event.card.display_name, Color.WHITE)
	# 겨냥한 칸 쪽으로 공격한다 (유닛이 없어도 칸 위치로).
	await _attack(view, board.layout.cell_position(event.target_team, event.target_cell), event.card.attack_type, logs, hits)


## 적 행동 연출: 공격이면 공격(뒤따르는 피해를 타격 순간에), 방어·휴식이면 깡충, 이동이면 없음.
func _enemy_acted(event: BattleEvent, logs: Array[BattleEvent], hits: Array[BattleEvent]) -> void:
	# 테스트 모드거나 이동이면 연출 없음.
	if instant or event.action == EnemyBrain.Action.MOVE:
		return
	# 행동한 적.
	var view: UnitView = board.view_for(event.unit)
	# 대상이 있는 공격.
	if event.action == EnemyBrain.Action.ATTACK and event.target != null:
		await _attack(view, board.view_for(event.target).home_position, (event.unit.data as EnemyData).attack_type, logs, hits)
	# 방어·휴식.
	else:
		await view.hop()


# 공격 한 번: 푸시인·휘두르기 소리 → 돌진 시작 → 타격 시점까지 대기 → (원거리) 발사음·화살 → 타격 묶음 → 돌진 끝 대기.
func _attack(view: UnitView, target: Vector3, type: CardData.AttackType, logs: Array[BattleEvent], hits: Array[BattleEvent]) -> void:
	# 목표 쪽으로 조금 다가간다.
	if _has_camera():
		camera_fx.push_toward(target)
	# 근접은 예비동작부터 휘두르기 소리.
	if _has_audio() and not attack_sound_at_strike(type):
		audio.play(audio.sounds.for_attack(type))
	# 원거리는 뒤로 물러나는 반동, 근접은 앞으로 돌진. 기다리지 않고 시작한다.
	var ranged: bool = type == CardData.AttackType.RANGED
	var lunging: Array[bool] = [true]
	_lunge_and_flag(view, target, RANGED_RECOIL if ranged else UnitView.LUNGE_DISTANCE, lunging)
	# 무기가 닿는(쏘는) 순간까지.
	await _wait(UnitMotion.ATTACK_STRIKE * view.attack_duration())
	# 원거리는 이때 발사음과 화살.
	if _has_audio() and attack_sound_at_strike(type):
		audio.play(audio.sounds.for_attack(type))
	if ranged:
		var chest := Vector3.UP * UnitView.CHEST_HEIGHT
		var arrow: Projectile = Projectile.spawn(board, projectile_texture, view.home_position + chest, target + chest)
		await arrow.fly()
	# 타격 묶음.
	if not hits.is_empty():
		for log_event in logs:
			hud.append_log(log_event.text)
		_impact_type = type
		_impact_origin = view.home_position
		_has_impact_origin = true
		await _play_damage_batch(hits)
		_impact_type = CardData.AttackType.MELEE
		_has_impact_origin = false
	# 돌진이 끝날 때까지.
	while lunging[0]:
		await _lunge_finished


# 돌진을 끝까지 하고 flag[0] 을 false 로 바꾼 뒤 알린다 (호출한 쪽은 기다리지 않는다).
func _lunge_and_flag(view: UnitView, target: Vector3, distance: float, flag: Array[bool]) -> void:
	await view.lunge_toward(target, distance)
	flag[0] = false
	_lunge_finished.emit()


## 이동 연출: 아군이면 SP 표시를 갱신하고, 유닛을 새 칸으로 옮긴다.
func _unit_moved(event: BattleEvent) -> void:
	# SP 패널과 카드 흐림을 갱신한다 (적이면 HUD 가 무시한다).
	hud.apply_move(event)
	# 보드에서 유닛을 옮긴다. 테스트 모드면 즉시, 아니면 미끄러짐이 끝날 때까지 기다린다.
	await board.move_view(event.unit, event.from_cell, event.to_cell, not instant)


## 피해 연출: 체력 표시 갱신, 튀는 숫자, 타격음, 히트스톱·흔들림, 큰 타격 펄스, 흰 번쩍임·불꽃·넉백.
func _damaged(event: BattleEvent) -> void:
	# 맞은 유닛.
	var view: UnitView = board.view_for(event.unit)
	# 체력·방어도 표시.
	view.set_stats(event.hp, event.unit.data.max_hp, event.block)
	# 로그.
	hud.append_log("%s 에게 %d 피해%s" % [event.unit.data.display_name, event.amount, " (치명)" if event.critical else ""])
	# 테스트 모드면 여기까지만.
	if instant:
		return
	# 피해 숫자 (처치는 더 크게, 치명이면 앞에 표시).
	view.pop_text("%s-%d" % ["치명! " if event.critical else "", event.amount], DAMAGE_COLOR, UnitView.KILL_POP_PUNCH if event.hp <= 0 else UnitView.DAMAGE_POP_PUNCH)
	# 타격음.
	if _has_audio():
		audio.play(audio.sounds.for_impact(_impact_type, event.amount, false))
	# 히트스톱과 흔들림.
	if _has_camera():
		camera_fx.hit_stop(HIT_STOP_TIME)
		camera_fx.shake(BattleCamera.shake_for_damage(event.amount, false))
	# 큰 타격 펄스.
	if _has_pulse() and event.amount >= BIG_HIT_DAMAGE:
		screen_fx.pulse(_BIG_HIT_PULSE)
	# 흰 번쩍임·불꽃·피격·넉백.
	await view.flash_and_shake(_knockback(view, event.amount))
	# 전체 피해 연출 시간이 DAMAGE_TIME 이 되도록 남은 시간 (피격 띠가 더 길면 기다리지 않는다).
	await _wait(maxf(0.0, DAMAGE_TIME - view.hit_duration()))


## 회복 연출: 체력 바 갱신과 초록 숫자.
func _healed(event: BattleEvent) -> void:
	# 회복한 유닛의 화면 객체.
	var view: UnitView = board.view_for(event.unit)
	# 체력 표시를 회복 직후 값으로 바꾼다.
	view.set_hp(event.hp, event.unit.data.max_hp)
	# 테스트 모드면 여기까지만.
	if instant:
		return
	# 머리 위에 초록 회복 숫자를 띄운다.
	view.pop_text("+%d" % event.amount, HEAL_COLOR)
	# 숫자가 보이도록 기다린다.
	await _wait(STAT_POP_TIME)


## 방어도 연출: 방어도 표시 갱신과 푸른 숫자.
func _block_gained(event: BattleEvent) -> void:
	# 방어도를 얻은 유닛의 화면 객체.
	var view: UnitView = board.view_for(event.unit)
	# 방어도 표시를 갱신한다.
	view.set_block(event.block)
	# 테스트 모드면 여기까지만.
	if instant:
		return
	# 머리 위에 푸른 방어도 숫자를 띄운다.
	view.pop_text("+%d 방어" % event.amount, BLOCK_COLOR)
	# 숫자가 보이도록 기다린다.
	await _wait(STAT_POP_TIME)


## 쓰러짐 연출: 빈 칸 표시, 긴 히트스톱·최대 흔들림·슬로모션·펄스·처치음, 넘어지며 사라짐.
func _died(event: BattleEvent) -> void:
	# 빈 칸.
	board.mark_empty(event.unit.team, event.cell)
	# 쓰러진 유닛.
	var view: UnitView = board.view_for(event.unit)
	# 테스트 모드면 바로 숨긴다.
	if instant:
		view.set_alive(false)
		return
	# 카메라.
	if _has_camera():
		camera_fx.hit_stop(KILL_HIT_STOP_TIME)
		camera_fx.shake(BattleCamera.shake_for_damage(0, true))
		camera_fx.kill_slow_mo()
	# 펄스.
	if _has_pulse():
		screen_fx.pulse(1.0)
	# 처치음.
	if _has_audio():
		audio.play(audio.sounds.for_impact(_impact_type, 0, true))
	# 넘어지며 사라진다.
	await view.fade_out()


## seconds 초 동안 기다린다. 테스트 모드이거나 0 이하면 바로 돌아간다.
func _wait(seconds: float) -> void:
	# 기다릴 필요가 없으면 즉시 끝낸다 (await 해도 같은 프레임에 이어진다).
	if instant or seconds <= 0.0:
		return
	# 씬 트리 타이머를 만들어 끝날 때까지 기다린다.
	await get_tree().create_timer(seconds).timeout
