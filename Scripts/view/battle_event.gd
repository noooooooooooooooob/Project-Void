class_name BattleEvent
extends RefCounted

enum Kind { TURN_STARTED, CARD_PLAYED, ENEMY_ACTED, DAMAGED, HEALED, BLOCK_GAINED, DIED, LOG, BATTLE_ENDED, CARD_DRAWN, DECK_RESHUFFLED, HAND_DISCARDED }

var kind: Kind
var unit: Unit
var target: Unit
var card: CardData
var action: EnemyBrain.Action = EnemyBrain.Action.ATTACK
var amount: int = 0
var hp: int = 0
var block: int = 0
var text: String = ""
var ally_won: bool = false
var round_index: int = 0
var order: Array[Unit] = []
var alive: Array[bool] = []
var turn_index: int = -1
var cards: Array[CardData] = []
var deck_count: int = 0
var discard_count: int = 0


func _init(p_kind: Kind) -> void:
	kind = p_kind
