# @tool: 에디터 안에서도 실행되어 인스펙터에서 값을 편집할 수 있다.
@tool
## 적 유닛 한 종류의 설계 데이터 (.tres 리소스로 저장).
## 적은 카드 대신 고정된 공격·방어·휴식 행동을 쓰며, 그 수치를 여기서 정한다.
## 어떤 행동을 할지는 EnemyBrain 이 정한다.
class_name EnemyData
# 이름·체력·속도·그림 같은 공통 항목은 부모 UnitData 에서 물려받는다.
extends UnitData

## 공격 행동 한 번의 피해량.
@export var attack_damage: int = 5
## 공격 방식 (근접/원거리). 카드와 같은 규칙으로 대상을 고른다.
@export var attack_type: CardData.AttackType = CardData.AttackType.MELEE
## 공격 범위 모양 (단일/관통/횡렬).
@export var attack_shape: CardData.Shape = CardData.Shape.SINGLE
## 공격이 닿는 최대 거리.
@export var attack_range: int = 1
## 방어 행동으로 얻는 방어도.
@export var block_amount: int = 5
## 휴식 행동으로 회복하는 체력.
@export var rest_heal: int = 4
