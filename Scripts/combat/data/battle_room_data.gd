# @tool: 에디터 인스펙터에서 편집할 수 있게 한다.
@tool
## 전투가 벌어지는 방의 표현 데이터: 반복 바닥·벽 텍스처, 칸 윗면 그림, 가장자리 소품.
## EncounterData.room 이 가리킨다. 규칙과는 상관없다.
class_name BattleRoomData
extends Resource

## 화면 뒤에 까는 배경 그림 (픽셀 아트 한 장). 있으면 바닥·벽·소품 대신 이 그림을 화면 가득 깐다.
@export var backdrop: Texture2D
## 배경 그림 위에 덧칠하는 어둡기 (0 이면 원본, 1 이면 검정). 유닛이 배경에 묻히지 않게.
@export_range(0.0, 1.0) var backdrop_dim: float = 0.25
## 바닥 반복 텍스처.
@export var ground_texture: Texture2D
## 뒷벽·옆벽 반복 텍스처.
@export var wall_texture: Texture2D
## 아군 칸 윗면 그림 (없으면 단색 칸).
@export var ally_tile_texture: Texture2D
## 적군 칸 윗면 그림 (없으면 단색 칸).
@export var enemy_tile_texture: Texture2D
## 보드 칸을 가리지 않는 가장자리에 놓는 소품들.
@export var props: Array[PropPlacement] = []
