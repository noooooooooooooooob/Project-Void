# 맵 프로토타입 구현 계획

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 시작 → 2갈래(각 4스텝) → 보스로 합류하는 고정 맵에서 노드를 골라 전투에 들어가고, 승패 결과를 맵 진행과 화면에 반영한다.

**Architecture:** 맵 로직은 `Scripts/map/`의 `RefCounted`(`MapNode`, `MapGraph`, `MapLayout`, `EncounterGenerator`, `MapRunState`)로 두고, 화면은 `Scripts/view/map_view.gd`(맵 UI)와 `Scripts/view/game_root.gd`(맵↔전투 전환, 새 메인 씬)가 맡는다. 전투는 노드에 들어갈 때마다 `battle_3d.tscn`을 새로 인스턴스하고 끝나면 버린다. `Scripts/combat/`은 무수정.

**Tech Stack:** Godot 4.7.2 (stable), GDScript (타입 명시), 자체 헤드리스 테스트 러너

**Spec:** `docs/superpowers/specs/2026-09-16-map-prototype-design.md`

## Global Constraints

- Godot 4.7.2. 엔진 버전 올리지 말 것.
- Godot 실행 파일: `C:\C\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe`
- 타입 명시 GDScript. 모든 함수에 `-> ReturnType`, 모든 `var`에 타입.
- 외부 애드온/의존성 추가 금지.
- `Scripts/combat/`의 기존 파일은 **한 글자도** 수정하지 않는다. 맵 로직(`Scripts/map/`)은 그 타입들을 읽기 전용으로 소비하거나 새 인스턴스를 만들 뿐이다.
- `Scripts/map/`의 클래스는 `Node`를 상속하거나 참조하지 않는다. `RefCounted`와 `Resource`(기존 데이터 타입)만.
- 난수는 전부 주입된 `RandomNumberGenerator` 인자로만 소비한다. 전역 `randi()`/`randf()`/`Array.shuffle()` 호출 금지 — 기존 `Unit._shuffle`과 같은 방식으로 손으로 셔플한다.
- 전역 함수와 이름이 겹치는 식별자 금지: `range`, `log`, `sign` 등.
- 로드한 `Resource`(예: `vanguard.tres`)를 그 자리에서 고치지 않는다. 반드시 `.duplicate()` 후 수정 — 안 그러면 리소스 캐시를 공유하는 다른 곳까지 값이 바뀐다.
- 주석은 WHY가 비자명할 때만.
- 테스트 명령:
  ```
  & "C:\C\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --headless --path "C:\C\GitHubDH\Project-Void" --script res://tests/run_tests.gd
  ```
  베이스라인은 `339/339 passed`다. 새 태스크를 시작하기 전에 이 숫자가 유지되는지 항상 먼저 확인한다.
- 새 `class_name` 스크립트를 추가한 뒤 "Could not find type X" 파싱 에러가 나면 클래스 캐시가 낡은 것이다. 클래스 캐시 갱신:
  ```
  & "C:\C\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --headless --editor --quit --path "C:\C\GitHubDH\Project-Void"
  ```
- 헤드리스 테스트에서 노드를 트리에 붙일 때: `(Engine.get_main_loop() as SceneTree).root.add_child(node)`, 테스트 끝에 `node.free()`.
- 커밋 메시지: 제목 한 줄 + 본문. `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>` 트레일러 포함.
- 작업 브랜치는 `feature/map-prototype` (이미 생성됨, `feature/combat-prototype`에서 분기).

## 파일 구조

| 경로 | 책임 |
|---|---|
| `Scripts/map/map_node.gd` | 노드 1개의 구조 정보 |
| `Scripts/map/map_graph.gd` | 고정 토폴로지 (시작→2갈래×4스텝→보스) |
| `Scripts/map/map_layout.gd` | 노드 좌표 계산 (순수 함수) |
| `Scripts/map/encounter_generator.gd` | 아군 로스터·적 구성 랜덤 생성 |
| `Scripts/map/map_run_state.gd` | 런 진행 상태, 선택 규칙, 승패 처리 |
| `Scripts/view/map_view.gd` | 맵 화면 (원+선, 클릭, 결과 배너) |
| `Scripts/view/game_root.gd` | 맵↔전투 전환 오케스트레이션 |
| `Scenes/game_root.tscn` | 새 메인 씬 |
| `tests/test_map_graph.gd`, `test_map_layout.gd`, `test_encounter_generator.gd`, `test_map_run_state.gd`, `test_map_view.gd` | 각 클래스 테스트 |

