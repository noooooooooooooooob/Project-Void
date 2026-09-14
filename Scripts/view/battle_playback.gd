## 기록된 BattleEvent 들을 하나씩 순서대로 화면에 연출하는 노드.
## 이벤트 하나의 연출(돌진, 피격 번쩍임, 카드 드로우 등)이 끝날 때까지 await 로 기다린 뒤 다음으로 넘어간다.
## 3D 보드(Board3D)와 HUD(BattleHud)를 BattleRoot 가 넣어 준다.
class_name BattlePlayback
# Node: 씬 트리에 붙어야 타이머(get_tree().create_timer)를 쓸 수 있다.
extends Node

## play() 가 모든 이벤트를 재생하고 끝났을 때.
signal finished

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

## 유닛·타일을 보여 주는 3D 보드.
var board: Board3D
## 손패·더미·로그·SP 를 보여 주는 HUD.
var hud: BattleHud
# 테스트용. 트윈과 대기를 건너뛰고 표시값만 반영해서 play() 가 동기로 끝난다.
## true 면 연출 없이 최종 표시값만 즉시 반영한다.
var instant: bool = false


## 이벤트 목록을 앞에서부터 하나씩 재생한다. 호출하는 쪽은 await 로 끝날 때까지 기다린다.
func play(events: Array[BattleEvent]) -> void:
	# 이벤트를 순서대로 하나씩 꺼낸다.
	for event in events:
		# 종류에 따라 알맞은 연출 함수로 보낸다.
		match event.kind:
			# 차례 시작: 현재 유닛 표시·순서 바 갱신.
			BattleEvent.Kind.TURN_STARTED:
				await _turn_started(event)
			# 카드 사용: 손패에서 빼고 돌진.
			BattleEvent.Kind.CARD_PLAYED:
				await _card_played(event)
			# 적 행동: 돌진 또는 제자리 뛰기.
			BattleEvent.Kind.ENEMY_ACTED:
				await _enemy_acted(event)
			# 피해: 체력 바 갱신·숫자·번쩍임.
			BattleEvent.Kind.DAMAGED:
				await _damaged(event)
			# 회복: 체력 바 갱신·숫자.
			BattleEvent.Kind.HEALED:
				await _healed(event)
			# 방어도: 방어도 표시·숫자.
			BattleEvent.Kind.BLOCK_GAINED:
				await _block_gained(event)
			# 쓰러짐: 사라지기.
			BattleEvent.Kind.DIED:
				await _died(event)
			# 로그: 기다림 없이 한 줄 추가.
			BattleEvent.Kind.LOG:
				hud.append_log(event.text)
			# 전투 종료: 승패 배너와 로그.
			BattleEvent.Kind.BATTLE_ENDED:
				# 화면 가운데에 승리/패배 배너를 띄운다.
				hud.show_banner(event.ally_won)
				# 로그에도 결과를 남긴다.
				hud.append_log("전투 종료 — %s" % ("승리" if event.ally_won else "패배"))
			# 드로우: 카드가 덱에서 손패로 날아오기 시작하고, 조금만 기다린 뒤 다음 장으로.
			BattleEvent.Kind.CARD_DRAWN:
				# 비행을 시작한다 (끝날 때까지 기다리지 않음).
				hud.draw_card(event)
				# 다음 장이 약간 늦게 출발하도록 짧게 기다린다.
				await _wait(DRAW_WAIT)
			# 리셔플: 묘지 → 덱 연출을 시작하고 기다린다.
			BattleEvent.Kind.DECK_RESHUFFLED:
				# 뒷면 카드들이 날아가기 시작한다.
				hud.reshuffle(event)
				# 연출이 보이도록 기다린다.
				await _wait(RESHUFFLE_WAIT)
			# 손패 버리기: 손패 → 묘지 연출을 시작하고 기다린다.
			BattleEvent.Kind.HAND_DISCARDED:
				# 손패 카드들이 묘지로 날아가기 시작한다.
				hud.discard_hand(event)
				# 연출이 보이도록 기다린다.
				await _wait(DISCARD_WAIT)
			# 이동: 유닛이 새 칸으로 미끄러진다.
			BattleEvent.Kind.UNIT_MOVED:
				await _unit_moved(event)
	# 모든 이벤트를 재생했음을 알린다.
	finished.emit()


## 차례 시작 연출.
func _turn_started(event: BattleEvent) -> void:
	# 보드에서 지금 차례인 유닛을 강조한다.
	board.show_current(event.unit)
	# 그 유닛의 체력·방어도 표시를 기록 시점 값으로 맞춘다 (방어도 초기화 반영).
	board.view_for(event.unit).set_stats(event.hp, event.unit.data.max_hp, event.block)
	# HUD 의 순서 바·SP·더미를 이번 차례로 바꾼다.
	hud.show_turn(event)
	# 로그에 차례 구분선을 넣는다.
	hud.append_log("― %s 차례" % event.unit.data.display_name)
	# 적 차례라면 잠깐 멈춰 누구 차례인지 보이게 한다.
	if not event.unit.is_ally():
		await _wait(ENEMY_TURN_PAUSE)


