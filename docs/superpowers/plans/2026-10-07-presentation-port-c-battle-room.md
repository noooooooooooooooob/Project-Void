# 전투 연출 역이식 C — 전투 공간 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 전투가 단색 배경이 아니라 유니티와 같은 창고 방(바닥·벽·소품) 안에서, 창문 빛기둥·먼지·SSAO·글로우·볼류메트릭 포그가 깔린 분위기로 벌어지게 한다. 맵에서 생성된 전투도 같은 방을 쓴다.

**Architecture:** 방은 `BattleRoomData` 리소스(바닥·벽·칸 텍스처 + `PropPlacement` 목록)로 두고 `EncounterData.room` 이 가리킨다. `BattleEnvironment.build(layout, room)` 이 바닥·벽·소품·스포트라이트·먼지 노드를 만들고, `BattleEnvironment.apply_atmosphere(env, sun)` 가 `Environment`·태양을 실내 분위기로 바꾼다. `Board3D.build` 는 방의 칸 텍스처를 받는다. `BattleRoot` 가 이들을 묶고, 옛 `background`(하늘 이미지)를 지운다.

**Tech Stack:** Godot 4.7.2 (Forward Plus: 볼류메트릭 포그, SSAO, Glow), GDScript, spatial 셰이더, 헤드리스 `TestCase` 러너.

**Spec:** `docs/superpowers/specs/2026-10-06-unity-presentation-port-design.md` (§6, §7, §8 C, §9, §10 C)

## Global Constraints

- 유니티 원본: `C:\Users\User\Desktop\projectvoidunityh\Assets\_Project\` — `Scripts/View/BattleEnvironment.cs`, `Board3D.cs`(칸 텍스처), `Scripts/Editor/AtmosphereSetup.cs`, `Scenes/Battle.unity`(안개·조명), 에셋 `Art/Backgrounds/warehouse_floor.png`·`warehouse_wall.png`·`tile_ally.png`·`tile_enemy.png`, `Art/Props/{crates,railing,drum,fan,cardboard,worklight,toolbox}.png`.
- 유니티 좌표는 먼 쪽이 +z, Godot 은 −z. 위치를 옮길 때 z 부호를 뒤집는다 (x 는 그대로, 아군이 −x).
- 수치 (spec §6): 바닥 40×24, 텍스처 한 장 5 단위, 색 (0.45, 0.45, 0.5) / 벽 높이 4, 텍스처 4 단위, 아래 12% 잘라냄, 색 (0.8, 0.8, 0.85), 위로 0.35→1 구간 smoothstep 최대 85% 어둡게 / 뒷벽은 가장 먼 행에서 2 뒤, 옆벽은 보드 끝에서 3 바깥 / 바닥 높이 = −`Board3D.TILE_THICKNESS` / 칸 텍스처가 있으면 기본색 (0.85, 0.85, 0.88) / 스포트 색 (1, 0.9, 0.75), 전체 각도 35°(Godot `spot_angle` 은 반각 17.5), 범위 20, 그림자 / 먼지 수명 6초, 최대 60, 초당 8, 크기 0.02, 속도 0.05, 상자 2×3×2, 색 (1, 0.92, 0.8, 0.3) / 태양 0.45, 그림자 / 앰비언트 (0.16, 0.17, 0.2) / 안개 색 (0.06, 0.065, 0.08), 밀도 0.025 / Glow threshold 0.9, intensity 0.5 / 채도 0.82, 대비 1.08.
- 소품 배치 (spec §6.3 표, Godot 좌표): crates (−5.8, −2.7) h1.6 · crates (−5.3, 1.5) h1.1 · railing (−0.6, −3.2) h1.0 · drum (4.3, −2.9) h1.1 · drum (5.0, −2.2) h1.1 · fan (3.9, 1.9) h1.8 · cardboard (−3.0, −3.4) h1.0 · worklight (0.3, 2.6) h1.6 · toolbox (−6.0, −0.6) h0.5.
- 규칙 코어는 건드리지 않는다. 새 GDScript 는 타입 명시 + `class_name` + 촘촘한 한국어 주석.
- 테스트: `& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --path . --script res://tests/run_tests.gd` → `N/N passed`. 새 class_name 은 `--headless --editor --quit --path .` 로 재스캔. 새 테스트 파일은 `TEST_SCRIPTS` 에 추가.
- 커밋 끝에 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`. `project.godot` 의 무관한 변경은 커밋하지 않는다.

## Review Focus

1. **방이 없는 인카운터(null room)** — 예전 동작(단색 배경, 단색 칸, 씬 기본 조명)이 그대로여야 하고 오류가 없어야 한다. → Task 2 `no room keeps plain tiles`, Task 3 `no room builds nothing`, Task 4 `atmosphere untouched without a room`.
2. **방 노드가 클릭을 막는 경우** — 바닥·벽·소품에 충돌체가 생기면 칸·유닛 클릭 광선이 먼저 맞는다. → Task 3 `room has no colliders`.
3. **행 수가 다른 격자(맵 생성 3×3 vs skirmish 아군 3×3 / 적 2×2)** — 벽 위치가 `layout.depth()`·`min_x()`·`max_x()` 로 정해져야 어느 격자에서도 보드 바깥에 선다. → Task 3 `walls stand outside the board` 를 두 격자로 검사.
4. **칸 상태 색이 텍스처 위에서 사라지는 경우** — 빈 칸/무효 칸의 어둡게 하기와 발광이 텍스처 칸에서도 동작해야 한다. → Task 2 `textured empty tile is darkened`.
5. **맵에서 들어간 전투에 방이 안 붙는 경우** — 생성기가 만든 모든 인카운터가 창고 방을 가리켜야 한다. → Task 1 `generated encounters use the warehouse room`.

---

### Task 1: 방 데이터 — `BattleRoomData` · `PropPlacement` · 에셋 · 연결

**Files:**
- Create: `Art/rooms/warehouse_floor.png`, `warehouse_wall.png`, `tile_ally.png`, `tile_enemy.png`, `Art/props/{crates,railing,drum,fan,cardboard,worklight,toolbox}.png` (+ `.import`)
- Create: `Scripts/combat/data/battle_room_data.gd`, `Scripts/combat/data/prop_placement.gd`, `Resources/rooms/warehouse.tres`
- Modify: `Scripts/combat/data/encounter_data.gd` (`background` → `room`), `Resources/encounters/skirmish.tres`, `Scripts/map/encounter_generator.gd`, `Scripts/view/battle_root.gd` (`_apply_background` 삭제)
- Test: `tests/test_data.gd`, `tests/test_encounter_generator.gd`

**Interfaces:**
- Produces:
  - `class_name BattleRoomData extends Resource` — `@export var ground_texture, wall_texture, ally_tile_texture, enemy_tile_texture: Texture2D`, `@export var props: Array[PropPlacement]`
  - `class_name PropPlacement extends Resource` — `@export var texture: Texture2D`, `@export var position: Vector3`, `@export var height: float = 1.0`
  - `EncounterData.room: BattleRoomData`
  - `EncounterGenerator.DEFAULT_ROOM_PATH := "res://Resources/rooms/warehouse.tres"`

- [ ] **Step 1: 실패하는 테스트** — `tests/test_data.gd` 의 `run()` 에 `_test_rooms()` 호출을 추가하고 함수를 붙인다.

```gdscript
	# 전투 방 데이터와 연결.
	_test_rooms()