세부 인터페이스와 근거는 spec 5~9장을 그대로 따른다. 이 계획은 구현 순서와 검증 방법만 다룬다.

---

### Task 1: `MapNode` / `MapGraph`

**Files:** Create `Scripts/map/map_node.gd`, `Scripts/map/map_graph.gd`, `tests/test_map_graph.gd`. Modify `tests/run_tests.gd`.

**Interfaces:** spec 5장의 `MapNode`(`id`, `branch`, `step`, `is_boss`, `connections`)와 `MapGraph`(`BRANCH_COUNT=2`, `STEPS_PER_BRANCH=4`, `start_id`, `boss_id`, `nodes`, `get_node(id)`, `node_count()`).

- [ ] **Step 1**: `test_map_graph.gd` 작성 — 노드 10개, `get_node(0).connections == [1, 5]`, 갈래 내부 선형 체인(`get_node(1).connections == [2]` ... `get_node(4).connections == [9]`), `get_node(9).connections.is_empty()`, `boss_id == 9`, 모든 논-보스 논-시작 노드의 `is_boss == false`이고 `get_node(9).is_boss == true`. `run_tests.gd`의 `TEST_SCRIPTS`에 추가.
- [ ] **Step 2**: 테스트 명령 실행 → `map_graph.gd` 없어서 실패 확인 (기존 339개는 PASS 유지).
- [ ] **Step 3**: `MapNode`, `MapGraph` 구현.
- [ ] **Step 4**: 클래스 캐시 갱신 → 테스트 통과 확인 (`349/349`).
- [ ] **Step 5**: 커밋.

---

### Task 2: `MapLayout`

**Files:** Create `Scripts/map/map_layout.gd`, `tests/test_map_layout.gd`. Modify `tests/run_tests.gd`.

**Interfaces:** spec 6장. `STEP_SPACING=120.0`, `BRANCH_SPACING=220.0`, `static func node_position(node: MapNode) -> Vector2`.

- [ ] **Step 1**: 테스트 작성 — 시작이 `(0,0)`, 갈래0/갈래1이 x축 좌우 대칭, 같은 스텝이면 `|x|`가 같음, 스텝이 커질수록 `y` 증가, 보스의 `y`가 스텝4보다 크고 `x == 0`.
- [ ] **Step 2**: 실패 확인.
- [ ] **Step 3**: 구현.
- [ ] **Step 4**: 캐시 갱신 + 통과 확인.
- [ ] **Step 5**: 커밋.

---

### Task 3: `EncounterGenerator`

**Files:** Create `Scripts/map/encounter_generator.gd`, `tests/test_encounter_generator.gd`. Modify `tests/run_tests.gd`.

**Interfaces:** spec 7.1장. `build_ally_roster(rng) -> Array[UnitPlacement]`, `build_encounter(rng, ally_units, is_boss) -> EncounterData`.

이 태스크가 카드/적 풀을 `res://Resources/cards/`, `res://Resources/units/`에서 `DirAccess`로 스캔하는 로더를 처음 만든다. 파일명을 하드코딩하지 않는다.

- [ ] **Step 1**: 테스트 작성 (spec 11.3 항목 그대로) — 결정론(같은 시드 → 같은 구성), 로스터 3기·셀·그리드 일치, 적 수 범위(1~3 / 보스 4), 적이 `EnemyData`만, 칸 중복 없음, 원본 `.tres` 비오염(같은 경로를 두 번 `load()`해서 `.deck`이 그대로인지).
- [ ] **Step 2**: 실패 확인.
- [ ] **Step 3**: 구현 — 셔플은 `Unit._shuffle`과 동일한 Fisher-Yates를 손으로. `_load_cards()`/`_load_enemy_pool()`은 `DirAccess.open(dir).get_files()`로 `.tres` 확장자만 필터링 후 `load()`, 적 풀은 `is EnemyData`로 걸러낸다.
- [ ] **Step 4**: 캐시 갱신 + 통과 확인.
- [ ] **Step 5**: 커밋.

