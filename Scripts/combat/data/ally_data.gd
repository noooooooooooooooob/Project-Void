# @tool: 에디터 안에서도 이 스크립트가 실행되어 인스펙터에서 값을 바로 편집할 수 있다.
@tool
## 아군 유닛 한 종류의 설계 데이터 (.tres 리소스로 저장).
## UnitData 의 공통 능력치에 더해 아군만 가지는 SP 와 덱을 정의한다.
## 전투가 시작되면 Unit 이 이 데이터를 읽어 실제 상태(체력, 손패 등)를 만든다.
class_name AllyData
# 이름·체력·속도·그림 같은 공통 항목은 부모 UnitData 에서 물려받는다.
extends UnitData

## 한 차례에 쓸 수 있는 최대 SP. 차례가 시작될 때마다 이 값으로 다시 채워진다.
@export var max_sp: int = 3
## 이 유닛이 전투를 시작할 때 가지고 있는 카드 목록 (같은 카드를 여러 번 넣을 수 있음).
@export var deck: Array[CardData] = []
