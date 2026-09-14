## 규칙(BattleState)이 낸 신호 하나를 "그 순간의 값"과 함께 저장한 기록.
## 규칙은 한 번에 끝까지 계산하지만 화면은 천천히 연출해야 하므로,
## 신호가 난 시점의 체력·장수 같은 값을 복사해 두고 나중에 순서대로 재생한다.
## 종류마다 쓰는 필드가 다르며, 쓰지 않는 필드는 기본값으로 남는다.
class_name BattleEvent
# RefCounted: 노드가 아닌 가벼운 객체. 참조가 없어지면 자동으로 해제된다.
extends RefCounted

## 기록 종류. BattleState 의 신호 하나에 종류 하나가 대응한다.
## (새 종류는 뒤에만 추가한다 — 중간에 넣으면 기존 숫자 값이 밀린다.)
enum Kind { TURN_STARTED, CARD_PLAYED, ENEMY_ACTED, DAMAGED, HEALED, BLOCK_GAINED, DIED, LOG, BATTLE_ENDED, CARD_DRAWN, DECK_RESHUFFLED, HAND_DISCARDED }

## 이 기록의 종류.
var kind: Kind
## 주인공 유닛 (차례를 받은 유닛, 카드를 쓴 유닛, 맞은 유닛 등).
var unit: Unit
## 대상 유닛 (카드 대상, 적 공격 대상). 없으면 null.
var target: Unit
## 관련 카드 (사용한 카드, 뽑은 카드).
var card: CardData
## 적이 고른 행동 (ENEMY_ACTED 에서만 의미가 있음).
var action: EnemyBrain.Action = EnemyBrain.Action.ATTACK
## 수치 (피해량, 회복량, 방어도 증가량, 리셔플 장수).
var amount: int = 0
## 기록 시점의 체력.
var hp: int = 0
## 기록 시점의 방어도.
var block: int = 0
## 로그 문장.
var text: String = ""
## 전투 종료 시 아군 승리 여부.
var ally_won: bool = false
## 기록 시점의 라운드 번호.
var round_index: int = 0
## 기록 시점의 행동 순서 (순서 바 표시용).
var order: Array[Unit] = []
## order 와 같은 순서로 각 유닛이 살아 있었는지 (나중에 쓰러져도 당시 모습을 보여 주기 위해).
var alive: Array[bool] = []
## 기록 시점에 행동 순서 안에서 몇 번째 차례였는지.
var turn_index: int = -1
## 관련 카드 목록 (HAND_DISCARDED 에서 버린 카드들).
var cards: Array[CardData] = []
## 기록 시점의 덱 장수.
var deck_count: int = 0
## 기록 시점의 묘지 장수.
var discard_count: int = 0


## 종류를 정해 빈 기록을 만든다. 나머지 필드는 만든 쪽이 채운다.
func _init(p_kind: Kind) -> void:
	# 종류를 저장한다.
	kind = p_kind