## 카드 사용 연출: 손패에서 카드를 빼고, 사용자가 대상 쪽으로 돌진한다.
func _card_played(event: BattleEvent) -> void:
	# 손패에서 쓴 카드를 없애고 SP·묘지 숫자를 갱신한다 (instant 에서도 해야 하므로 먼저).
	hud.remove_played_card(event)
	# 테스트 모드면 움직임 연출은 건너뛴다.
	if instant:
		return
	# 카드가 사라지는 것이 보이도록 잠깐 기다린다.
	await _wait(PLAY_REMOVE_WAIT)
	# 카드를 쓴 유닛의 화면 객체.
	var view: UnitView = board.view_for(event.unit)
	# 머리 위에 카드 이름을 띄운다.
	view.pop_text(event.card.display_name, Color.WHITE)
	# 대상의 원래 자리 쪽으로 돌진했다가 돌아올 때까지 기다린다.
	await view.lunge_toward(board.view_for(event.target).home_position)


## 적 행동 연출: 공격이면 돌진, 방어·휴식이면 제자리 뛰기, 이동이면 없음(UNIT_MOVED 가 보여 준다).
func _enemy_acted(event: BattleEvent) -> void:
	# 테스트 모드면 움직임 연출은 건너뛴다.
	if instant:
		return
	# 이동은 뒤따르는 이동 이벤트가 보여 주므로 여기서는 연출하지 않는다.
	if event.action == EnemyBrain.Action.MOVE:
		return
	# 행동한 적의 화면 객체.
	var view: UnitView = board.view_for(event.unit)
	# 대상이 있는 공격이면 대상 쪽으로 돌진한다.
	if event.action == EnemyBrain.Action.ATTACK and event.target != null:
		await view.lunge_toward(board.view_for(event.target).home_position)
	# 그 외(방어, 휴식)는 제자리에서 한 번 뛴다.
	else:
		await view.hop()


## 이동 연출: 아군이면 SP 표시를 갱신하고, 유닛을 새 칸으로 옮긴다.
func _unit_moved(event: BattleEvent) -> void:
	# SP 패널과 카드 흐림을 갱신한다 (적이면 HUD 가 무시한다).
	hud.apply_move(event)
	# 보드에서 유닛을 옮긴다. 테스트 모드면 즉시, 아니면 미끄러짐이 끝날 때까지 기다린다.
	await board.move_view(event.unit, event.from_cell, event.to_cell, not instant)


## 피해 연출: 체력 바를 먼저 갱신하고, 숫자를 띄우며 번쩍이고 흔들린다.
func _damaged(event: BattleEvent) -> void:
	# 맞은 유닛의 화면 객체.
	var view: UnitView = board.view_for(event.unit)
	# 체력·방어도 표시를 맞은 직후 값으로 바꾼다.
	view.set_stats(event.hp, event.unit.data.max_hp, event.block)
	# 로그에 피해를 남긴다.
	hud.append_log("%s 에게 %d 피해" % [event.unit.data.display_name, event.amount])
	# 테스트 모드면 여기까지만.
	if instant:
		return
	# 머리 위에 붉은 피해 숫자를 띄운다.
	view.pop_text("-%d" % event.amount, DAMAGE_COLOR)
	# 번쩍이고 흔들리는 연출이 끝날 때까지 기다린다.
	await view.flash_and_shake()
	# 전체 피해 연출 시간이 DAMAGE_TIME 이 되도록 남은 시간을 기다린다.
	await _wait(DAMAGE_TIME - UnitView.FLASH_TIME)


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


## 쓰러짐 연출: 타일을 빈 칸으로 표시하고 유닛을 서서히 사라지게 한다.
func _died(event: BattleEvent) -> void:
	# 유닛이 서 있던 타일을 빈 칸 모습으로 바꾼다.
	board.mark_empty(event.unit)
	# 쓰러진 유닛의 화면 객체.
	var view: UnitView = board.view_for(event.unit)
	# 테스트 모드면 바로 숨긴다.
	if instant:
		view.set_alive(false)
		return
	# 서서히 사라지는 연출이 끝날 때까지 기다린다.
	await view.fade_out()


## seconds 초 동안 기다린다. 테스트 모드이거나 0 이하면 바로 돌아간다.
func _wait(seconds: float) -> void:
	# 기다릴 필요가 없으면 즉시 끝낸다 (await 해도 같은 프레임에 이어진다).
	if instant or seconds <= 0.0:
		return
	# 씬 트리 타이머를 만들어 끝날 때까지 기다린다.
	await get_tree().create_timer(seconds).timeout
