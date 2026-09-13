class_name Unit
extends RefCounted

enum Team { ALLY, ENEMY }

var unit_id: int
var data: UnitData
var team: Team
var cell: Vector2i
var hp: int
var block: int = 0
var sp: int = 0

var deck: Array[CardData] = []
var hand: Array[CardData] = []
var discard: Array[CardData] = []
var exile: Array[CardData] = []


func _init(p_unit_id: int, p_data: UnitData, p_team: Team, p_cell: Vector2i) -> void:
	unit_id = p_unit_id
	data = p_data
	team = p_team
	cell = p_cell
	hp = p_data.max_hp

	if p_data is AllyData:
		var ally: AllyData = p_data as AllyData
		sp = ally.max_sp
		deck = ally.deck.duplicate()


func is_alive() -> bool:
	return hp > 0


func is_ally() -> bool:
	return team == Team.ALLY


func take_damage(amount: int) -> void:
	var absorbed: int = mini(block, amount)
	block -= absorbed
	hp = maxi(0, hp - (amount - absorbed))


func heal(amount: int) -> void:
	hp = mini(data.max_hp, hp + amount)


func gain_block(amount: int) -> void:
	block += amount


func shuffle_deck(rng: RandomNumberGenerator) -> void:
	_shuffle(deck, rng)


func reshuffle_discard(rng: RandomNumberGenerator) -> int:
	var count: int = discard.size()
	deck.append_array(discard)
	discard.clear()
	_shuffle(deck, rng)
	return count


func draw_one() -> CardData:
	if deck.is_empty():
		return null
	var card: CardData = deck.pop_front()
	hand.append(card)
	return card


func draw(count: int, rng: RandomNumberGenerator) -> void:
	for _i in count:
		if deck.is_empty():
			if discard.is_empty():
				return
			reshuffle_discard(rng)
		draw_one()


func discard_hand() -> void:
	discard.append_array(hand)
	hand.clear()


func _shuffle(cards: Array[CardData], rng: RandomNumberGenerator) -> void:
	for i in range(cards.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: CardData = cards[i]
		cards[i] = cards[j]
		cards[j] = swap
