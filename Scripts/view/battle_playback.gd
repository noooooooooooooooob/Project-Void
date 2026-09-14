class_name BattlePlayback
extends Node

signal finished

const ENEMY_TURN_PAUSE: float = 0.2
const DAMAGE_TIME: float = 0.5
const STAT_POP_TIME: float = 0.4
const DAMAGE_COLOR := Color(1.0, 0.35, 0.3)
const HEAL_COLOR := Color(0.45, 0.9, 0.45)
const BLOCK_COLOR := Color(0.5, 0.7, 1.0)
const DRAW_WAIT: float = 0.12
const RESHUFFLE_WAIT: float = 0.45
const DISCARD_WAIT: float = 0.35
const PLAY_REMOVE_WAIT: float = 0.2

var board: Board3D
var hud: BattleHud
# 테스트용. 트윈과 대기를 건너뛰고 표시값만 반영해서 play() 가 동기로 끝난다.
var instant: bool = false


func play(events: Array[BattleEvent]) -> void:
	for event in events:
		match event.kind:
			BattleEvent.Kind.TURN_STARTED:
				await _turn_started(event)
			BattleEvent.Kind.CARD_PLAYED:
				await _card_played(event)
			BattleEvent.Kind.ENEMY_ACTED:
				await _enemy_acted(event)
			BattleEvent.Kind.DAMAGED:
				await _damaged(event)
			BattleEvent.Kind.HEALED:
				await _healed(event)
			BattleEvent.Kind.BLOCK_GAINED:
				await _block_gained(event)
			BattleEvent.Kind.DIED:
				await _died(event)
			BattleEvent.Kind.LOG:
				hud.append_log(event.text)
			BattleEvent.Kind.BATTLE_ENDED:
				hud.show_banner(event.ally_won)
				hud.append_log("전투 종료 — %s" % ("승리" if event.ally_won else "패배"))
			BattleEvent.Kind.CARD_DRAWN:
				hud.draw_card(event)
				await _wait(DRAW_WAIT)
			BattleEvent.Kind.DECK_RESHUFFLED:
				hud.reshuffle(event)
				await _wait(RESHUFFLE_WAIT)
			BattleEvent.Kind.HAND_DISCARDED:
				hud.discard_hand(event)
				await _wait(DISCARD_WAIT)
	finished.emit()


func _turn_started(event: BattleEvent) -> void:
	board.show_current(event.unit)
	board.view_for(event.unit).set_stats(event.hp, event.unit.data.max_hp, event.block)
	hud.show_turn(event)
	hud.append_log("― %s 차례" % event.unit.data.display_name)
	if not event.unit.is_ally():
		await _wait(ENEMY_TURN_PAUSE)


func _card_played(event: BattleEvent) -> void:
	hud.remove_played_card(event)
	if instant:
		return
	await _wait(PLAY_REMOVE_WAIT)
	var view: UnitView = board.view_for(event.unit)
	view.pop_text(event.card.display_name, Color.WHITE)
	await view.lunge_toward(board.view_for(event.target).home_position)


func _enemy_acted(event: BattleEvent) -> void:
	if instant:
		return
	var view: UnitView = board.view_for(event.unit)
	if event.action == EnemyBrain.Action.ATTACK and event.target != null:
		await view.lunge_toward(board.view_for(event.target).home_position)
	else:
		await view.hop()


func _damaged(event: BattleEvent) -> void:
	var view: UnitView = board.view_for(event.unit)
	view.set_stats(event.hp, event.unit.data.max_hp, event.block)
	hud.append_log("%s 에게 %d 피해" % [event.unit.data.display_name, event.amount])
	if instant:
		return
	view.pop_text("-%d" % event.amount, DAMAGE_COLOR)
	await view.flash_and_shake()
	await _wait(DAMAGE_TIME - UnitView.FLASH_TIME)


func _healed(event: BattleEvent) -> void:
	var view: UnitView = board.view_for(event.unit)
	view.set_hp(event.hp, event.unit.data.max_hp)
	if instant:
		return
	view.pop_text("+%d" % event.amount, HEAL_COLOR)
	await _wait(STAT_POP_TIME)


func _block_gained(event: BattleEvent) -> void:
	var view: UnitView = board.view_for(event.unit)
	view.set_block(event.block)
	if instant:
		return
	view.pop_text("+%d 방어" % event.amount, BLOCK_COLOR)
	await _wait(STAT_POP_TIME)


func _died(event: BattleEvent) -> void:
	board.mark_empty(event.unit)
	var view: UnitView = board.view_for(event.unit)
	if instant:
		view.set_alive(false)
		return
	await view.fade_out()


func _wait(seconds: float) -> void:
	if instant or seconds <= 0.0:
		return
	await get_tree().create_timer(seconds).timeout
