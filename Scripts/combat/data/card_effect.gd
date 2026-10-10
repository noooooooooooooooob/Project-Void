# @tool: 에디터 안에서도 실행되어 인스펙터에서 효과 값을 편집할 수 있다.
@tool
## 카드 효과 하나: 무엇을(피해·방어도·회복), 얼마나(사용자 스탯의 %), 누구에게(카드 범위·자신).
## 카드 하나에 여러 개를 넣어 "피해 80% + 자신 방어도 50%" 같은 복합 카드를 만든다.
class_name CardEffect
# Resource: 카드 .tres 안에 하위 리소스로 저장된다.
extends Resource

## 효과 종류. 기준 스탯은 종류가 정한다 (피해·회복 → 공격, 방어도 → 방어).
enum Kind { DAMAGE, BLOCK, HEAL }
## 효과 대상. AREA 는 카드의 기준 유닛과 범위로 정해진 유닛들, SELF 는 카드를 쓴 유닛.
enum Target { AREA, SELF }

## 효과 종류.
@export var kind: Kind = Kind.DAMAGE
## 계수 (%). 120 이면 기준 스탯의 1.2 배.
@export var percent: int = 100
## 효과 대상.
@export var target: Target = Target.AREA
