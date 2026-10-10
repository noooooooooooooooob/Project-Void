# @tool: 에디터 안에서도 실행되어 인스펙터에서 값을 편집할 수 있다.
@tool
## 적 유닛 한 종류의 설계 데이터 (.tres 리소스로 저장).
## 적의 공격·방어·휴식은 카드(attack_card·defend_card·rest_card)로 정의되고 아군 카드와 같은 규칙으로 적용된다.
## 어떤 행동을 할지는 EnemyBrain 이 정한다.
class_name EnemyData
# 이름·체력·속도·그림 같은 공통 항목은 부모 UnitData 에서 물려받는다.
extends UnitData

## 차례마다 이동을 먼저 고를 확률 (0.25 = 25%). 0 이면 이동하지 않고 난수도 쓰지 않는다.
@export var move_chance: float = 0.25
## 공격 행동에 쓰는 카드 (근접·원거리·범위·% 계수를 아군 카드와 같은 규칙으로 적용). 비어 있으면 공격하지 않는다.
@export var attack_card: CardData
## 방어 행동에 쓰는 카드 (보통 자신 방어도). 비어 있으면 방어하지 않는다.
@export var defend_card: CardData
## 휴식 행동에 쓰는 카드 (보통 자신 회복). 비어 있으면 휴식하지 않는다.
@export var rest_card: CardData
