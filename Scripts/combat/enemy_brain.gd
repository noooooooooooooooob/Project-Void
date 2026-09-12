class_name EnemyBrain
extends RefCounted

enum Action { ATTACK, DEFEND, REST }

const REST_THRESHOLD: float = 0.3


static func decide(state: BattleState, actor: Unit) -> Action:
	var data: EnemyData = actor.data as EnemyData
	var hp_ratio: float = float(actor.hp) / float(data.max_hp)
	if hp_ratio <= REST_THRESHOLD and data.rest_heal > 0:
		return Action.REST
	if find_target(state, actor) == null:
		return Action.DEFEND
	return Action.ATTACK


static func find_target(state: BattleState, actor: Unit) -> Unit:
	var data: EnemyData = actor.data as EnemyData
	var best: Unit = null
	for candidate in state.units:
		if not state.resolver.is_valid_target(actor, candidate, data.attack_type, data.attack_range, state.units):
			continue
		if best == null:
			best = candidate
		elif candidate.hp < best.hp:
			best = candidate
		elif candidate.hp == best.hp and candidate.unit_id < best.unit_id:
			best = candidate
	return best


static func take_turn(state: BattleState, actor: Unit) -> void:
	var data: EnemyData = actor.data as EnemyData

	match decide(state, actor):
		Action.REST:
			actor.heal(data.rest_heal)
			state.write_log("%s 휴식" % data.display_name)
		Action.DEFEND:
			actor.gain_block(data.block_amount)
			state.write_log("%s 방어" % data.display_name)
		Action.ATTACK:
			var target: Unit = find_target(state, actor)
			if target == null:
				return
			state.write_log("%s → %s 공격" % [data.display_name, target.data.display_name])
			for victim in state.resolver.expand_shape(target, data.attack_shape, state.units):
				state.apply_damage(victim, data.attack_damage)
