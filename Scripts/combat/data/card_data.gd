# @tool: 에디터 안에서도 실행되어 인스펙터에서 카드 값을 편집할 수 있다.
@tool
## 카드 한 종류의 설계 데이터 (.tres 리소스로 저장).
## 전투 중에는 이 리소스를 그대로 덱·손패·묘지 배열에 넣어 돌려 쓴다.
## 규칙(BattleState)과 화면(CardView) 모두 이 값을 읽기만 하고 바꾸지 않는다.
class_name CardData
# Resource: 파일로 저장·불러오기가 되는 데이터 객체.
extends Resource

## 공격 방식.
## MELEE(근접): 대상과 같은 행에서 대상보다 앞 열에 살아 있는 유닛이 있으면 막혀서 칠 수 없다.
## RANGED(원거리): 막힘을 무시하고 사거리만 따진다.
enum AttackType { MELEE, RANGED }
## 피해 범위 모양 (TargetResolver.expand_shape 가 실제 맞는 유닛을 고른다).
## SINGLE(단일): 고른 대상 한 명만.
## PIERCE(관통): 대상과 같은 행(cell.y)에 있는 그 편 유닛 전부 — 앞뒤로 꿰뚫는다.
## SWEEP(횡렬): 대상과 같은 열(cell.x)에 있는 그 편 유닛 전부 — 옆으로 쓸어낸다.
enum Shape { SINGLE, PIERCE, SWEEP }

## 코드에서 카드를 구분하는 고유 이름 (예: &"slash").
@export var id: StringName = &""
## 화면에 보이는 카드 이름 (예: "베기").
@export var display_name: String = ""
## 카드를 쓰는 데 드는 SP.
@export var sp_cost: int = 1
## 근접/원거리 공격 방식.
@export var attack_type: AttackType = AttackType.MELEE
## 피해 범위 모양.
@export var shape: Shape = Shape.SINGLE
## 칠 수 있는 최대 거리. TargetResolver.reach 로 잰 거리가 이 값 이하여야 한다.
@export var attack_range: int = 1
## 맞은 유닛마다 주는 피해량 (방어도가 먼저 깎인다).
@export var damage: int = 0
