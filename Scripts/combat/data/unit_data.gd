# @tool: 에디터 안에서도 실행되어 인스펙터에서 값을 편집할 수 있다.
@tool
## 아군·적군이 공통으로 가지는 유닛 설계 데이터.
## 직접 쓰지 않고 AllyData / EnemyData 가 상속해서 쓴다.
class_name UnitData
# Resource: 파일로 저장·불러오기가 되는 데이터 객체.
extends Resource

## 코드에서 유닛 종류를 구분하는 고유 이름 (예: &"brute").
@export var id: StringName = &""
## 화면에 보이는 유닛 이름 (예: "괴한").
@export var display_name: String = ""
## 최대 체력. 전투 시작 시 현재 체력도 이 값으로 시작한다.
@export var max_hp: int = 10
## 행동 속도. 매 라운드 이 값이 큰 유닛부터 차례가 온다.
@export var speed: int = 10
## 2.5D 화면에서 유닛을 그릴 그림. 비어 있으면 Board3D 가 임시 실루엣 그림(placeholder_unit.png)을 쓴다.
@export var sprite: Texture2D
## 64px 프레임을 가로로 이어 붙인 대기 애니메이션 띠 (프레임 수 = 너비 ÷ 높이). 비어 있으면 sprite 한 장 + 코드 숨쉬기.
@export var idle_sheet: Texture2D
## 공격 애니메이션 띠. 비어 있으면 코드 자세(UnitMotion.attack)로 공격한다.
@export var attack_sheet: Texture2D
## 피격 애니메이션 띠. 비어 있으면 코드 자세(UnitMotion.hit)로 움찔한다.
@export var hit_sheet: Texture2D
## 몸 주변에 계속 피어오르는 이펙트 그림 (예: 영혼불). 비어 있으면 없음.
@export var aura_texture: Texture2D