```

```gdscript
# 창고 방이 텍스처 4장과 소품 9개를 갖고, skirmish 가 그 방을 가리키며, 옛 배경 필드는 없는지.
func _test_rooms() -> void:
	# 창고 방.
	var room: BattleRoomData = load("res://Resources/rooms/warehouse.tres")
	# 불러와짐.
	check("warehouse room loads", room != null)
	# 텍스처 4장.
	check("room textures set", room.ground_texture != null and room.wall_texture != null and room.ally_tile_texture != null and room.enemy_tile_texture != null)
	# 소품 9개.
	check_eq("warehouse props", room.props.size(), 9)
	# 첫 소품 (crates, 먼 쪽 왼편).
	check("first prop is the far-left crates", room.props[0].texture != null and room.props[0].position.is_equal_approx(Vector3(-5.8, 0.0, -2.7)) and is_equal_approx(room.props[0].height, 1.6))
	# skirmish.
	var skirmish: EncounterData = load("res://Resources/encounters/skirmish.tres")
	# 같은 방.
	check_eq("skirmish uses the warehouse room", skirmish.room.resource_path, "res://Resources/rooms/warehouse.tres")
	# 옛 배경 필드 제거.
	check("encounter has no background field", not ("background" in skirmish))
```

`tests/test_encounter_generator.gd` 의 `run()` 에 `_test_generated_encounters_use_the_room()` 을 추가하고 함수를 붙인다.

```gdscript
func _test_generated_encounters_use_the_room() -> void:
	var roster: Array[UnitPlacement] = GeneratorScript.build_ally_roster(_rng(3))
	var regular: EncounterData = GeneratorScript.build_encounter(_rng(3), roster, false)
	var boss: EncounterData = GeneratorScript.build_encounter(_rng(3), roster, true)
	check("generated encounters use the warehouse room", regular.room != null and regular.room.resource_path == GeneratorScript.DEFAULT_ROOM_PATH and boss.room == regular.room)
