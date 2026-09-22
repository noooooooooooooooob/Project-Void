# @tool: 에디터 안에서도 실행되어 인스펙터에서 전투 구성을 편집할 수 있다.
@tool
## 전투 한 판의 구성 데이터 (.tres 리소스로 저장, 예: skirmish.tres).
## 양쪽 격자 크기와 어떤 유닛이 어느 칸에 서는지를 정한다.
## BattleState 가 이 데이터를 받아 실제 유닛들을 만든다.
class_name EncounterData
# Resource: 파일로 저장·불러오기가 되는 데이터 객체.
extends Resource

## 아군 격자 크기. x = 가로 칸 수(앞뒤 열), y = 세로 칸 수(행).
@export var ally_grid: Vector2i = Vector2i(3, 3)
## 적군 격자 크기. x = 가로 칸 수(앞뒤 열), y = 세로 칸 수(행).
@export var enemy_grid: Vector2i = Vector2i(3, 3)
## 아군 유닛과 각자 서는 칸 목록. 배열 순서대로 유닛 id 가 매겨진다.
@export var ally_units: Array[UnitPlacement] = []
## 적군 유닛과 각자 서는 칸 목록. 아군 다음 번호부터 id 가 매겨진다.
@export var enemy_units: Array[UnitPlacement] = []
## 전투 배경으로 쓸 이미지. 비워 두면 기본 단색 배경을 쓴다.
@export var background: Texture2D
