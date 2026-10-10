# @tool: 에디터 안에서도 실행되어 인스펙터에서 카드 값을 편집할 수 있다.
@tool
## 카드 한 종류의 설계 데이터 (.tres 리소스로 저장).
## 전투 중에는 이 리소스를 그대로 덱·손패·묘지 배열에 넣어 돌려 쓴다.
## 규칙(BattleState)과 화면(CardView) 모두 이 값을 읽기만 하고 바꾸지 않는다.
class_name CardData
# Resource: 파일로 저장·불러오기가 되는 데이터 객체.
extends Resource

## 공격 종류. 카드의 기준 유닛을 고르는 방법이 다르다 (TargetResolver.valid_anchors).
## MELEE(근접): 사용자와 같은 행에서 가장 앞 열의 적 한 명. 없으면 쓸 수 없다. 조준 없이 자동.
## RANGED(원거리): 상대 편 아무나. ALLY(아군): 같은 편 아무나(자신 포함). SELF(자신): 사용자. 조준 없이 자동.
enum AttackType { MELEE, RANGED, ALLY, SELF }
## 카드 분류. 카드 색을 정한다.
enum Category { ATTACK, SKILL, SPECIAL }
## 피해 범위 모양 (TargetResolver.expand_shape 가 실제 맞는 유닛을 고른다).
## SINGLE(단일): 고른 대상 한 명만.
## PIERCE(관통): 대상과 같은 행(cell.y)에 있는 그 편 유닛 전부 — 앞뒤로 꿰뚫는다.
## SWEEP(횡렬): 대상과 같은 열(cell.x)에 있는 그 편 유닛 전부 — 옆으로 쓸어낸다.
## AREA(광역 2×2): 고른 대상 칸을 왼쪽 위 모서리로 삼는 2×2 블록 안의 그 편 유닛 전부.
## LINE(관통로): 대상과 같은 행(cell.y)에서 앞줄(0 열)부터 대상 열까지 — 대상까지 가는 길목의 유닛을 모두 휩쓴다.
enum Shape { SINGLE, PIERCE, SWEEP, AREA, LINE }

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
## 카드 분류 (공격·스킬·특수).
@export var category: Category = Category.ATTACK
## 범위: 기준 칸에서의 오프셋 목록 (x = 열, + 가 뒤쪽 / y = 행, + 가 아래). 비어 있으면 기준 칸 하나(단일).
@export var area: Array[Vector2i] = []
## 효과 목록. 순서대로 적용된다.
@export var effects: Array[CardEffect] = []


## 실제로 쓸 범위 오프셋. 비어 있으면 단일 [(0,0)].
func area_offsets() -> Array[Vector2i]:
	# 비었으면 기준 칸 하나.
	if area.is_empty():
		var single: Array[Vector2i] = [Vector2i.ZERO]
		return single
	# 아니면 그대로.
	return area


## 플레이어가 기준 유닛을 직접 겨냥해야 하는 카드인지 (원거리·아군). 근접·자신은 자동으로 정해진다.
func needs_aim() -> bool:
	# 원거리나 아군이면 조준한다.
	return attack_type == AttackType.RANGED or attack_type == AttackType.ALLY