---

### Task 4: `MapRunState`

**Files:** Create `Scripts/map/map_run_state.gd`, `tests/test_map_run_state.gd`. Modify `tests/run_tests.gd`.

**Interfaces:** spec 7.2장. `_init(rng)`, `is_selectable(id) -> bool`, `encounter_for(id) -> EncounterData`, `resolve_win(id) -> void`, `reset() -> void`.

- [ ] **Step 1**: 테스트 작성 (spec 11.4 항목) — 시작에서 `[1, 5]`만 selectable, 한쪽 갈래 진입 후 반대쪽 불가, `resolve_win` 후 `current_node_id`/`cleared` 갱신, 보스 클리어 시 내부 `reset()` 호출 확인(새 `MapGraph` 인스턴스, `current_node_id == 새 graph.start_id`), 같은 시드로 두 `MapRunState`를 만들면 초기 상태(첫 노드의 인카운터 등)가 동일.
- [ ] **Step 2**: 실패 확인.
- [ ] **Step 3**: 구현.
- [ ] **Step 4**: 캐시 갱신 + 통과 확인.
- [ ] **Step 5**: 커밋.

---

### Task 5: `MapView`

**Files:** Create `Scripts/view/map_view.gd`, `tests/test_map_view.gd`. Modify `tests/run_tests.gd`.

**Interfaces:** spec 8.1장. `signal node_selected(node_id: int)`, `sync_from_state(run_state) -> void`, `show_result(text: String) -> void`, `hide_result() -> void`.

- [ ] **Step 1**: 테스트 작성 (트리에 붙여서) — `_ready()` 후 버튼 개수 == `graph.node_count()`, 버튼 클릭(가짜 `pressed.emit()` 또는 `button_pressed` 헬퍼 호출) → `node_selected(id)`, `sync_from_state` 후 selectable 버튼만 `disabled == false`, `show_result("x")` 후 배너 텍스트 "x"이고 `visible == true`, `hide_result()` 후 `visible == false`.
- [ ] **Step 2**: 실패 확인.
- [ ] **Step 3**: 구현 — 씬 파일 없이 `_ready()`에서 버튼·배너 생성 (`UnitView.setup()` 전례). `_draw()`로 간선.
- [ ] **Step 4**: 캐시 갱신 + 통과 확인.
- [ ] **Step 5**: 커밋.

---

### Task 6: `GameRoot`와 전투 연결

**Files:** Create `Scripts/view/game_root.gd`, `Scenes/game_root.tscn`. Modify `Scripts/view/battle_root.gd`, `project.godot`.

**Interfaces:** spec 8.2장, 9장.

- [ ] **Step 1**: `battle_root.gd`에 `signal battle_finished(ally_won: bool)` 추가하고 `_ready()`에서 `_state.battle_ended`에 연결.
- [ ] **Step 2**: 테스트 명령 실행 → 기존 스위트 전부 통과 확인 (순수 추가라 회귀 없어야 함).
- [ ] **Step 3**: `game_root.gd` 구현 (spec 8.2 흐름 1~4, 보스 클리어/패배 시 `show_result` 분기 포함).
- [ ] **Step 4**: `Scenes/game_root.tscn` 생성 (`Node` + 스크립트).
- [ ] **Step 5**: `project.godot`의 `run/main_scene`을 `res://Scenes/game_root.tscn`으로 변경.
- [ ] **Step 6**: 캐시 갱신 + 전체 테스트 통과 확인.
- [ ] **Step 7**: 실행 검증 — Godot 에디터로 실제 플레이: 시작 노드에서 두 갈래만 활성인지, 노드 클릭 시 전투 진입, 승리 시 맵 복귀 및 클리어 표시, 보스 클리어와 패배 시 결과 배너가 뜨는지, `battle_3d.tscn`을 단독으로 열어도 기존처럼 스커미시가 뜨는지(회귀 확인).
- [ ] **Step 8**: 커밋.

---

### Task 7: 마무리 확인

- [ ] 전체 테스트 스위트 최종 실행, 통과 개수 기록.
- [ ] spec의 "확정한 가정" 표와 실제 구현이 일치하는지 재확인.
- [ ] 커밋 로그 정리 확인 (`git log --oneline feature/combat-prototype..feature/map-prototype`).
