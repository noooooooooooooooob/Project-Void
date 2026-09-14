## 전투 중인 유닛 한 명의 실제 상태 (체력, 방어도, SP, 카드 더미).
## 설계 데이터(UnitData)는 바꾸지 않고, 전투에서 변하는 값만 여기에 둔다.
## 신호를 내지 않는다 — 화면에 알릴 일은 BattleState 가 이 객체를 바꾼 뒤 신호로 알린다.
class_name Unit
# RefCounted: 노드가 아닌 가벼운 객체. 참조가 없어지면 자동으로 해제된다.
extends RefCounted

## 소속 편.
enum Team { ALLY, ENEMY }

## 전투 안에서 유닛을 구분하는 번호. 속도가 같을 때 차례 순서를 정하는 데도 쓴다.
var unit_id: int
## 이 유닛의 설계 데이터 (AllyData 또는 EnemyData).
var data: UnitData
## 소속 편.
var team: Team
## 자기 편 격자 안의 칸 좌표 (x = 열, 0 이 앞줄 / y = 행).
var cell: Vector2i
## 현재 체력. 0 이 되면 쓰러진다.
var hp: int
## 현재 방어도. 피해를 먼저 흡수하고, 자기 차례가 시작될 때 0 으로 초기화된다.
var block: int = 0
## 현재 SP (아군만 사용). 카드를 쓸 때 줄어든다.
var sp: int = 0

## 덱: 아직 뽑지 않은 카드. 배열 앞쪽부터 뽑는다.
var deck: Array[CardData] = []
## 손패: 이번 차례에 쓸 수 있는 카드.
var hand: Array[CardData] = []
## 묘지(버린 더미): 쓴 카드와 차례 끝에 버린 카드. 덱이 비면 다시 섞여 덱이 된다.
var discard: Array[CardData] = []
## 제외 더미: 이번 전투에서 다시 쓰지 않는 카드 (아직 이 더미로 보내는 규칙은 없음).
var exile: Array[CardData] = []


## 설계 데이터로부터 전투 시작 상태의 유닛을 만든다.
func _init(p_unit_id: int, p_data: UnitData, p_team: Team, p_cell: Vector2i) -> void:
	# 번호를 기억한다.
	unit_id = p_unit_id
	# 설계 데이터를 기억한다.
	data = p_data
	# 소속 편을 기억한다.
	team = p_team
	# 서 있는 칸을 기억한다.
	cell = p_cell
	# 체력은 최대 체력으로 시작한다.
	hp = p_data.max_hp

	# 아군 데이터라면 SP 와 덱을 준비한다 (적은 카드를 쓰지 않는다).
	if p_data is AllyData:
		# 형 변환해서 AllyData 전용 항목에 접근한다.
		var ally: AllyData = p_data as AllyData
		# SP 를 최대치로 채운다.
		sp = ally.max_sp
		# 덱을 복사한다 — 리소스의 배열을 직접 섞으면 원본 .tres 데이터가 바뀌기 때문이다.
		deck = ally.deck.duplicate()


## 살아 있으면 true.
func is_alive() -> bool:
	# 체력이 1 이상이면 살아 있다.
	return hp > 0


## 아군이면 true.
func is_ally() -> bool:
	# 소속 편이 ALLY 인지 비교한다.
	return team == Team.ALLY


## 피해를 받는다. 방어도가 먼저 깎이고 남은 만큼 체력이 줄어든다.
func take_damage(amount: int) -> void:
	# 방어도가 막을 수 있는 양 = 방어도와 피해 중 작은 값.
	var absorbed: int = mini(block, amount)
	# 막은 만큼 방어도를 소모한다.
	block -= absorbed
	# 막지 못한 나머지를 체력에서 빼되, 0 아래로 내려가지 않게 한다.
	hp = maxi(0, hp - (amount - absorbed))


## 체력을 회복한다. 최대 체력을 넘지 않는다.
func heal(amount: int) -> void:
	# 회복한 값과 최대 체력 중 작은 값으로 맞춘다.
	hp = mini(data.max_hp, hp + amount)


## 방어도를 얻는다. 여러 번 얻으면 누적된다.
func gain_block(amount: int) -> void:
	# 기존 방어도에 더한다.
	block += amount


## 덱을 섞는다 (전투 시작 시 한 번).
func shuffle_deck(rng: RandomNumberGenerator) -> void:
	# 공용 섞기 함수에 덱을 넘긴다.
	_shuffle(deck, rng)


## 묘지의 카드를 모두 덱으로 옮기고 섞는다. 옮긴 장수를 돌려준다.
## 덱이 비었을 때만 부르는 것을 전제로 한다 (호출하는 쪽이 확인함).
func reshuffle_discard(rng: RandomNumberGenerator) -> int:
	# 옮기기 전에 장수를 세어 둔다 (화면 연출에 쓰임).
	var count: int = discard.size()
	# 묘지 카드를 덱 뒤에 붙인다.
	deck.append_array(discard)
	# 묘지를 비운다.
	discard.clear()
	# 덱을 섞는다.
	_shuffle(deck, rng)
	# 옮긴 장수를 알려 준다.
	return count


## 덱 맨 위에서 한 장을 손패로 옮긴다. 덱이 비어 있으면 null.
## 리셔플은 하지 않는다 — BattleState 가 한 장마다 신호를 내기 위해 단계를 나눠 부른다.
func draw_one() -> CardData:
	# 뽑을 카드가 없으면 아무것도 하지 않는다.
	if deck.is_empty():
		return null
	# 덱의 첫 카드를 꺼낸다.
	var card: CardData = deck.pop_front()
	# 손패 끝에 넣는다.
	hand.append(card)
	# 뽑은 카드를 돌려준다.
	return card


## count 장을 뽑는다. 도중에 덱이 비면 묘지를 섞어 이어서 뽑는다.
## (신호 없는 버전. 실제 전투는 같은 순서로 신호를 내는 BattleState._draw_cards 를 쓴다.)
func draw(count: int, rng: RandomNumberGenerator) -> void:
	# 정해진 장수만큼 반복한다.
	for _i in count:
		# 덱이 비었으면 먼저 채워야 한다.
		if deck.is_empty():
			# 묘지도 비었으면 더 뽑을 카드가 없으므로 멈춘다.
			if discard.is_empty():
				return
			# 묘지를 섞어 덱으로 만든다.
			reshuffle_discard(rng)
		# 한 장 뽑는다.
		draw_one()


## 손패를 전부 묘지로 보낸다 (차례가 끝날 때).
func discard_hand() -> void:
	# 손패 카드를 묘지 뒤에 붙인다.
	discard.append_array(hand)
	# 손패를 비운다.
	hand.clear()


## 카드 배열을 제자리에서 섞는다 (Fisher–Yates 방식).
## 전투의 rng 를 쓰므로 같은 시드면 같은 순서가 나온다 (테스트 재현용).
func _shuffle(cards: Array[CardData], rng: RandomNumberGenerator) -> void:
	# 마지막 칸부터 두 번째 칸까지 거꾸로 내려간다.
	for i in range(cards.size() - 1, 0, -1):
		# 0 부터 i 사이에서 무작위 칸을 고른다.
		var j: int = rng.randi_range(0, i)
		# i 칸 카드를 잠시 보관한다.
		var swap: CardData = cards[i]
		# j 칸 카드를 i 칸에 넣는다.
		cards[i] = cards[j]
		# 보관한 카드를 j 칸에 넣어 두 칸을 맞바꾼다.
		cards[j] = swap
