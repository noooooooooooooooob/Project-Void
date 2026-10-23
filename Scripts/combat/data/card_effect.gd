# @tool: 에디터 안에서도 실행되어 인스펙터에서 효과 값을 편집할 수 있다.
@tool
## 카드 효과 하나: 무엇을(피해·방어도·회복·상태 등), 얼마나(사용자 스탯의 % 또는 고정값), 누구에게(카드 범위·자신).
## 카드 하나에 여러 개를 넣어 "피해 80% + 자신 방어도 50%" 같은 복합 카드를 만든다.
class_name CardEffect
# Resource: 카드 .tres 안에 하위 리소스로 저장된다.
extends Resource

## 효과 종류.
## DAMAGE 피해(공격 %), BLOCK 방어도(방어 %), HEAL 회복(공격 %),
## GAIN_STATUS 상태 스택을 value 만큼 얻는다(예: 혈갑), BURST 사용자의 status 스택을 모두 소모해 스택당 공격 % 피해,
## HP_COST 사용자가 체력을 value 만큼 잃는다(방어도 무시, 1 아래로는 내려가지 않음), STAGGER 흐트러짐만 공격 % 만큼 깎는다.
enum Kind { DAMAGE, BLOCK, HEAL, GAIN_STATUS, BURST, HP_COST, STAGGER }
## 효과 대상. AREA 는 카드의 기준 유닛과 범위로 정해진 유닛들, SELF 는 카드를 쓴 유닛.
enum Target { AREA, SELF }

## 효과 종류.
@export var kind: Kind = Kind.DAMAGE
## 계수 (%). 120 이면 기준 스탯의 1.2 배. DAMAGE·BLOCK·HEAL·BURST·STAGGER 가 쓴다.
@export var percent: int = 100
## 고정값. GAIN_STATUS(얻는 스택)·HP_COST(잃는 체력)가 쓴다.
@export var value: int = 0
## 상태 id. GAIN_STATUS·BURST 가 쓴다 (예: &"blood_armor").
@export var status: StringName = &""
## 효과 대상.
@export var target: Target = Target.AREA
