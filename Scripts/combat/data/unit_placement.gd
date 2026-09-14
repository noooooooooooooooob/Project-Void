# @tool: 에디터 안에서도 실행되어 인스펙터에서 값을 편집할 수 있다.
@tool
## 전투 구성(EncounterData)에서 "어떤 유닛이 어느 칸에 서는가" 한 줄을 나타낸다.
class_name UnitPlacement
# Resource: 파일로 저장·불러오기가 되는 데이터 객체.
extends Resource

## 배치할 유닛의 설계 데이터 (AllyData 또는 EnemyData).
@export var unit_data: UnitData
## 자기 편 격자 안의 칸 좌표. x = 열(0 이 가장 앞줄), y = 행(위에서부터).
@export var cell: Vector2i = Vector2i.ZERO