```

- [ ] **Step 2: 실패 확인** — Expected: `BattleRoomData` 를 못 찾거나 `room` 이 없어 FAIL.

- [ ] **Step 3: 에셋 복사·임포트** (Bash)

```bash
U=/c/Users/User/Desktop/projectvoidunityh/Assets/_Project/Art
mkdir -p Art/rooms Art/props Resources/rooms
cp $U/Backgrounds/{warehouse_floor,warehouse_wall,tile_ally,tile_enemy}.png Art/rooms/
cp $U/Props/{crates,railing,drum,fan,cardboard,worklight,toolbox}.png Art/props/
```

`& "C:\Users\User\Desktop\Godot_v4.7.2-stable_win64.exe" --headless --editor --quit --path .` 로 임포트한 뒤:

```bash
# 반복·비스듬히 보이는 큰 텍스처는 밉맵을 켠다 (멀리서 지글거리지 않게).
sed -i 's#mipmaps/generate=false#mipmaps/generate=true#' Art/rooms/*.import
# 64px 소품은 3D 압축을 끈다 (픽셀이 뭉개지지 않게).
sed -i 's#detect_3d/compress_to=1#detect_3d/compress_to=0#' Art/props/*.import
```

그다음 같은 임포트 명령을 한 번 더.

- [ ] **Step 4: 데이터 스크립트**

`Scripts/combat/data/prop_placement.gd`

```gdscript
# @tool: 에디터 인스펙터에서 편집할 수 있게 한다.
@tool
## 전투 방에 놓는 소품 하나. 유닛처럼 카메라를 향한 그림 판으로 서 있다.
class_name PropPlacement
# Resource: 방 리소스 안에 하위 리소스로 저장된다.
extends Resource

## 소품 그림.
@export var texture: Texture2D
## 바닥 위치 (y 는 무시한다, 월드 좌표).
@export var position: Vector3 = Vector3.ZERO
## 그림을 맞출 높이 (3D 단위). 폭은 그림 비율대로.
@export var height: float = 1.0
```

`Scripts/combat/data/battle_room_data.gd`

```gdscript
# @tool: 에디터 인스펙터에서 편집할 수 있게 한다.
@tool
## 전투가 벌어지는 방의 표현 데이터: 반복 바닥·벽 텍스처, 칸 윗면 그림, 가장자리 소품.
## EncounterData.room 이 가리킨다. 규칙과는 상관없다.
class_name BattleRoomData
# Resource: .tres 로 저장해 여러 인카운터가 같은 방을 쓴다.
extends Resource

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
```

`Scripts/combat/data/encounter_data.gd` 의 `background` 두 줄을 교체:

```gdscript
## 전투가 벌어지는 방 (바닥·벽·소품). 비워 두면 단색 배경과 단색 칸.
@export var room: BattleRoomData
```

- [ ] **Step 5: 창고 방 리소스** — `Resources/rooms/warehouse.tres`

```
[gd_resource type="Resource" script_class="BattleRoomData" format=3]

[ext_resource type="Script" path="res://Scripts/combat/data/battle_room_data.gd" id="1_room"]
[ext_resource type="Script" path="res://Scripts/combat/data/prop_placement.gd" id="2_prop"]
[ext_resource type="Texture2D" path="res://Art/rooms/warehouse_floor.png" id="3_floor"]
[ext_resource type="Texture2D" path="res://Art/rooms/warehouse_wall.png" id="4_wall"]
[ext_resource type="Texture2D" path="res://Art/rooms/tile_ally.png" id="5_tile_ally"]
[ext_resource type="Texture2D" path="res://Art/rooms/tile_enemy.png" id="6_tile_enemy"]
[ext_resource type="Texture2D" path="res://Art/props/crates.png" id="7_crates"]
[ext_resource type="Texture2D" path="res://Art/props/railing.png" id="8_railing"]
[ext_resource type="Texture2D" path="res://Art/props/drum.png" id="9_drum"]
[ext_resource type="Texture2D" path="res://Art/props/fan.png" id="10_fan"]
[ext_resource type="Texture2D" path="res://Art/props/cardboard.png" id="11_cardboard"]
[ext_resource type="Texture2D" path="res://Art/props/worklight.png" id="12_worklight"]
[ext_resource type="Texture2D" path="res://Art/props/toolbox.png" id="13_toolbox"]

[sub_resource type="Resource" id="Prop_1"]
script = ExtResource("2_prop")
texture = ExtResource("7_crates")
position = Vector3(-5.8, 0, -2.7)
height = 1.6

[sub_resource type="Resource" id="Prop_2"]
script = ExtResource("2_prop")
texture = ExtResource("7_crates")
position = Vector3(-5.3, 0, 1.5)
height = 1.1

[sub_resource type="Resource" id="Prop_3"]
script = ExtResource("2_prop")
texture = ExtResource("8_railing")
position = Vector3(-0.6, 0, -3.2)
height = 1.0

[sub_resource type="Resource" id="Prop_4"]
script = ExtResource("2_prop")
texture = ExtResource("9_drum")
position = Vector3(4.3, 0, -2.9)
height = 1.1

[sub_resource type="Resource" id="Prop_5"]
script = ExtResource("2_prop")
texture = ExtResource("9_drum")
position = Vector3(5, 0, -2.2)
height = 1.1

[sub_resource type="Resource" id="Prop_6"]
script = ExtResource("2_prop")
texture = ExtResource("10_fan")
position = Vector3(3.9, 0, 1.9)
height = 1.8

[sub_resource type="Resource" id="Prop_7"]
script = ExtResource("2_prop")
texture = ExtResource("11_cardboard")
position = Vector3(-3, 0, -3.4)
height = 1.0

[sub_resource type="Resource" id="Prop_8"]
script = ExtResource("2_prop")
texture = ExtResource("12_worklight")
position = Vector3(0.3, 0, 2.6)
height = 1.6

[sub_resource type="Resource" id="Prop_9"]
script = ExtResource("2_prop")
texture = ExtResource("13_toolbox")
position = Vector3(-6, 0, -0.6)
height = 0.5

[resource]
script = ExtResource("1_room")
ground_texture = ExtResource("3_floor")
wall_texture = ExtResource("4_wall")
ally_tile_texture = ExtResource("5_tile_ally")
enemy_tile_texture = ExtResource("6_tile_enemy")
props = Array[ExtResource("2_prop")]([SubResource("Prop_1"), SubResource("Prop_2"), SubResource("Prop_3"), SubResource("Prop_4"), SubResource("Prop_5"), SubResource("Prop_6"), SubResource("Prop_7"), SubResource("Prop_8"), SubResource("Prop_9")])
```

- [ ] **Step 6: 연결**

`Resources/encounters/skirmish.tres`: 마지막 `[ext_resource ...]` 아래에 `[ext_resource type="Resource" path="res://Resources/rooms/warehouse.tres" id="9_room"]` 를 추가하고, `[resource]` 블록 끝에 `room = ExtResource("9_room")` 를 추가한다. (`background` 줄이 있으면 지운다.)

`Scripts/map/encounter_generator.gd`: 상수 영역에 추가

```gdscript
## 생성한 모든 전투가 쓰는 방. 방이 늘어나면 여기서 고르게 바꾼다.
const DEFAULT_ROOM_PATH: String = "res://Resources/rooms/warehouse.tres"
```

`build_encounter` 의 `return encounter` 바로 앞에:

```gdscript
	encounter.room = load(DEFAULT_ROOM_PATH)
```

`Scripts/view/battle_root.gd`: `_ready` 의 배경 두 줄(주석 + `_apply_background(encounter.background)`)과 `_apply_background` 함수 전체를 지운다. (`_environment` 변수는 Task 4 가 쓰므로 남긴다.)

- [ ] **Step 7: 통과 확인** — 재스캔 후 테스트 실행. Expected: 전체 통과.

- [ ] **Step 8: 커밋**

```bash
git add Art/rooms Art/props Scripts/combat/data/battle_room_data.gd* Scripts/combat/data/prop_placement.gd* Scripts/combat/data/encounter_data.gd Resources/rooms Resources/encounters/skirmish.tres Scripts/map/encounter_generator.gd Scripts/view/battle_root.gd tests/test_data.gd tests/test_encounter_generator.gd
git commit -m "feat: add battle room data with the warehouse room and attach it to encounters

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: 칸 텍스처 (`Board3D`)

**Files:**
- Modify: `Scripts/view/board_3d.gd`, `Scripts/view/battle_root.gd` (build 호출)
- Test: `tests/test_board_3d.gd`

**Interfaces:**
- Consumes: `BattleRoomData.ally_tile_texture / enemy_tile_texture` (Task 1)
- Produces: `Board3D.build(state: BattleState, placeholder: Texture2D, room: BattleRoomData = null) -> void`, 상수 `TEXTURED_TILE_TINT := Color(0.85, 0.85, 0.88)`, `func tile_material(team: Unit.Team, cell: Vector2i) -> StandardMaterial3D`

- [ ] **Step 1: 실패하는 테스트** — `test_board_3d.gd` 의 `run()` 에 `_test_room_tile_textures()` 를 추가하고 함수를 붙인다.

```gdscript
# 방에 칸 텍스처가 있으면 칸 재질에 들어가고 바탕색은 흰 틴트, 빈 칸은 어둡게. 방이 없으면 예전 단색.
func _test_room_tile_textures() -> void:
	# 칸 그림 두 장.
	var ally_tile: Texture2D = _texture(30)
	var enemy_tile: Texture2D = _texture(31)
	var room := BattleRoomData.new()
	room.ally_tile_texture = ally_tile
	room.enemy_tile_texture = enemy_tile
	# 방 있는 보드.
	var state: BattleState = _state()
	var board := Board3D.new()
	board.build(state, _texture(20), room)
	board.sync_from_state(state)
	# 아군 칸 (유닛이 선 칸은 BASE).
	var ally_material: StandardMaterial3D = board.tile_material(Unit.Team.ALLY, Vector2i(0, 1))
	check("ally tile uses the room texture", ally_material.albedo_texture == ally_tile)
	check_eq("textured tile base tint", ally_material.albedo_color, Board3D.TEXTURED_TILE_TINT)
	# 적 칸.
	check("enemy tile uses the room texture", board.tile_material(Unit.Team.ENEMY, Vector2i(0, 1)).albedo_texture == enemy_tile)
	# 빈 칸은 어둡게.
	check_eq("textured empty tile is darkened", board.tile_material(Unit.Team.ALLY, Vector2i(2, 2)).albedo_color, Board3D.TEXTURED_TILE_TINT.darkened(0.45))
	board.free()

	# 방 없는 보드.
	var plain_state: BattleState = _state()
	var plain := Board3D.new()
	plain.build(plain_state, _texture(20))
	plain.sync_from_state(plain_state)
	var plain_material: StandardMaterial3D = plain.tile_material(Unit.Team.ALLY, Vector2i(0, 1))
	check("no room keeps plain tiles", plain_material.albedo_texture == null and plain_material.albedo_color == Board3D.ALLY_TILE_COLOR)
	plain.free()
```

(`_state()` 의 아군은 (0,1) 에 서 있고, 아군 (2,2) 는 비어 있다 — 기존 `_test_build_creates_tiles_and_views` 와 같은 구성.)

- [ ] **Step 2: 실패 확인** — Expected: `tile_material`/`TEXTURED_TILE_TINT` 없음으로 FAIL.

- [ ] **Step 3: 구현** — `Scripts/view/board_3d.gd`

상수 영역(`ENEMY_TILE_COLOR` 아래)에 추가:

```gdscript
## 칸 텍스처가 있을 때의 바탕색 (그림 색을 살리고 살짝만 누른다).
const TEXTURED_TILE_TINT := Color(0.85, 0.85, 0.88)
```

변수 영역에 추가:

```gdscript
## 아군·적군 칸 윗면 그림 (방이 없거나 비어 있으면 null → 단색 칸).
var _tile_textures: Dictionary = {}
```

`build` 시그니처와 앞부분:

```gdscript
## 전투 상태를 보고 타일과 유닛 화면 객체를 모두 만든다 (전투 시작 시 한 번). room 이 있으면 칸에 그 그림을 입힌다.
func build(state: BattleState, placeholder: Texture2D, room: BattleRoomData = null) -> void:
	# 편별 칸 그림 (방이 없으면 없음).
	_tile_textures = {
		Unit.Team.ALLY: room.ally_tile_texture if room != null else null,
		Unit.Team.ENEMY: room.enemy_tile_texture if room != null else null,
	}
```

(기존 본문은 그대로 이어진다.)

`_build_side` 의 `tile.material_override = StandardMaterial3D.new()` 줄을 교체:

```gdscript
			# 칸마다 따로 색을 바꿀 수 있게 새 재질을 만든다.
			var material := StandardMaterial3D.new()
			# 방의 칸 그림이 있으면 입힌다.
			material.albedo_texture = _tile_textures.get(team)
			tile.material_override = material
```

`set_tile_state` 의 기본색 줄을 교체:

```gdscript
	# 편에 따른 기본 색. 칸 그림이 있으면 그림 색을 살리는 흰 틴트.
	var base: Color = TEXTURED_TILE_TINT if _tile_textures.get(team) != null else (ALLY_TILE_COLOR if team == Unit.Team.ALLY else ENEMY_TILE_COLOR)
```

새 함수 (`tile_state` 아래):

```gdscript
## 칸 하나의 재질 (테스트·연출용).
func tile_material(team: Unit.Team, cell: Vector2i) -> StandardMaterial3D:
	return (_tiles[Vector3i(team, cell.x, cell.y)] as MeshInstance3D).material_override
```

`Scripts/view/battle_root.gd` 의 `_board.build(_state, PLACEHOLDER_SPRITE)` 를 `_board.build(_state, PLACEHOLDER_SPRITE, encounter.room)` 로.

- [ ] **Step 4: 통과 확인** — 테스트 실행. Expected: 전체 통과.

- [ ] **Step 5: 커밋**

```bash
git add Scripts/view/board_3d.gd Scripts/view/battle_root.gd tests/test_board_3d.gd
git commit -m "feat: texture board tiles from the battle room

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: 방 만들기 (`BattleEnvironment`)

**Files:**
- Create: `Shaders/room_wall.gdshader`, `Scripts/view/battle_environment.gd`, `tests/test_battle_environment.gd`
- Modify: `tests/run_tests.gd`

**Interfaces:**
- Consumes: `BattleRoomData`, `PropPlacement` (Task 1), `BoardLayout.min_x/max_x/depth/center`, `Board3D.TILE_THICKNESS`, `UnitView.billboard_rotation`, `UnitView.BODY_TILT_DEG`, `UnitView.UNIT_SHADER`
- Produces: `class_name BattleEnvironment extends Node3D`
  - 상수 `GROUND_WIDTH 40.0`, `GROUND_DEPTH 24.0`, `GROUND_TILE_SIZE 5.0`, `GROUND_TINT`, `WALL_HEIGHT 4.0`, `WALL_TILE_SIZE 4.0`, `BACK_WALL_GAP 2.0`, `SIDE_WALL_GAP 3.0`, `WALL_TINT`, `WALL_FLOOR_CROP 0.12`, `WALL_SHADE_ALPHA 0.85`, `LIGHT_COLOR`
  - `static func build(layout: BoardLayout, room: BattleRoomData) -> BattleEnvironment` (room null 이면 null)
  - `var ground: MeshInstance3D`, `var back_wall / left_wall / right_wall: MeshInstance3D`, `var props: Array[Node3D]`, `var lights: Array[SpotLight3D]`

- [ ] **Step 1: 실패하는 테스트** — `tests/test_battle_environment.gd`

```gdscript
# BattleEnvironment(전투 방) 테스트: 방 없으면 없음, 바닥·벽 3면·소품·빛, 벽은 보드 바깥, 충돌체 없음.
extends TestCase


# 실행기가 부르는 진입점.
func run() -> Array[Dictionary]:
	# 방 없음.
	_test_no_room()
	# 구성 요소.
	_test_parts()
	# 벽 위치 (두 격자).
	_test_walls_outside(Vector2i(3, 3), Vector2i(2, 2))
	_test_walls_outside(Vector2i(3, 3), Vector2i(3, 3))
	# 충돌체 없음.
	_test_no_colliders()
	# 결과를 돌려준다.
	return results()


# 텍스처 두 장과 소품 2개짜리 방.
func _room() -> BattleRoomData:
	var room := BattleRoomData.new()
	room.ground_texture = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	room.wall_texture = ImageTexture.create_from_image(Image.create(8, 8, false, Image.FORMAT_RGBA8))
	var props: Array[PropPlacement] = []
	for x in [-5.0, 5.0]:
		var prop := PropPlacement.new()
		prop.texture = ImageTexture.create_from_image(Image.create(32, 64, false, Image.FORMAT_RGBA8))
		prop.position = Vector3(x, 0.0, -3.0)
		prop.height = 1.2
		props.append(prop)
	room.props = props
	return room


# 방이 없으면 아무것도 만들지 않는다.
func _test_no_room() -> void:
	check("no room builds nothing", BattleEnvironment.build(BoardLayout.new(Vector2i(3, 3), Vector2i(2, 2)), null) == null)


# 바닥 1, 벽 3, 소품 2, 창문 빛 2. 바닥은 보드 아래, 소품은 비율대로 높이를 맞춘다.
func _test_parts() -> void:
	var env: BattleEnvironment = BattleEnvironment.build(BoardLayout.new(Vector2i(3, 3), Vector2i(2, 2)), _room())
	check("ground built", env.ground != null)
	check("ground sits under the tiles", is_equal_approx(env.ground.position.y, -Board3D.TILE_THICKNESS))
	check("three walls", env.back_wall != null and env.left_wall != null and env.right_wall != null)
	check_eq("props built", env.props.size(), 2)
	check_eq("two window lights", env.lights.size(), 2)
	# 32×64 그림, 높이 1.2 → 폭 0.6.
	var quad: QuadMesh = (env.props[0].get_child(0) as MeshInstance3D).mesh
	check("prop keeps its aspect", quad.size.is_equal_approx(Vector2(0.6, 1.2)))
	check("prop stands at its floor spot", is_equal_approx(env.props[0].position.x, -5.0) and is_equal_approx(env.props[0].position.z, -3.0))
	env.free()


# 뒷벽은 가장 먼 행 너머(−z), 옆벽은 보드 좌우 끝 바깥.
func _test_walls_outside(ally_grid: Vector2i, enemy_grid: Vector2i) -> void:
	var layout := BoardLayout.new(ally_grid, enemy_grid)
	var env: BattleEnvironment = BattleEnvironment.build(layout, _room())
	var label: String = "%s/%s" % [ally_grid, enemy_grid]
	check("walls stand outside the board: back %s" % label, env.back_wall.position.z < -layout.depth() / 2.0)
	check("walls stand outside the board: left %s" % label, env.left_wall.position.x < layout.min_x())
	check("walls stand outside the board: right %s" % label, env.right_wall.position.x > layout.max_x())
	# 옆벽은 보드 쪽을 본다 (판의 앞 +Z 가 안쪽).
	check("left wall faces the board %s" % label, env.left_wall.global_basis.z.x > 0.9 if env.is_inside_tree() else env.left_wall.basis.z.x > 0.9)
	env.free()


# 방의 어떤 노드도 클릭 광선에 걸리지 않는다.
func _test_no_colliders() -> void:
	var env: BattleEnvironment = BattleEnvironment.build(BoardLayout.new(Vector2i(3, 3), Vector2i(2, 2)), _room())
	check("room has no colliders", env.find_children("*", "CollisionObject3D", true, false).is_empty())
	env.free()
```

`TEST_SCRIPTS` 에 `"res://tests/test_battle_environment.gd",` 추가.

- [ ] **Step 2: 실패 확인** — Expected: `BattleEnvironment` 없음으로 FAIL.

- [ ] **Step 3: 벽 셰이더** — `Shaders/room_wall.gdshader`

```glsl
// 방 벽: 반복 텍스처에 색을 곱하고, 위로 갈수록 어두워지는 그늘(천장 아래 어둠)을 칠한다.
shader_type spatial;
// 옆벽 안쪽·뒷벽 앞쪽만 보이지만 회전 방향과 상관없게 양면.
render_mode cull_disabled;

// 벽 텍스처 (반복).
uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
// 곱하는 색.
uniform vec3 tint : source_color = vec3(0.8, 0.8, 0.85);
// 텍스처 반복 횟수 (가로, 세로).
uniform vec2 uv_scale = vec2(1.0);
// 맨 위에서의 최대 어둡기.
uniform float shade_alpha = 0.85;

void fragment() {
	// 반복 좌표 (세로는 위쪽부터 uv_scale.y 만큼만 써서 텍스처 아래쪽 바닥 줄을 잘라낸다).
	vec3 color = texture(texture_albedo, UV * uv_scale).rgb * tint;
	// 0 = 벽 아래, 1 = 벽 위.
	float height = 1.0 - UV.y;
	// 0.35 위부터 부드럽게 어두워진다.
	float shade = smoothstep(0.0, 1.0, clamp((height - 0.35) / 0.65, 0.0, 1.0)) * shade_alpha;
	ALBEDO = color * (1.0 - shade);
}
```

- [ ] **Step 4: 구현** — `Scripts/view/battle_environment.gd`

```gdscript
## 보드를 둘러싼 방 디오라마: 반복 바닥, 뒷벽·좌우 벽, 가장자리 소품, 창문 스포트라이트와 빛 속 먼지.
## 모두 3D 라서 원근·조명·그림자를 받아 칸이 실제 방 바닥 위에 놓인 것처럼 보인다 (유니티 BattleEnvironment).
## 클릭 판정에 끼지 않도록 충돌체를 만들지 않는다.
class_name BattleEnvironment
# Node3D: 방 전체를 묶는 노드.
extends Node3D

## 벽 셰이더.
const WALL_SHADER: Shader = preload("res://Shaders/room_wall.gdshader")
## 바닥 폭·깊이.
const GROUND_WIDTH: float = 40.0
const GROUND_DEPTH: float = 24.0
## 바닥 텍스처 한 장이 덮는 크기.
const GROUND_TILE_SIZE: float = 5.0
## 바닥이 유닛보다 튀지 않게 어둡게 칠하는 색.
const GROUND_TINT := Color(0.45, 0.45, 0.5)
## 벽 높이 (44° 카메라에는 아래 약 4 단위만 보인다).
const WALL_HEIGHT: float = 4.0
## 벽 텍스처 한 장이 덮는 크기.
const WALL_TILE_SIZE: float = 4.0
## 뒷벽은 가장 먼 행에서, 옆벽은 보드 좌우 끝에서 이만큼 떨어진다.
const BACK_WALL_GAP: float = 2.0
const SIDE_WALL_GAP: float = 3.0
## 벽 색.
const WALL_TINT := Color(0.8, 0.8, 0.85)
## 벽 텍스처 아래쪽에 그려진 바닥 줄을 잘라내는 비율.
const WALL_FLOOR_CROP: float = 0.12
## 벽 맨 위의 최대 어둡기.
const WALL_SHADE_ALPHA: float = 0.85
## 창문 빛 색.
const LIGHT_COLOR := Color(1.0, 0.9, 0.75)
## 창문 빛 세기 (화면을 보며 맞춘다).
const LIGHT_ENERGY: float = 3.0
## 먼지 색.
const DUST_COLOR := Color(1.0, 0.92, 0.8, 0.3)

## 바닥.
var ground: MeshInstance3D
## 뒷벽·왼쪽 벽·오른쪽 벽.
var back_wall: MeshInstance3D
var left_wall: MeshInstance3D
var right_wall: MeshInstance3D
## 소품 (카메라를 향해 도는 피벗).
var props: Array[Node3D] = []
## 창문 스포트라이트.
var lights: Array[SpotLight3D] = []


## 보드 배치와 방 데이터로 방을 만든다. 방이 없으면 null.
static func build(layout: BoardLayout, room: BattleRoomData) -> BattleEnvironment:
	# 방 없음.
	if room == null:
		return null
	# 방 노드.
	var env := BattleEnvironment.new()
	env.name = "Environment"
	# 보드 중심과 바닥 높이 (칸 윗면 0 에서 두께만큼 아래).
	var center: Vector3 = layout.center()
	var floor_y: float = -Board3D.TILE_THICKNESS

	# --- 바닥 ---
	if room.ground_texture != null:
		env.ground = MeshInstance3D.new()
		env.ground.name = "Ground"
		var plane := PlaneMesh.new()
		plane.size = Vector2(GROUND_WIDTH, GROUND_DEPTH)
		env.ground.mesh = plane
		var material := StandardMaterial3D.new()
		material.albedo_texture = room.ground_texture
		material.albedo_color = GROUND_TINT
		# 텍스처 한 장이 5 단위를 덮게 반복한다.
		material.uv1_scale = Vector3(GROUND_WIDTH / GROUND_TILE_SIZE, GROUND_DEPTH / GROUND_TILE_SIZE, 1.0)
		env.ground.material_override = material
		env.ground.position = Vector3(center.x, floor_y, center.z)
		env.add_child(env.ground)

	# --- 벽 ---
	# 0행이 −z (화면 안쪽). 뒷벽은 가장 먼 행 너머, 옆벽은 보드 좌우 끝 너머.
	var back_z: float = -(layout.depth() / 2.0 + BACK_WALL_GAP)
	var left_x: float = layout.min_x() - SIDE_WALL_GAP
	var right_x: float = layout.max_x() + SIDE_WALL_GAP
	var front_z: float = center.z + GROUND_DEPTH / 2.0
	var side_length: float = front_z - back_z
	if room.wall_texture != null:
		# 뒷벽은 앞(+z, 카메라 쪽)을 본다.
		env.back_wall = env._wall("BackWall", room.wall_texture, Vector3(center.x, floor_y, back_z), 0.0, right_x - left_x)
		# 왼쪽 벽은 +x(보드 쪽)를 본다.
		env.left_wall = env._wall("LeftWall", room.wall_texture, Vector3(left_x, floor_y, back_z + side_length / 2.0), 90.0, side_length)
		# 오른쪽 벽은 −x 를 본다.
		env.right_wall = env._wall("RightWall", room.wall_texture, Vector3(right_x, floor_y, back_z + side_length / 2.0), -90.0, side_length)
		# 뒷벽 위쪽 창문에서 비스듬히 들어오는 빛 두 줄기와 그 아래 먼지.
		env._window_light(Vector3(left_x + (right_x - left_x) * 0.3, WALL_HEIGHT, back_z + 0.5), center + Vector3(-1.5, floor_y, -0.5))
		env._window_light(Vector3(left_x + (right_x - left_x) * 0.75, WALL_HEIGHT, back_z + 0.5), center + Vector3(2.5, floor_y, 0.5))

	# --- 소품 ---
	for placement in room.props:
		if placement.texture != null:
			env.props.append(env._prop(placement, floor_y))
	return env


## 매 프레임: 소품을 카메라 쪽으로 돌린다 (유닛과 같은 세로축 빌보드 + 20° 기울임).
func _process(_delta: float) -> void:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if camera == null:
		return
	var rotation_now: Vector3 = UnitView.billboard_rotation(-camera.global_basis.z, UnitView.BODY_TILT_DEG)
	for prop in props:
		prop.rotation = rotation_now


# 벽 한 면: 아래 가운데 bottom_center, 세로축 yaw_deg 회전, 가로 length, 높이 WALL_HEIGHT.
func _wall(wall_name: String, texture: Texture2D, bottom_center: Vector3, yaw_deg: float, length: float) -> MeshInstance3D:
	var wall := MeshInstance3D.new()
	wall.name = wall_name
	var quad := QuadMesh.new()
	quad.size = Vector2(length, WALL_HEIGHT)
	wall.mesh = quad
	# 반복 텍스처·그늘 셰이더.
	var material := ShaderMaterial.new()
	material.shader = WALL_SHADER
	material.set_shader_parameter("texture_albedo", texture)
	material.set_shader_parameter("tint", WALL_TINT)
	material.set_shader_parameter("uv_scale", Vector2(length / WALL_TILE_SIZE, WALL_HEIGHT / WALL_TILE_SIZE * (1.0 - WALL_FLOOR_CROP)))
	material.set_shader_parameter("shade_alpha", WALL_SHADE_ALPHA)
	wall.material_override = material
	# 판 중심을 높이 절반에.
	wall.position = bottom_center + Vector3.UP * (WALL_HEIGHT / 2.0)
	wall.rotation_degrees = Vector3(0.0, yaw_deg, 0.0)
	add_child(wall)
	return wall


# 창문 스포트라이트 하나와 빛이 떨어지는 곳 위의 먼지.
func _window_light(from: Vector3, target: Vector3) -> void:
	var spot := SpotLight3D.new()
	spot.name = "WindowLight"
	spot.light_color = LIGHT_COLOR
	spot.light_energy = LIGHT_ENERGY
	spot.spot_range = 20.0
	# 유니티 spotAngle 35° 는 전체 각도, Godot 은 반각.
	spot.spot_angle = 17.5
	spot.shadow_enabled = true
	add_child(spot)
	spot.look_at_from_position(from, target, Vector3.UP)
	lights.append(spot)
	_dust(target + Vector3.UP * 1.5)


# 빛 속에 천천히 떠다니는 먼지.
func _dust(at: Vector3) -> void:
	var dust := CPUParticles3D.new()
	dust.name = "Dust"
	dust.position = at
	dust.amount = 48
	dust.lifetime = 6.0
	dust.preprocess = 6.0
	dust.local_coords = false
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	dust.emission_box_extents = Vector3(1.0, 1.5, 1.0)
	dust.direction = Vector3.UP
	dust.spread = 180.0
	dust.gravity = Vector3.ZERO
	dust.initial_velocity_min = 0.05
	dust.initial_velocity_max = 0.05
	var quad := QuadMesh.new()
	quad.size = Vector2(0.02, 0.02)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_color = DUST_COLOR
	quad.material = material
	dust.mesh = quad
	dust.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dust.emitting = true
	add_child(dust)


# 소품 하나: 바닥 위치에 선 피벗 + 높이에 맞춘 그림 판 (유닛과 같은 셰이더, 그림자 드리움).
func _prop(placement: PropPlacement, floor_y: float) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = "Prop"
	pivot.position = Vector3(placement.position.x, floor_y, placement.position.z)
	var sprite := MeshInstance3D.new()
	var quad := QuadMesh.new()
	var aspect: float = float(placement.texture.get_width()) / float(placement.texture.get_height())
	quad.size = Vector2(placement.height * aspect, placement.height)
	sprite.mesh = quad
	sprite.position = Vector3(0.0, placement.height / 2.0, 0.0)
	var material := ShaderMaterial.new()
	material.shader = UnitView.UNIT_SHADER
	material.set_shader_parameter("texture_albedo", placement.texture)
	sprite.material_override = material
	pivot.add_child(sprite)
	add_child(pivot)
	return pivot
```

- [ ] **Step 5: 통과 확인** — 재스캔 후 테스트 실행. Expected: 전체 통과.

- [ ] **Step 6: 커밋**

```bash
git add Shaders/room_wall.gdshader* Scripts/view/battle_environment.gd* tests/test_battle_environment.gd* tests/run_tests.gd
git commit -m "feat: build the battle room with floor, walls, props, window lights and dust

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: 실내 분위기와 `BattleRoot` 연결

**Files:**
- Modify: `Scripts/view/battle_environment.gd`, `Scripts/view/battle_root.gd`
- Test: `tests/test_battle_environment.gd`

**Interfaces:**
- Consumes: `BattleEnvironment.build` (Task 3), `Board3D.build(..., room)` (Task 2)
- Produces: `static func apply_atmosphere(env: Environment, sun: DirectionalLight3D) -> void`, 상수 `AMBIENT_COLOR`, `FOG_COLOR`, `FOG_DENSITY 0.025`, `VOLUMETRIC_DENSITY`, `SUN_ENERGY 0.45`

- [ ] **Step 1: 실패하는 테스트** — `test_battle_environment.gd` 의 `run()` 에 `_test_atmosphere()` 를 추가하고 함수를 붙인다.

```gdscript
# 실내 분위기: 앰비언트·안개·볼류메트릭 포그·SSAO·글로우·색 보정, 태양은 약하게·그림자.
func _test_atmosphere() -> void:
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	BattleEnvironment.apply_atmosphere(env, sun)
	check_eq("ambient colour", env.ambient_light_color, BattleEnvironment.AMBIENT_COLOR)
	check("depth fog", env.fog_enabled and is_equal_approx(env.fog_density, BattleEnvironment.FOG_DENSITY))
	check("volumetric fog for light shafts", env.volumetric_fog_enabled)
	check("ssao on", env.ssao_enabled)
	check("glow on", env.glow_enabled and is_equal_approx(env.glow_hdr_threshold, 0.9) and is_equal_approx(env.glow_intensity, 0.5))
	check("muted colours", env.adjustment_enabled and is_equal_approx(env.adjustment_saturation, 0.82) and is_equal_approx(env.adjustment_contrast, 1.08))
	check("weak sun with shadows", is_equal_approx(sun.light_energy, BattleEnvironment.SUN_ENERGY) and sun.shadow_enabled)
	# 태양은 안개를 밝히지 않는다 (빛기둥은 창문 빛만).
	check("sun does not light the fog", is_equal_approx(sun.light_volumetric_fog_energy, 0.0))
	sun.free()
```

(`atmosphere untouched without a room` 은 `BattleRoot` 가 방이 있을 때만 `apply_atmosphere` 를 부르는 것으로 보장한다 — Step 4 코드의 `if encounter.room != null` 분기. 씬 단위 테스트는 Task 5 실행 확인에서 본다.)

- [ ] **Step 2: 실패 확인** — Expected: `apply_atmosphere` 없음으로 FAIL.

- [ ] **Step 3: 구현** — `battle_environment.gd` 상수 영역에 추가:

```gdscript
## 실내 앰비언트 색.
const AMBIENT_COLOR := Color(0.16, 0.17, 0.2)
## 멀어질수록 깔리는 어두운 안개 색과 밀도.
const FOG_COLOR := Color(0.06, 0.065, 0.08)
const FOG_DENSITY: float = 0.025
## 창문 빛이 보이는 볼류메트릭 포그 밀도 (뒤쪽 유닛을 가리지 않을 만큼 옅게, 화면을 보며 맞춘다).
const VOLUMETRIC_DENSITY: float = 0.02
## 실내라 약한 태양.
const SUN_ENERGY: float = 0.45
```

정적 함수 (`build` 아래):

```gdscript
## 실내 분위기로 환경·태양을 바꾼다 (유니티 AtmosphereSetup + Battle.unity 안개·조명).
static func apply_atmosphere(env: Environment, sun: DirectionalLight3D) -> void:
	# 바깥은 안개 색과 같은 어둠.
	env.background_mode = Environment.BG_COLOR
	env.background_color = FOG_COLOR
	# 실내 앰비언트.
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = AMBIENT_COLOR
	env.ambient_light_energy = 1.0
	# 멀어질수록 어두워지는 안개.
	env.fog_enabled = true
	env.fog_light_color = FOG_COLOR
	env.fog_density = FOG_DENSITY
	# 빛기둥을 만드는 옅은 볼류메트릭 포그 (창문 스포트라이트만 밝힌다).
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = VOLUMETRIC_DENSITY
	env.volumetric_fog_albedo = Color(1.0, 0.95, 0.9)
	# 구석 그늘.
	env.ssao_enabled = true
	# 창문·밝은 곳이 은은하게 번지게.
	env.glow_enabled = true
	env.glow_hdr_threshold = 0.9
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1
	# 채도를 낮추고 대비를 조금 올린다.
	env.adjustment_enabled = true
	env.adjustment_saturation = 0.82
	env.adjustment_contrast = 1.08
	# 약한 태양, 그림자는 켠다. 태양이 안개 전체를 밝히면 빛기둥이 묻히므로 안개에는 기여하지 않는다.
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	sun.light_volumetric_fog_energy = 0.0
```

- [ ] **Step 4: `BattleRoot` 연결** — `Scripts/view/battle_root.gd`

`_ready` 의 `_board.build(...)` 바로 앞에:

```gdscript
	# 인카운터에 방이 있으면 방을 짓고 실내 분위기로 바꾼다 (없으면 씬 기본 단색 배경·조명 그대로).
	if encounter.room != null:
		# 방 노드 (보드 배치가 필요해 같은 격자로 먼저 계산한다).
		var room_env: BattleEnvironment = BattleEnvironment.build(BoardLayout.new(encounter.ally_grid, encounter.enemy_grid), encounter.room)
		add_child(room_env)
		# 씬 환경을 이 전투 전용 사본으로 바꿔 분위기를 입힌다.
		var env: Environment = _environment.environment.duplicate()
		BattleEnvironment.apply_atmosphere(env, get_node("Sun") as DirectionalLight3D)
		_environment.environment = env
```

(`_environment` 주석이 "배경(하늘)" 이면 "씬 환경(배경·안개·후처리)" 로 고친다.)

- [ ] **Step 5: 통과 확인** — 재스캔 후 테스트 실행. Expected: 전체 통과.

- [ ] **Step 6: 커밋**

```bash
git add Scripts/view/battle_environment.gd Scripts/view/battle_root.gd tests/test_battle_environment.gd
git commit -m "feat: give room battles an indoor atmosphere with fog, light shafts, SSAO and glow

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: 실행 확인과 조정

**Files:** 조정이 필요하면 `Scripts/view/battle_environment.gd` 의 상수(`LIGHT_ENERGY`, `VOLUMETRIC_DENSITY`, 소품 위치는 `Resources/rooms/warehouse.tres`)만.

- [ ] **Step 1: 전체 테스트** — Expected: `N/N passed`.

- [ ] **Step 2: 게임 실행** — `battle_3d.tscn` 을 띄우고(PowerShell `Start-Process ... -ArgumentList "--path", ".", "res://Scenes/battle_3d.tscn"`), 스크래치패드 `rt.py`(TCP 7777, 응답 4바이트 LE 길이 + JSON)로 캡처한다. 맵에서 들어간 전투도 한 번 확인한다(`game_root.tscn` 실행 → 첫 노드 클릭, press/release 짝).

- [ ] **Step 3: 확인 항목**
  - 바닥·뒷벽·옆벽이 보이고 벽 위쪽이 어둡다. 벽 아래에 바닥 줄이 두 번 보이지 않는다.
  - 창문 쪽에서 빛기둥이 비스듬히 내려오고 먼지가 떠다닌다. 빛기둥이 뒤쪽 유닛을 가리지 않는다 (가리면 `VOLUMETRIC_DENSITY` 를 낮춘다).
  - 칸이 콘크리트/금속 그림이고 차례·사거리·이동 강조색이 보인다.
  - 소품 9개가 보드 가장자리에 있고 칸·유닛을 가리지 않는다 (가리면 `warehouse.tres` 위치만 조정).
  - 유닛·소품 그림자가 바닥에 진다.
  - 카드·칸 클릭이 된다. 콘솔 오류 0건 (셰이더 포함).
  - 맵에서 들어간 전투도 같은 방이다.
  - 유니티 `Battle.unity` 캡처(사용자 제공)와 나란히 비교는 사용자에게 맡긴다.

- [ ] **Step 4: 조정했다면 테스트 다시 실행 후 커밋**

```bash
git add Scripts/view/battle_environment.gd Resources/rooms/warehouse.tres
git commit -m "fix: tune battle room lighting after in-game check

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```
